import Foundation

struct ChatMessage: Sendable {
    let role: String
    let content: String
}

protocol LLMService: Sendable {
    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error>
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
