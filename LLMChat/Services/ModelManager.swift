import Foundation

struct OpenRouterModel: Identifiable, Codable, Sendable {
    let id: String
    let name: String
}

@MainActor @Observable
final class ModelManager {
    static let shared = ModelManager()

    var models: [OpenRouterModel] = ModelManager.defaultModels
    var isLoading = false

    private static let cacheKey = "llmchat_cached_models"

    static let defaultModels: [OpenRouterModel] = [
        OpenRouterModel(id: "anthropic/claude-haiku-4.5", name: "Claude Haiku 4.5"),
        OpenRouterModel(id: "anthropic/claude-sonnet-4.5", name: "Claude Sonnet 4.5"),
        OpenRouterModel(id: "anthropic/claude-opus-4.6", name: "Claude Opus 4.6"),
        OpenRouterModel(id: "openai/gpt-4o", name: "GPT-4o"),
        OpenRouterModel(id: "openai/gpt-4o-mini", name: "GPT-4o Mini"),
        OpenRouterModel(id: "google/gemini-3-flash-preview", name: "Gemini 3 Flash"),
        OpenRouterModel(id: "deepseek/deepseek-v3.2", name: "DeepSeek V3.2"),
        OpenRouterModel(id: "mistralai/mistral-large-2512", name: "Mistral Large"),
        OpenRouterModel(id: "meta-llama/llama-4-maverick", name: "Llama 4 Maverick"),
    ]

    static let defaultModelId = "anthropic/claude-haiku-4.5"

    private init() {
        loadCached()
    }

    func fetchModels() async {
        guard let apiKey = KeychainManager.apiKey() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await URLSession.shared.data(for: request)

            struct ModelsResponse: Codable {
                let data: [ModelEntry]
                struct ModelEntry: Codable {
                    let id: String
                    let name: String
                }
            }

            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let fetched = response.data.map { OpenRouterModel(id: $0.id, name: $0.name) }

            if !fetched.isEmpty {
                models = fetched
                cache(fetched)
            }
        } catch {
            // Keep using cached/default models
        }
    }

    struct ModelGroup: Identifiable {
        let provider: String
        let models: [OpenRouterModel]
        var id: String { provider }

        var displayName: String {
            let names: [String: String] = [
                "anthropic": "Anthropic",
                "openai": "OpenAI",
                "google": "Google",
                "meta-llama": "Meta",
                "mistralai": "Mistral",
                "deepseek": "DeepSeek",
                "cohere": "Cohere",
                "perplexity": "Perplexity",
                "x-ai": "xAI",
                "qwen": "Qwen",
            ]
            return names[provider] ?? provider.capitalized
        }
    }

    var groupedModels: [ModelGroup] {
        let grouped = Dictionary(grouping: models) { model -> String in
            model.id.components(separatedBy: "/").first ?? "other"
        }
        // Sort providers: prioritize well-known ones first
        let priority = ["anthropic", "openai", "google", "meta-llama", "mistralai", "deepseek", "x-ai"]
        return grouped
            .map { ModelGroup(provider: $0.key, models: $0.value) }
            .sorted { a, b in
                let ai = priority.firstIndex(of: a.provider) ?? Int.max
                let bi = priority.firstIndex(of: b.provider) ?? Int.max
                if ai != bi { return ai < bi }
                return a.provider < b.provider
            }
    }

    func modelName(for id: String) -> String {
        models.first(where: { $0.id == id })?.name ?? id
    }

    private func cache(_ models: [OpenRouterModel]) {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    private func loadCached() {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey),
              let cached = try? JSONDecoder().decode([OpenRouterModel].self, from: data),
              !cached.isEmpty else { return }
        models = cached
    }
}
