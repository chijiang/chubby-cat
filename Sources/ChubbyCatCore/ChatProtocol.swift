import Foundation

public enum ChatFailure: LocalizedError {
    case invalidEndpoint, insecureEndpoint, emptyModel, malformedResponse, emptyResponse, oversizedResponse
    case provider(String)
    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return "Enter a complete API URL without credentials, query parameters or fragments."
        case .insecureEndpoint: return "Use HTTPS for remote services. HTTP is allowed only for localhost."
        case .emptyModel: return "Enter the model name supplied by your API service."
        case .malformedResponse: return "The service returned an unreadable response. Check its compatibility and streaming setting."
        case .emptyResponse: return "The service returned no text. Check the model and response format."
        case .oversizedResponse: return "The response exceeded the prototype's size limit. Start a new conversation."
        case .provider(let message): return message
        }
    }
}

public enum ChatEndpoint {
    public static func url(from input: String) throws -> URL {
        guard var parts = URLComponents(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host?.lowercased(), !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil else { throw ChatFailure.invalidEndpoint }
        let local = ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host)
        if scheme == "http" && !local { throw ChatFailure.insecureEndpoint }
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.isEmpty { path = "/v1" }
        if !path.hasSuffix("/chat/completions") { path += "/chat/completions" }
        parts.path = path
        guard let result = parts.url else { throw ChatFailure.invalidEndpoint }
        return result
    }
}

public struct ChatMessage: Codable, Equatable {
    public var role: String
    public var content: String
    public init(role: String, content: String) { self.role = role; self.content = content }
}

public struct ChatRequest: Encodable {
    public var model: String
    public var messages: [ChatMessage]
    public var stream: Bool
    public init(model: String, messages: [ChatMessage], stream: Bool) { self.model = model; self.messages = messages; self.stream = stream }
    public func encoded() throws -> Data {
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatFailure.emptyModel }
        return try JSONEncoder().encode(self)
    }
}

public enum StreamEvent: Equatable { case text(String), done }

public struct SSEDecoder {
    private var dataLines: [String] = []
    private var bufferedSize = 0
    public init() {}
    public mutating func append(line: String) throws -> StreamEvent? {
        let line = line.hasSuffix("\r") ? String(line.dropLast()) : line
        if line.isEmpty { return try flush() }
        guard line.hasPrefix("data:") else { return nil }
        var value = String(line.dropFirst(5))
        if value.hasPrefix(" ") { value.removeFirst() }
        bufferedSize += value.utf8.count
        guard bufferedSize <= 262144 else { throw ChatFailure.oversizedResponse }
        dataLines.append(value)
        return nil
    }
    public mutating func flush() throws -> StreamEvent? {
        guard !dataLines.isEmpty else { return nil }
        let payload = dataLines.joined(separator: "\n")
        dataLines = []; bufferedSize = 0
        if payload.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" { return .done }
        guard let value = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { throw ChatFailure.malformedResponse }
        if let error = value["error"] as? [String: Any] { throw ChatFailure.provider(String((error["message"] as? String ?? "API request failed.").prefix(300))) }
        guard let choices = value["choices"] as? [[String: Any]], let choice = choices.first else { return nil }
        if let delta = choice["delta"] as? [String: Any], let text = delta["content"] as? String, !text.isEmpty { return .text(text) }
        if let reason = choice["finish_reason"] as? String, !reason.isEmpty { return .done }
        return nil
    }
}

public enum ChatResponse {
    public static func text(from data: Data) throws -> String {
        guard data.count <= 2_000_000 else { throw ChatFailure.oversizedResponse }
        guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ChatFailure.malformedResponse }
        if let error = value["error"] as? [String: Any] { throw ChatFailure.provider(String((error["message"] as? String ?? "API request failed.").prefix(300))) }
        guard let choices = value["choices"] as? [[String: Any]], let first = choices.first,
              let message = first["message"] as? [String: Any], let text = message["content"] as? String, !text.isEmpty else { throw ChatFailure.emptyResponse }
        return text
    }
}

/// Unlike AsyncBytes.lines, this preserves empty lines, which delimit SSE events.
public struct SSEByteDecoder {
    private var line = Data()
    private var decoder = SSEDecoder()
    public init() {}
    public mutating func append(byte: UInt8) throws -> StreamEvent? {
        if byte == 10 {
            guard let text = String(data: line, encoding: .utf8) else { throw ChatFailure.malformedResponse }
            line.removeAll(keepingCapacity: true)
            return try decoder.append(line: text)
        }
        guard line.count < 262144 else { throw ChatFailure.oversizedResponse }
        line.append(byte)
        return nil
    }
    public mutating func flush() throws -> StreamEvent? {
        if !line.isEmpty {
            guard let text = String(data: line, encoding: .utf8) else { throw ChatFailure.malformedResponse }
            line.removeAll()
            if let event = try decoder.append(line: text) { return event }
        }
        return try decoder.flush()
    }
}
