import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @State private var viewModel = ConversationListViewModel()
    @State private var navigationPath: [Conversation] = []
    @State private var modelManager = ModelManager.shared
    @State private var renamingConversation: Conversation?
    @State private var renameText: String = ""

    var filteredConversations: [Conversation] {
        let list = viewModel.searchText.isEmpty ? conversations : conversations.filter {
            $0.title.localizedCaseInsensitiveContains(viewModel.searchText)
        }
        return list.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(filteredConversations) { conversation in
                    Button {
                        navigationPath = [conversation]
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    if conversation.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(conversation.title)
                                        .font(.body)
                                        .lineLimit(1)
                                }
                                HStack(spacing: 6) {
                                    Text(modelManager.modelName(for: conversation.modelId))
                                    Text("·")
                                    Text(timeAgo(conversation.updatedAt))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .contextMenu {
                        Button {
                            renameText = conversation.title
                            renamingConversation = conversation
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            conversation.isPinned.toggle()
                            try? modelContext.save()
                        } label: {
                            Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        Divider()
                        Button(role: .destructive) {
                            if navigationPath.first?.id == conversation.id {
                                navigationPath = []
                            }
                            viewModel.deleteConversation(conversation, modelContext: modelContext)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if navigationPath.first?.id == conversation.id {
                                navigationPath = []
                            }
                            viewModel.deleteConversation(conversation, modelContext: modelContext)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search chats")
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width < -50 && abs(value.translation.height) < 50 {
                            newChat()
                        }
                    }
            )
            .navigationTitle("Chats")
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation, modelContext: modelContext, onNewChat: { newChat() })
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            newChat()
                        } label: {
                            Label("New Chat", systemImage: "bubble.left")
                        }

                        if !agents.isEmpty {
                            Divider()

                            ForEach(agents) { agent in
                                Button {
                                    newChat(agent: agent)
                                } label: {
                                    Label(agent.name, systemImage: agent.iconName ?? "person.circle")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .alert("Rename Chat", isPresented: Binding(
                get: { renamingConversation != nil },
                set: { if !$0 { renamingConversation = nil } }
            )) {
                TextField("Chat name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingConversation = nil }
                Button("Save") {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let convo = renamingConversation {
                        convo.title = trimmed
                        try? modelContext.save()
                    }
                    renamingConversation = nil
                }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        return "\(weeks)w"
    }

    private func newChat(agent: Agent? = nil) {
        let convo = viewModel.makeDraftConversation(
            provider: SettingsManager.aiProvider,
            modelId: agent?.modelId ?? SettingsManager.sessionModelId ?? SettingsManager.defaultModelId,
            systemPrompt: agent?.systemPrompt
        )
        if let agent {
            convo.title = agent.name
        }
        if navigationPath.isEmpty {
            navigationPath = [convo]
        } else {
            navigationPath = []
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigationPath = [convo]
            }
        }
    }
}
