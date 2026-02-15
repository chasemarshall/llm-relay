import SwiftUI
import SwiftData

struct AgentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var modelManager = ModelManager.shared

    @State private var name: String
    @State private var selectedModelId: String
    @State private var systemPrompt: String

    let existingAgent: Agent?
    let onSave: (() -> Void)?

    init(agent: Agent? = nil, onSave: (() -> Void)? = nil) {
        self.existingAgent = agent
        self.onSave = onSave
        _name = State(initialValue: agent?.name ?? "")
        _selectedModelId = State(initialValue: agent?.modelId ?? SettingsManager.defaultModelId)
        _systemPrompt = State(initialValue: agent?.systemPrompt ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Code Assistant", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(modelManager.groupedModels) { group in
                            Section(group.displayName) {
                                ForEach(group.models) { model in
                                    Text(model.name).tag(model.id)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Model")
                }

                Section {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 120)
                } header: {
                    Text("Instructions")
                } footer: {
                    Text("Tell the agent how to behave and respond")
                }
            }
            .navigationTitle(existingAgent == nil ? "New Agent" : "Edit Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                        onSave?()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.tint, in: Circle())
                    }
                    .buttonStyle(.glass)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let agent = existingAgent {
            agent.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            agent.modelId = selectedModelId
            agent.systemPrompt = systemPrompt
        } else {
            let agent = Agent(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                modelId: selectedModelId,
                systemPrompt: systemPrompt
            )
            modelContext.insert(agent)
        }
        try? modelContext.save()
    }
}
