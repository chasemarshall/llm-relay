import SwiftUI
import SwiftData

private enum ProviderStatus {
    case operational, incident, unknown

    var color: Color {
        switch self {
        case .operational: .green
        case .incident: .red
        case .unknown: .gray
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @Query(sort: \Memory.createdAt) private var memories: [Memory]
    @State private var aiProvider: Provider = .openRouter
    @State private var aiKeys: [Provider: String] = [:]
    @State private var searchKeys: [SearchProvider: String] = [:]
    @State private var searchProvider: SearchProvider = .tavily
    @State private var searchResultLimit: Int = 5
    @State private var memoryWritePolicy: MemoryWritePolicy = .ask
    @State private var newMemory: String = ""
    @State private var defaultModelId: String = ""
    @State private var globalSystemPrompt: String = ""
    @State private var modelManager = ModelManager.shared
    @State private var showNewAgent = false
    @State private var editingAgent: Agent?
    @State private var showClearChatsAlert = false
    @State private var hasChanges = false
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var providerStatus: ProviderStatus = .unknown
    @State private var searchProviderStatus: ProviderStatus = .unknown

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
                    HStack(spacing: 4) {
                        if let statusURL = aiProvider.statusURL {
                            Link(destination: statusURL) {
                                Circle()
                                    .fill(providerStatus.color)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text("Get your key at [\(aiProvider.keyPlaceholder)](https://\(aiProvider.keyPlaceholder))")
                    }
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
                    HStack(spacing: 4) {
                        if let statusURL = searchProvider.statusURL {
                            Link(destination: statusURL) {
                                Circle()
                                    .fill(searchProviderStatus.color)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text("Get your key at [\(searchProvider.keyPlaceholder)](https://\(searchProvider.keyPlaceholder))")
                    }
                }

                Section {
                    Stepper(value: $searchResultLimit, in: 1...20) {
                        Text("Sources per search: \(searchResultLimit)")
                    }

                    Picker("Memory writes", selection: $memoryWritePolicy) {
                        ForEach(MemoryWritePolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                } header: {
                    Text("Assistant Tools")
                } footer: {
                    Text("Use Ask to approve each save/forget memory request. Source limit applies to each web search request.")
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
                } footer: {
                    if let fetchError = modelManager.lastFetchError {
                        Text(fetchError)
                            .foregroundStyle(.orange)
                    }
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
                                do {
                                    try modelContext.save()
                                } catch {
                                    errorMessage = "Couldn't delete that agent. \(error.localizedDescription)"
                                }
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
                                do {
                                    try modelContext.save()
                                    hasChanges = true
                                } catch {
                                    errorMessage = "Couldn't delete that memory. \(error.localizedDescription)"
                                }
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
                            do {
                                try modelContext.save()
                                newMemory = ""
                                hasChanges = true
                            } catch {
                                errorMessage = "Couldn't save that memory. \(error.localizedDescription)"
                            }
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
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Something went wrong.")
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
                checkProviderStatus()
                checkSearchProviderStatus()
                Task {
                    await modelManager.fetchModels(for: aiProvider)
                }
            }
            .onChange(of: aiProvider) {
                if didLoad { hasChanges = true }
                modelManager.loadModels(for: aiProvider)
                defaultModelId = SettingsManager.defaultModelIdForProvider(aiProvider)
                checkProviderStatus()
                Task {
                    await modelManager.fetchModels(for: aiProvider)
                }
            }
            .onChange(of: aiKeys) { if didLoad { hasChanges = true } }
            .onChange(of: searchKeys) { if didLoad { hasChanges = true } }
            .onChange(of: searchProvider) {
                if didLoad { hasChanges = true }
                checkSearchProviderStatus()
            }
            .onChange(of: defaultModelId) { if didLoad { hasChanges = true } }
            .onChange(of: globalSystemPrompt) { if didLoad { hasChanges = true } }
            .onChange(of: searchResultLimit) { if didLoad { hasChanges = true } }
            .onChange(of: memoryWritePolicy) { if didLoad { hasChanges = true } }
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
                    } catch {
                        errorMessage = "Couldn't clear chats. \(error.localizedDescription)"
                    }
                }
            } message: {
                Text("This will permanently delete all conversations and messages. This cannot be undone.")
            }
        }
    }

    private func loadSettings() {
        aiProvider = SettingsManager.aiProvider
        searchProvider = SettingsManager.searchProvider
        searchResultLimit = SettingsManager.searchResultLimit
        memoryWritePolicy = SettingsManager.memoryWritePolicy
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
        SettingsManager.searchResultLimit = searchResultLimit
        SettingsManager.memoryWritePolicy = memoryWritePolicy
        SettingsManager.defaultModelId = defaultModelId
        SettingsManager.globalSystemPrompt = globalSystemPrompt.isEmpty ? nil : globalSystemPrompt
    }

    private func checkProviderStatus() {
        guard let feedURL = aiProvider.statusFeedURL else {
            providerStatus = .unknown
            return
        }
        fetchStatus(from: feedURL) { providerStatus = $0 }
    }

    private func checkSearchProviderStatus() {
        guard let feedURL = searchProvider.statusFeedURL else {
            searchProviderStatus = .unknown
            return
        }
        fetchStatus(from: feedURL) { searchProviderStatus = $0 }
    }

    private func fetchStatus(from url: URL, completion: @escaping (ProviderStatus) -> Void) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let delegate = RSSParserDelegate()
                let parser = XMLParser(data: data)
                parser.delegate = delegate
                parser.parse()

                let status: ProviderStatus
                if let latest = delegate.items.first {
                    let descLower = latest.description.lowercased()
                    let isResolved = descLower.contains("resolved") || descLower.contains("back to normal") || descLower.contains("operational")
                    let isOld = latest.pubDate.map { Date().timeIntervalSince($0) > 86_400 } ?? false
                    if isResolved || isOld {
                        status = .operational
                    } else {
                        status = .incident
                    }
                } else {
                    status = .operational
                }

                await MainActor.run { completion(status) }
            } catch {
                await MainActor.run { completion(.unknown) }
            }
        }
    }
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    struct Item {
        var title: String = ""
        var description: String = ""
        var pubDate: Date?
    }

    var items: [Item] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var insideItem = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            insideItem = true
            currentTitle = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" {
            insideItem = false
            let item = Item(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: Self.dateFormatter.date(from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            items.append(item)
        }
    }
}
