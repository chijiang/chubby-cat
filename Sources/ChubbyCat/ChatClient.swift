import Foundation
import Security
import ChubbyCatCore

struct APIConfiguration {
    var baseURL: String
    var model: String
    var key: String
    var streaming: Bool
}

// A dedicated session refuses cross-origin redirects, preventing credential forwarding.
final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let old = task.originalRequest?.url, let next = request.url,
              old.scheme == next.scheme, old.host == next.host, old.port == next.port else { completionHandler(nil); return }
        completionHandler(request)
    }
}

final class ChatClient {
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpShouldSetCookies = false
        config.urlCredentialStorage = nil
        session = URLSession(configuration: config, delegate: RedirectGuard(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }

    func complete(configuration: APIConfiguration, messages: [ChatMessage], onText: @escaping @MainActor (String) -> Void) async throws {
        var request = URLRequest(url: try ChatEndpoint.url(from: configuration.baseURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.streaming ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        if !configuration.key.isEmpty { request.setValue("Bearer \(configuration.key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try ChatRequest(model: configuration.model, messages: messages, stream: configuration.streaming).encoded()
        if !configuration.streaming {
            let (data, response) = try await session.data(for: request)
            try validate(response, data: data)
            try Task.checkCancellation()
            await onText(try ChatResponse.text(from: data))
            return
        }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ChatFailure.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw httpError(http.statusCode) }
        // Some compatible services return JSON despite stream=true; decode the single response, without a second request.
        if http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("application/json") == true {
            var data = Data()
            for try await byte in bytes { try Task.checkCancellation(); data.append(byte); if data.count > 2_000_000 { throw ChatFailure.oversizedResponse } }
            await onText(try ChatResponse.text(from: data)); return
        }
        var decoder = SSEByteDecoder()
        var received = false
        var count = 0
        for try await byte in bytes {
            try Task.checkCancellation()
            count += 1
            guard count <= 2_000_000 else { throw ChatFailure.oversizedResponse }
            if let event = try decoder.append(byte: byte) {
                switch event {
                case .text(let text): received = true; await onText(text)
                case .done: if !received { throw ChatFailure.emptyResponse }; return
                }
            }
        }
        if let event = try decoder.flush(), case .text(let text) = event { received = true; await onText(text) }
        if !received { throw ChatFailure.emptyResponse }
    }
    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ChatFailure.malformedResponse }
        guard (200..<300).contains(http.statusCode) else { throw httpError(http.statusCode) }
    }
    private func httpError(_ status: Int) -> ChatFailure {
        let message: String
        switch status {
        case 401, 403: message = "The API rejected access (\(status)). Check your key and permissions."
        case 404: message = "The endpoint or model was not found (404). Check the API URL and model name."
        case 429: message = "The service is rate-limiting requests (429). Wait a moment, then retry."
        case 300..<400: message = "The API redirected to a different address. Enter its final HTTPS endpoint in Settings."
        default: message = "The service returned HTTP \(status). Try again later or check the service."
        }
        return .provider(message)
    }
}

enum CredentialStore {
    private static let service = "com.deskkitty.prototype.api"
    static func read(for endpoint: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: endpoint, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ key: String, for endpoint: String, delete: (CFDictionary) -> OSStatus = { SecItemDelete($0) }) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: endpoint]
        if key.isEmpty {
            let status = delete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw ChatFailure.provider("Could not remove the saved API key from Keychain (\(status)).")
            }
            return
        }
        let update: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = Data(key.utf8)
            let inserted = SecItemAdd(item as CFDictionary, nil)
            if inserted != errSecSuccess { throw ChatFailure.provider("Could not save the API key to Keychain (\(inserted)).") }
        } else if status != errSecSuccess { throw ChatFailure.provider("Could not update the API key in Keychain (\(status)).") }
    }
}
