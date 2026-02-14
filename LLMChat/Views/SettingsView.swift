import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @Query(sort: \Memory.createdAt) private var memories: [Memory]
    @State private var apiKey: String = ""
    @State private var newMemory: String = ""
    @State private var defaultModelId: String = ""
    @State private var globalSystemPrompt: String = ""
    @State private var modelManager = ModelManager.shared
    @State private var showNewAgent = false
    @State private var editingAgent: Agent?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("OpenRouter API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()

                    if !apiKey.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Key saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Get your key at openrouter.ai/keys")
                }

                Section("Default Model") {
                    Picker("Model", selection: $defaultModelId) {
                        // Ensure current selection always has a tag
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
                }

                Section {
                    TextEditor(text: $globalSystemPrompt)
                        .frame(minHeight: 80)
                } header: {
                    Text("Global System Prompt")
                } footer: {
                    Text("Applied to all new chats unless overridden")
                }

                Section {
                    ForEach(agents) { agent in
                        Button {
                            editingAgent = agent
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(agent.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(modelManager.modelName(for: agent.modelId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !agent.systemPrompt.isEmpty {
                                    Text(agent.systemPrompt)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(agent)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        showNewAgent = true
                    } label: {
                        Label("Create Agent", systemImage: "plus")
                    }
                } header: {
                    Text("Agents")
                } footer: {
                    Text("Custom agents with their own model and instructions")
                }

                Section {
                    ForEach(memories) { memory in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.content)
                                .font(.body)
                            HStack(spacing: 4) {
                                Image(systemName: memory.source == "auto" ? "sparkles" : "hand.draw")
                                    .font(.system(size: 9))
                                Text(memory.source == "auto" ? "Auto" : "Manual")
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
                    Text("The AI automatically learns facts about you, or say \"remember that...\" in chat. You can also add memories manually here.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if apiKey.isEmpty {
                            KeychainManager.deleteApiKey()
                        } else {
                            KeychainManager.setApiKey(apiKey)
                        }
                        SettingsManager.defaultModelId = defaultModelId
                        SettingsManager.globalSystemPrompt = globalSystemPrompt.isEmpty ? nil : globalSystemPrompt
                        dismiss()
                    }
                }
            }
            .onAppear {
                apiKey = KeychainManager.apiKey() ?? ""
                defaultModelId = SettingsManager.defaultModelId
                globalSystemPrompt = SettingsManager.globalSystemPrompt ?? ""
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
