import Foundation

struct OpenRouterModel: Identifiable, Codable, Sendable {
    let id: String
    let name: String
}

@MainActor @Observable
final class ModelManager {
    static let shared = ModelManager()

    var models: [OpenRouterModel] = []
    var isLoading = false
    var currentProvider: Provider = .openRouter

    private static func cacheKey(for provider: Provider) -> String {
        "llmchat_cached_models_\(provider.rawValue)"
    }

    static let openRouterDefaults: [OpenRouterModel] = [
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

    static let openAIDefaults: [OpenRouterModel] = [
        OpenRouterModel(id: "gpt-4o", name: "GPT-4o"),
        OpenRouterModel(id: "gpt-4o-mini", name: "GPT-4o Mini"),
        OpenRouterModel(id: "gpt-4.1", name: "GPT-4.1"),
        OpenRouterModel(id: "gpt-4.1-mini", name: "GPT-4.1 Mini"),
        OpenRouterModel(id: "gpt-4.1-nano", name: "GPT-4.1 Nano"),
        OpenRouterModel(id: "o3-mini", name: "o3-mini"),
    ]

    static let anthropicDefaults: [OpenRouterModel] = [
        OpenRouterModel(id: "claude-sonnet-4-5-20250514", name: "Claude Sonnet 4.5"),
        OpenRouterModel(id: "claude-haiku-4-5-20251001", name: "Claude Haiku 4.5"),
        OpenRouterModel(id: "claude-opus-4-6-20250610", name: "Claude Opus 4.6"),
    ]

    static func defaultModels(for provider: Provider) -> [OpenRouterModel] {
        switch provider {
        case .openRouter: openRouterDefaults
        case .openAI: openAIDefaults
        case .anthropic: anthropicDefaults
        }
    }

    private init() {
        let provider = SettingsManager.aiProvider
        currentProvider = provider
        loadModels(for: provider)
    }

    func loadModels(for provider: Provider) {
        currentProvider = provider
        // Try loading from cache first
        let key = Self.cacheKey(for: provider)
        if let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode([OpenRouterModel].self, from: data),
           !cached.isEmpty {
            models = cached
        } else {
            models = Self.defaultModels(for: provider)
        }
    }

    func fetchModels(for provider: Provider? = nil) async {
        let target = provider ?? currentProvider
        // Anthropic has no model list endpoint — use hardcoded list
        if target == .anthropic {
            models = Self.anthropicDefaults
            cache(models, for: target)
            return
        }

        guard let apiKey = KeychainManager.apiKey(for: target) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let url = target.baseURL.appendingPathComponent("models")
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            if target == .openRouter {
                request.setValue("https://llmchat.app", forHTTPHeaderField: "HTTP-Referer")
            }

            let (data, _) = try await URLSession.shared.data(for: request)

            struct ModelsResponse: Codable {
                let data: [ModelEntry]
                struct ModelEntry: Codable {
                    let id: String
                    let name: String?
                }
            }

            let response = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let fetched = response.data.map { OpenRouterModel(id: $0.id, name: $0.name ?? $0.id) }

            if !fetched.isEmpty {
                models = fetched
                cache(fetched, for: target)
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
            // OpenRouter models have "provider/model" format; OpenAI/Anthropic don't
            let parts = model.id.components(separatedBy: "/")
            return parts.count > 1 ? parts[0] : currentProvider.displayName.lowercased()
        }
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

    private func cache(_ models: [OpenRouterModel], for provider: Provider) {
        if let data = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey(for: provider))
        }
    }
}
