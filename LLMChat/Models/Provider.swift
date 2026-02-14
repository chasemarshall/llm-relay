import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case openai
    case anthropic
    case openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .openRouter: "OpenRouter"
        }
    }

    var baseURL: URL {
        switch self {
        case .openai: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        }
    }

    var availableModels: [(id: String, name: String)] {
        switch self {
        case .openai:
            [("gpt-4o", "GPT-4o"), ("gpt-4o-mini", "GPT-4o Mini"), ("o1", "o1"), ("o1-mini", "o1 Mini")]
        case .anthropic:
            [("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"), ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"), ("claude-opus-4-6", "Claude Opus 4.6")]
        case .openRouter:
            [("openai/gpt-4o", "GPT-4o"), ("anthropic/claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"), ("google/gemini-2.0-flash-exp", "Gemini 2.0 Flash"), ("meta-llama/llama-3.1-405b-instruct", "Llama 3.1 405B")]
        }
    }
}
