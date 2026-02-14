import Foundation

enum ServiceFactory {
    static func service(for provider: Provider) -> LLMService {
        switch provider {
        case .openai:
            OpenAIService(baseURL: provider.baseURL)
        case .anthropic:
            AnthropicService()
        case .openRouter:
            OpenAIService(
                baseURL: provider.baseURL,
                extraHeaders: ["HTTP-Referer": "https://llmchat.app"]
            )
        }
    }
}
