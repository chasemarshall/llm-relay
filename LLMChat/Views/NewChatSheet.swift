import SwiftUI

struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: Provider = .openai
    @State private var selectedModelId: String = "gpt-4o"
    @State private var systemPrompt: String = ""
    let onCreate: (Provider, String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) {
                        if let first = selectedProvider.availableModels.first {
                            selectedModelId = first.id
                        }
                    }
                }

                Section("Model") {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(selectedProvider.availableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(selectedProvider, selectedModelId, systemPrompt.isEmpty ? nil : systemPrompt)
                        dismiss()
                    }
                }
            }
        }
    }
}
