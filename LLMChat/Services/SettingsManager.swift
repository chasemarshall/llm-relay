import Foundation

enum SettingsManager {
    private static let defaultModelKey = "llmchat_default_model"
    private static let globalSystemPromptKey = "llmchat_global_system_prompt"
    private static let fallbackModelId = "anthropic/claude-haiku-4.5"

    static var defaultModelId: String {
        get { UserDefaults.standard.string(forKey: defaultModelKey) ?? fallbackModelId }
        set { UserDefaults.standard.set(newValue, forKey: defaultModelKey) }
    }

    static var globalSystemPrompt: String? {
        get {
            let val = UserDefaults.standard.string(forKey: globalSystemPromptKey)
            return (val?.isEmpty == true) ? nil : val
        }
        set { UserDefaults.standard.set(newValue, forKey: globalSystemPromptKey) }
    }
}
