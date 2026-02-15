import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @Query(sort: \Memory.createdAt) private var memories: [Memory]
    @State private var apiKey: String = ""
    @State private var searchApiKey: String = ""
    @State private var searchProvider: SearchProvider = .tavily
    @State private var newMemory: String = ""
    @State private var defaultModelId: String = ""
    @State private var globalSystemPrompt: String = ""
    @State private var modelManager = ModelManager.shared
    @State private var showNewAgent = false
    @State private var editingAgent: Agent?

    // Track initial values to detect changes
    @State private var initialApiKey: String = ""
    @State private var initialSearchApiKey: String = ""
    @State private var initialSearchProvider: SearchProvider = .tavily
    @State private var initialModelId: String = ""
    @State private var initialSystemPrompt: String = ""

    private var hasChanges: Bool {
        apiKey != initialApiKey ||
        searchApiKey != initialSearchApiKey ||
        searchProvider != initialSearchProvider ||
        defaultModelId != initialModelId ||
        globalSystemPrompt != initialSystemPrompt
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("OpenRouter", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Picker("Search Provider", selection: $searchProvider) {
                        ForEach(SearchProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    SecureField("Search API Key", text: $searchApiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("OpenRouter: openrouter.ai/keys · Search: \(searchProvider.keyPlaceholder)")
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
                            HStack {
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
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(newMemory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("Memories")
                } footer: {
                    Text("Facts remembered across all chats. Say \"remember that...\" in a conversation, or add them here.")
                }
            }
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
                        if apiKey.isEmpty {
                            KeychainManager.deleteApiKey()
                        } else {
                            KeychainManager.setApiKey(apiKey)
                        }
                        if searchApiKey.isEmpty {
                            KeychainManager.deleteSearchApiKey()
                        } else {
                            KeychainManager.setSearchApiKey(searchApiKey)
                        }
                        SettingsManager.searchProvider = searchProvider
                        SettingsManager.defaultModelId = defaultModelId
                        SettingsManager.globalSystemPrompt = globalSystemPrompt.isEmpty ? nil : globalSystemPrompt
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(hasChanges ? .blue : .gray)
                    }
                }
            }
            .onAppear {
                apiKey = KeychainManager.apiKey() ?? ""
                searchApiKey = KeychainManager.searchApiKey() ?? ""
                searchProvider = SettingsManager.searchProvider
                defaultModelId = SettingsManager.defaultModelId
                globalSystemPrompt = SettingsManager.globalSystemPrompt ?? ""
                initialApiKey = apiKey
                initialSearchApiKey = searchApiKey
                initialSearchProvider = searchProvider
                initialModelId = defaultModelId
                initialSystemPrompt = globalSystemPrompt
            }
            .sheet(isPresented: $showNewAgent) {
                AgentEditorView()
            }
            .sheet(item: $editingAgent) { agent in
                AgentEditorView(agent: agent)
            }
        }
    }
}
