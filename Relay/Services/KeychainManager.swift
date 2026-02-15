import Foundation

enum KeychainManager {
    private static let legacyApiKeyKey = "llmchat_apikey_openrouter"
    private static let legacySearchApiKeyKey = "llmchat_apikey_search"
    private nonisolated(unsafe) static let defaults = UserDefaults.standard
    private nonisolated(unsafe) static var didMigrate = false

    // MARK: - Migration

    private static func migrateIfNeeded() {
        guard !didMigrate else { return }
        didMigrate = true

        // Migrate old single AI key to per-provider format
        if let oldKey = defaults.string(forKey: legacyApiKeyKey), !oldKey.isEmpty {
            let newKey = "llmchat_apikey_\(Provider.openRouter.rawValue)"
            if defaults.string(forKey: newKey) == nil {
                defaults.set(oldKey, forKey: newKey)
            }
        }

        // Migrate old single search key to per-search-provider format
        if let oldKey = defaults.string(forKey: legacySearchApiKeyKey), !oldKey.isEmpty {
            let searchProvider = SettingsManager.searchProvider
            let newKey = "llmchat_apikey_search_\(searchProvider.rawValue)"
            if defaults.string(forKey: newKey) == nil {
                defaults.set(oldKey, forKey: newKey)
            }
        }
    }

    // MARK: - Per-Provider AI Keys

    static func apiKey(for provider: Provider) -> String? {
        migrateIfNeeded()
        let key = defaults.string(forKey: "llmchat_apikey_\(provider.rawValue)")
        if let key, key.isEmpty { return nil }
        return key
    }

    static func setApiKey(_ value: String, for provider: Provider) {
        defaults.set(value, forKey: "llmchat_apikey_\(provider.rawValue)")
    }

    static func deleteApiKey(for provider: Provider) {
        defaults.removeObject(forKey: "llmchat_apikey_\(provider.rawValue)")
    }

    /// Convenience: get key for the currently selected AI provider
    static func apiKey() -> String? {
        apiKey(for: SettingsManager.aiProvider)
    }

    static func setApiKey(_ value: String) {
        setApiKey(value, for: SettingsManager.aiProvider)
    }

    static func deleteApiKey() {
        deleteApiKey(for: SettingsManager.aiProvider)
    }

    // MARK: - Per-Search-Provider Keys

    static func searchApiKey(for provider: SearchProvider) -> String? {
        migrateIfNeeded()
        let key = defaults.string(forKey: "llmchat_apikey_search_\(provider.rawValue)")
        if let key, key.isEmpty { return nil }
        return key
    }

    static func setSearchApiKey(_ value: String, for provider: SearchProvider) {
        defaults.set(value, forKey: "llmchat_apikey_search_\(provider.rawValue)")
    }

    static func deleteSearchApiKey(for provider: SearchProvider) {
        defaults.removeObject(forKey: "llmchat_apikey_search_\(provider.rawValue)")
    }

    /// Convenience: get key for the currently selected search provider
    static func searchApiKey() -> String? {
        searchApiKey(for: SettingsManager.searchProvider)
    }

    static func setSearchApiKey(_ value: String) {
        setSearchApiKey(value, for: SettingsManager.searchProvider)
    }

    static func deleteSearchApiKey() {
        deleteSearchApiKey(for: SettingsManager.searchProvider)
    }
}
