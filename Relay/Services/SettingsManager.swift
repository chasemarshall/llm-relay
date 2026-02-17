import Foundation

enum SearchProvider: String, CaseIterable, Sendable {
    case tavily
    case firecrawl

    var displayName: String {
        switch self {
        case .tavily: "Tavily"
        case .firecrawl: "Firecrawl"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .tavily: "tavily.com"
        case .firecrawl: "firecrawl.dev"
        }
    }

    var statusURL: URL? {
        switch self {
        case .tavily: nil
        case .firecrawl: URL(string: "https://status.firecrawl.dev")
        }
    }

    var statusFeedURL: URL? {
        switch self {
        case .tavily: nil
        case .firecrawl: URL(string: "https://status.firecrawl.dev/feed.rss")
        }
    }
}

enum SettingsManager {
    private static let legacyDefaultModelKey = "llmchat_default_model"
    private static let defaultModelKeyPrefix = "llmchat_default_model_"
    private static let globalSystemPromptKey = "llmchat_global_system_prompt"
    private static let searchProviderKey = "llmchat_search_provider"
    private static let aiProviderKey = "llmchat_ai_provider"
    private static let onboardingKey = "llmchat_has_completed_onboarding"
    private nonisolated(unsafe) static let defaults = UserDefaults.standard
    private static let migrationLock = NSLock()
    private nonisolated(unsafe) static var didMigrateDefaultModel = false

    private static func defaultModelKey(for provider: Provider) -> String {
        "\(defaultModelKeyPrefix)\(provider.rawValue)"
    }

    private static func migrateDefaultModelIfNeeded() {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        guard !didMigrateDefaultModel else { return }
        didMigrateDefaultModel = true

        guard let legacy = defaults.string(forKey: legacyDefaultModelKey), !legacy.isEmpty else { return }

        let provider = aiProvider
        let key = defaultModelKey(for: provider)
        if defaults.string(forKey: key) == nil {
            defaults.set(legacy, forKey: key)
        }
        defaults.removeObject(forKey: legacyDefaultModelKey)
    }

    static var aiProvider: Provider {
        get {
            guard let raw = defaults.string(forKey: aiProviderKey),
                  let provider = Provider(rawValue: raw) else { return .openRouter }
            return provider
        }
        set { defaults.set(newValue.rawValue, forKey: aiProviderKey) }
    }

    static func fallbackDefaultModelId(for provider: Provider) -> String {
        switch provider {
        case .openRouter: "anthropic/claude-haiku-4.5"
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-sonnet-4-5-20250514"
        }
    }

    static func defaultModelIdForProvider(_ provider: Provider) -> String {
        migrateDefaultModelIfNeeded()
        return defaults.string(forKey: defaultModelKey(for: provider)) ?? fallbackDefaultModelId(for: provider)
    }

    static func setDefaultModelId(_ modelId: String, for provider: Provider) {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: defaultModelKey(for: provider))
        } else {
            defaults.set(trimmed, forKey: defaultModelKey(for: provider))
        }
    }

    static var defaultModelId: String {
        get { defaultModelIdForProvider(aiProvider) }
        set { setDefaultModelId(newValue, for: aiProvider) }
    }

    /// Model selected during this app session; not persisted across launches.
    @MainActor static var sessionModelId: String?

    static var searchProvider: SearchProvider {
        get {
            guard let raw = defaults.string(forKey: searchProviderKey),
                  let provider = SearchProvider(rawValue: raw) else { return .tavily }
            return provider
        }
        set { defaults.set(newValue.rawValue, forKey: searchProviderKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: onboardingKey) }
        set { defaults.set(newValue, forKey: onboardingKey) }
    }

    static var globalSystemPrompt: String? {
        get {
            let val = defaults.string(forKey: globalSystemPromptKey)
            return (val?.isEmpty == true) ? nil : val
        }
        set { defaults.set(newValue, forKey: globalSystemPromptKey) }
    }
}
