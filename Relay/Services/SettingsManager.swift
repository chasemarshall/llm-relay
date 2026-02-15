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
}

enum SettingsManager {
    private static let defaultModelKey = "llmchat_default_model"
    private static let globalSystemPromptKey = "llmchat_global_system_prompt"
    private static let searchProviderKey = "llmchat_search_provider"
    private static let aiProviderKey = "llmchat_ai_provider"
    private static let onboardingKey = "llmchat_has_completed_onboarding"

    static var aiProvider: Provider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: aiProviderKey),
                  let provider = Provider(rawValue: raw) else { return .openRouter }
            return provider
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: aiProviderKey) }
    }

    static func defaultModelId(for provider: Provider) -> String {
        switch provider {
        case .openRouter: "anthropic/claude-haiku-4.5"
        case .openAI: "gpt-4o-mini"
        case .anthropic: "claude-sonnet-4-5-20250514"
        }
    }

    static var defaultModelId: String {
        get { UserDefaults.standard.string(forKey: defaultModelKey) ?? defaultModelId(for: aiProvider) }
        set { UserDefaults.standard.set(newValue, forKey: defaultModelKey) }
    }

    /// Model selected during this app session; not persisted across launches.
    @MainActor static var sessionModelId: String?

    static var searchProvider: SearchProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: searchProviderKey),
                  let provider = SearchProvider(rawValue: raw) else { return .tavily }
            return provider
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: searchProviderKey) }
    }

    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingKey) }
    }

    static var globalSystemPrompt: String? {
        get {
            let val = UserDefaults.standard.string(forKey: globalSystemPromptKey)
            return (val?.isEmpty == true) ? nil : val
        }
        set { UserDefaults.standard.set(newValue, forKey: globalSystemPromptKey) }
    }
}
