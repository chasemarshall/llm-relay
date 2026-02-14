import Foundation

enum ServiceFactory {
    static func service(for provider: Provider) -> LLMService {
        OpenAIService(
            baseURL: provider.baseURL,
            extraHeaders: ["HTTP-Referer": "https://llmchat.app"]
        )
    }
}
