import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case openRouter
    case openAI
    case anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openRouter: "OpenRouter"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }

    var baseURL: URL {
        switch self {
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        case .openAI: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openRouter: "openrouter.ai/keys"
        case .openAI: "platform.openai.com/api-keys"
        case .anthropic: "console.anthropic.com/settings/keys"
        }
    }

    var statusURL: URL? {
        switch self {
        case .openRouter: URL(string: "https://status.openrouter.ai")
        case .openAI: URL(string: "https://status.openai.com")
        case .anthropic: URL(string: "https://status.claude.com")
        }
    }

    var statusFeedURL: URL? {
        switch self {
        case .openRouter: URL(string: "https://status.openrouter.ai/incidents.rss")
        case .openAI: URL(string: "https://status.openai.com/feed.rss")
        case .anthropic: URL(string: "https://status.claude.com/history.rss")
        }
    }

    var usesOpenAIFormat: Bool {
        switch self {
        case .openRouter, .openAI: true
        case .anthropic: false
        }
    }

    func createService() -> LLMService {
        switch self {
        case .openRouter:
            OpenAIService(baseURL: baseURL, extraHeaders: ["HTTP-Referer": "https://relay.app"])
        case .openAI:
            OpenAIService(baseURL: baseURL)
        case .anthropic:
            AnthropicService(baseURL: baseURL)
        }
    }
}
