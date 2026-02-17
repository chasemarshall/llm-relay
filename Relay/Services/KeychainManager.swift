import Foundation
import Security

enum KeychainManager {
    private static let legacyApiKeyKey = "llmchat_apikey_openrouter"
    private static let legacySearchApiKeyKey = "llmchat_apikey_search"
    private static let keychainService = "com.relay.app.keys"
    private nonisolated(unsafe) static let defaults = UserDefaults.standard
    private static let migrationLock = NSLock()
    private nonisolated(unsafe) static var didMigrate = false

    private static func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }

    private static func readFromKeychain(account: String) -> String? {
        var query = keychainQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = kCFBooleanTrue

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private static func writeToKeychain(value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query = keychainQuery(account: account)

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return true
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        return addStatus == errSecSuccess || addStatus == errSecDuplicateItem
    }

    private static func deleteFromKeychain(account: String) {
        SecItemDelete(keychainQuery(account: account) as CFDictionary)
    }

    private static func migrateAccountIfNeeded(_ account: String) {
        guard let value = defaults.string(forKey: account), !value.isEmpty else { return }
        if let existing = readFromKeychain(account: account), !existing.isEmpty {
            defaults.removeObject(forKey: account)
            return
        }
        if writeToKeychain(value: value, account: account) {
            defaults.removeObject(forKey: account)
        }
    }

    // MARK: - Migration

    private static func migrateIfNeeded() {
        migrationLock.lock()
        defer { migrationLock.unlock() }

        guard !didMigrate else { return }
        didMigrate = true

        for provider in Provider.allCases {
            migrateAccountIfNeeded("llmchat_apikey_\(provider.rawValue)")
        }
        for provider in SearchProvider.allCases {
            migrateAccountIfNeeded("llmchat_apikey_search_\(provider.rawValue)")
        }

        // Migrate old single AI key to per-provider format
        if let oldKey = defaults.string(forKey: legacyApiKeyKey), !oldKey.isEmpty {
            let newKey = "llmchat_apikey_\(Provider.openRouter.rawValue)"
            if let existing = readFromKeychain(account: newKey), !existing.isEmpty {
                defaults.removeObject(forKey: legacyApiKeyKey)
            } else if writeToKeychain(value: oldKey, account: newKey) {
                defaults.removeObject(forKey: legacyApiKeyKey)
            }
        }

        // Migrate old single search key to per-search-provider format
        if let oldKey = defaults.string(forKey: legacySearchApiKeyKey), !oldKey.isEmpty {
            let searchProvider = SettingsManager.searchProvider
            let newKey = "llmchat_apikey_search_\(searchProvider.rawValue)"
            if let existing = readFromKeychain(account: newKey), !existing.isEmpty {
                defaults.removeObject(forKey: legacySearchApiKeyKey)
            } else if writeToKeychain(value: oldKey, account: newKey) {
                defaults.removeObject(forKey: legacySearchApiKeyKey)
            }
        }
    }

    // MARK: - Per-Provider AI Keys

    static func apiKey(for provider: Provider) -> String? {
        migrateIfNeeded()
        let key = readFromKeychain(account: "llmchat_apikey_\(provider.rawValue)")
        if let key, key.isEmpty { return nil }
        return key
    }

    static func setApiKey(_ value: String, for provider: Provider) {
        migrateIfNeeded()
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            deleteApiKey(for: provider)
        } else {
            writeToKeychain(value: key, account: "llmchat_apikey_\(provider.rawValue)")
        }
    }

    static func deleteApiKey(for provider: Provider) {
        migrateIfNeeded()
        deleteFromKeychain(account: "llmchat_apikey_\(provider.rawValue)")
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
        let key = readFromKeychain(account: "llmchat_apikey_search_\(provider.rawValue)")
        if let key, key.isEmpty { return nil }
        return key
    }

    static func setSearchApiKey(_ value: String, for provider: SearchProvider) {
        migrateIfNeeded()
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            deleteSearchApiKey(for: provider)
        } else {
            writeToKeychain(value: key, account: "llmchat_apikey_search_\(provider.rawValue)")
        }
    }

    static func deleteSearchApiKey(for provider: SearchProvider) {
        migrateIfNeeded()
        deleteFromKeychain(account: "llmchat_apikey_search_\(provider.rawValue)")
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
