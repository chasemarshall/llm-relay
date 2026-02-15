import Foundation

struct ToolDefinition: @unchecked Sendable {
    let name: String
    let description: String
    let parameters: [String: Any]
}

struct ToolCall: Sendable {
    var id: String
    var name: String
    var arguments: String
}

struct ChatMessage: Sendable {
    let role: String
    let content: String
    let imageBase64: String?
    let toolCallId: String?
    let toolCalls: [ToolCall]?

    init(role: String, content: String, imageBase64: String? = nil,
         toolCallId: String? = nil, toolCalls: [ToolCall]? = nil) {
        self.role = role
        self.content = content
        self.imageBase64 = imageBase64
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
    }
}

enum StreamToken: Sendable {
    case content(String)
    case reasoning(String)
    case toolCall(index: Int, id: String?, name: String?, arguments: String?)
    case finishReason(String)
    case usage(promptTokens: Int, completionTokens: Int)
}

protocol LLMService: Sendable {
    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String,
        tools: [ToolDefinition],
        forceToolName: String?
    ) -> AsyncThrowingStream<StreamToken, Error>
}

extension LLMService {
    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<StreamToken, Error> {
        streamCompletion(messages: messages, model: model, apiKey: apiKey, tools: [], forceToolName: nil)
    }
}

enum LLMError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "Invalid API key. Check your settings."
        case .rateLimited: "Rate limited. Please wait a moment."
        case .networkError(let msg): "Network error: \(msg)"
        case .invalidResponse(let msg): "Invalid response: \(msg)"
        }
    }
}
