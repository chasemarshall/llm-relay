import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @Query(sort: \Memory.createdAt) private var memories: [Memory]
    @State private var aiProvider: Provider = .openRouter
    @State private var aiKeys: [Provider: String] = [:]
    @State private var searchKeys: [SearchProvider: String] = [:]
    @State private var searchProvider: SearchProvider = .tavily
    @State private var newMemory: String = ""
    @State private var defaultModelId: String = ""
    @State private var globalSystemPrompt: String = ""
    @State private var modelManager = ModelManager.shared
    @State private var showNewAgent = false
    @State private var editingAgent: Agent?
    @State private var showClearChatsAlert = false
    @State private var hasChanges = false
    @State private var didLoad = false

    private var currentAiKey: Binding<String> {
        Binding(
            get: { aiKeys[aiProvider] ?? "" },
            set: { aiKeys[aiProvider] = $0 }
        )
    }

    private var currentSearchKey: Binding<String> {
        Binding(
            get: { searchKeys[searchProvider] ?? "" },
            set: { searchKeys[searchProvider] = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $aiProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    SecureField("API Key", text: currentAiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                } header: {
                    Text("AI Provider")
                } footer: {
                    Link("Get your key at \(aiProvider.keyPlaceholder)", destination: URL(string: "https://\(aiProvider.keyPlaceholder)")!)
                }

                Section {
                    Picker("Provider", selection: $searchProvider) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    SecureField("API Key", text: currentSearchKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                } header: {
                    Text("Web Search")
                } footer: {
                    Link("Get your key at \(searchProvider.keyPlaceholder)", destination: URL(string: "https://\(searchProvider.keyPlaceholder)")!)
                }

                Section {
                    Picker("Model", selection: $defaultModelId) {
                        if !modelManager.models.contains(where: { $0.id == defaultModelId }) {
                            Text(defaultModelId).tag(defaultModelId)
                        }
                        ForEach(modelManager.groupedModels) { group in
                            Section(group.displayName) {
                                ForEach(group.models) { model in
                                    Text(model.name).tag(model.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Default Model")
                }

                Section {
                    TextEditor(text: $globalSystemPrompt)
                        .frame(minHeight: 80)
                } header: {
                    Text("System Prompt")
                } footer: {
                    Text("Applied to all new chats unless overridden by an agent")
                }

                Section {
                    ForEach(agents) { agent in
                        Button {
                            editingAgent = agent
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: agent.iconName ?? "person.circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(agent.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(modelManager.modelName(for: agent.modelId))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(agent)
                                try? modelContext.save()
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    Button {
                        showNewAgent = true
                    } label: {
                        Label("New Agent", systemImage: "plus")
                    }
                } header: {
                    Text("Agents")
                }

                Section {
                    ForEach(memories) { memory in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.content)
                                .font(.body)
                            HStack(spacing: 4) {
                                Image(systemName: memory.source == "auto" ? "sparkles" : "hand.draw")
                                    .font(.system(size: 9))
                                Text(memory.source == "auto" ? "Learned" : "Added by you")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.tertiary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(memory)
                                try? modelContext.save()
                                hasChanges = true
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }

                    HStack {
                        TextField("Add a memory...", text: $newMemory)
                        Button {
                            let trimmed = newMemory.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            let memory = Memory(content: trimmed)
                            modelContext.insert(memory)
                            try? modelContext.save()
                            newMemory = ""
                            hasChanges = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Memories")
                } footer: {
                    Text("Facts remembered across all chats. The model saves memories automatically when you share important details, or add them here.")
                }

                Section {
                    Button(role: .destructive) {
                        showClearChatsAlert = true
                    } label: {
                        Text("Clear All Chats")
                    }
                } header: {
                    Text("Data")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveSettings()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasChanges ? .blue : .gray)
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
            .onChange(of: aiProvider) {
                if didLoad { hasChanges = true }
                modelManager.loadModels(for: aiProvider)
                defaultModelId = SettingsManager.defaultModelId(for: aiProvider)
            }
            .onChange(of: aiKeys) { if didLoad { hasChanges = true } }
            .onChange(of: searchKeys) { if didLoad { hasChanges = true } }
            .onChange(of: searchProvider) { if didLoad { hasChanges = true } }
            .onChange(of: defaultModelId) { if didLoad { hasChanges = true } }
            .onChange(of: globalSystemPrompt) { if didLoad { hasChanges = true } }
            .sheet(isPresented: $showNewAgent) {
                AgentEditorView()
            }
            .sheet(item: $editingAgent) { agent in
                AgentEditorView(agent: agent)
            }
            .alert("Clear All Chats?", isPresented: $showClearChatsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    do {
                        try modelContext.delete(model: Conversation.self)
                        try modelContext.save()
                    } catch { }
                }
            } message: {
                Text("This will permanently delete all conversations and messages. This cannot be undone.")
            }
        }
    }

    private func loadSettings() {
        aiProvider = SettingsManager.aiProvider
        searchProvider = SettingsManager.searchProvider
        defaultModelId = SettingsManager.defaultModelId
        globalSystemPrompt = SettingsManager.globalSystemPrompt ?? ""

        // Load all provider keys
        for provider in Provider.allCases {
            aiKeys[provider] = KeychainManager.apiKey(for: provider) ?? ""
        }
        for provider in SearchProvider.allCases {
            searchKeys[provider] = KeychainManager.searchApiKey(for: provider) ?? ""
        }

        // Load models for current provider
        modelManager.loadModels(for: aiProvider)

        // Allow change tracking now that initial values are set
        DispatchQueue.main.async { didLoad = true }
    }

    private func saveSettings() {
        // Save AI provider keys
        for provider in Provider.allCases {
            let key = aiKeys[provider] ?? ""
            if key.isEmpty {
                KeychainManager.deleteApiKey(for: provider)
            } else {
                KeychainManager.setApiKey(key, for: provider)
            }
        }

        // Save search provider keys
        for provider in SearchProvider.allCases {
            let key = searchKeys[provider] ?? ""
            if key.isEmpty {
                KeychainManager.deleteSearchApiKey(for: provider)
            } else {
                KeychainManager.setSearchApiKey(key, for: provider)
            }
        }

        SettingsManager.aiProvider = aiProvider
        SettingsManager.searchProvider = searchProvider
        SettingsManager.defaultModelId = defaultModelId
        SettingsManager.globalSystemPrompt = globalSystemPrompt.isEmpty ? nil : globalSystemPrompt
    }
}
