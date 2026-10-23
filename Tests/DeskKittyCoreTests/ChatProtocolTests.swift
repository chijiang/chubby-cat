import Foundation
import DeskKittyCore

final class ChatProtocolTests {
    func testEndpointNormalizesBaseVersionAndFullEndpoint() throws {
        for (input, expected) in [
            ("https://api.example.com", "https://api.example.com/v1/chat/completions"),
            ("https://api.example.com/v1/", "https://api.example.com/v1/chat/completions"),
            ("https://api.example.com/custom/v2", "https://api.example.com/custom/v2/chat/completions"),
            ("http://localhost:8123/v1/chat/completions", "http://localhost:8123/v1/chat/completions")
        ] {
            expectEqual(try ChatEndpoint.url(from: input).absoluteString, expected)
        }
    }

    func testRemoteHTTPAndEmbeddedCredentialsAreRejected() {
        for input in ["http://example.com/v1", "https://user:pass@example.com", "file:///tmp/a", "https://example.com?key=secret", "not a URL"] {
            expectThrows(try ChatEndpoint.url(from: input), input)
        }
        expectNoThrow(try ChatEndpoint.url(from: "http://127.0.0.1:11434/v1"))
        expectNoThrow(try ChatEndpoint.url(from: "http://[::1]:11434/v1"))
    }

    func testRequestContainsCurrentConversationAndStreamingChoice() throws {
        let data = try ChatRequest(model: "tiny-cat", messages: [.init(role: "user", content: "hello")], stream: true).encoded()
        let value = try require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        expectEqual(value["model"] as? String, "tiny-cat")
        expectEqual(value["stream"] as? Bool, true)
        let messages = try require(value["messages"] as? [[String: String]])
        expectEqual(messages, [["role": "user", "content": "hello"]])
    }

    func testSSEHonorsEventBoundaryCommentsAndDone() throws {
        var decoder = SSEDecoder()
        expectNil(try decoder.append(line: ": keepalive"))
        expectNil(try decoder.append(line: "data: {\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}"))
        expectEqual(try decoder.append(line: ""), .text("你好"))
        expectNil(try decoder.append(line: "data: [DONE]"))
        expectEqual(try decoder.append(line: ""), .done)
    }

    func testSSEMultilineDataAndRoleOnlyChunks() throws {
        var decoder = SSEDecoder()
        _ = try decoder.append(line: "data: {\"choices\":")
        _ = try decoder.append(line: "data: [{\"delta\":{\"content\":\"cat\"}}]}")
        expectEqual(try decoder.append(line: ""), .text("cat"))
        _ = try decoder.append(line: "data: {\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}")
        expectNil(try decoder.append(line: ""))
    }

    func testMalformedAndProviderErrorFailClearly() throws {
        var malformed = SSEDecoder()
        _ = try malformed.append(line: "data: broken")
        expectThrows(try malformed.append(line: ""))
        var provider = SSEDecoder()
        _ = try provider.append(line: "data: {\"error\":{\"message\":\"Model unavailable\"}}")
        expectThrows(try provider.append(line: ""))
    }

    func testNonstreamingCompletionRejectsMissingAnswer() throws {
        let good = Data("{\"choices\":[{\"message\":{\"content\":\"Take a break.\"}}]}".utf8)
        expectEqual(try ChatResponse.text(from: good), "Take a break.")
        expectThrows(try ChatResponse.text(from: Data("{}".utf8)))
    }

    func testByteStreamPreservesBlankBoundariesAndUnicode() throws {
        let bytes = Data("data: {\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}\r\n\r\ndata: [DONE]\r\n\r\n".utf8)
        var decoder = SSEByteDecoder()
        var events: [StreamEvent] = []
        for byte in bytes { if let event = try decoder.append(byte: byte) { events.append(event) } }
        expectEqual(events, [.text("你好"), .done])
    }
}
