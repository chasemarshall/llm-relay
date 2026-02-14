import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keys: [Provider: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(Provider.allCases) { provider in
                    Section(provider.displayName) {
                        SecureField("API Key", text: Binding(
                            get: { keys[provider] ?? "" },
                            set: { keys[provider] = $0 }
                        ))
                        .textContentType(.password)
                        .autocorrectionDisabled()

                        if let key = keys[provider], !key.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Key saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        for (provider, key) in keys {
                            if key.isEmpty {
                                KeychainManager.delete(key: "llmchat_apikey_\(provider.rawValue)")
                            } else {
                                KeychainManager.setApiKey(key, for: provider)
                            }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                for provider in Provider.allCases {
                    keys[provider] = KeychainManager.apiKey(for: provider) ?? ""
                }
            }
        }
    }
}
