import Foundation

enum KeychainManager {
    private static let apiKeyKey = "llmchat_apikey_openrouter"
    private nonisolated(unsafe) static let defaults = UserDefaults.standard

    static func apiKey(for provider: Provider) -> String? {
        apiKey()
    }

    static func setApiKey(_ value: String, for provider: Provider) {
        setApiKey(value)
    }

    static func apiKey() -> String? {
        let key = defaults.string(forKey: apiKeyKey)
        if let key, key.isEmpty { return nil }
        return key
    }

    static func setApiKey(_ value: String) {
        defaults.set(value, forKey: apiKeyKey)
    }

    static func deleteApiKey() {
        defaults.removeObject(forKey: apiKeyKey)
    }
}
