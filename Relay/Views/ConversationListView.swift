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
    @State private var listWidth: CGFloat = 0
    @State private var errorMessage: String?

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
                        HStack(spacing: AppTheme.Spacing.small) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    if conversation.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(conversation.title)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
                                }
                                HStack(spacing: AppTheme.Spacing.xSmall) {
                                    Text(modelManager.modelName(for: conversation.modelId))
                                    Text("·")
                                    Text(timeAgo(conversation.updatedAt))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.9))
                                .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, AppTheme.Spacing.small)
                        .padding(.vertical, 8)
                        .background(
                            conversation.isPinned ? AppTheme.Colors.pinnedTint : Color.clear,
                            in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        )
                        .animation(.easeInOut(duration: AppTheme.Motion.quick), value: conversation.isPinned)
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
                            do {
                                try modelContext.save()
                            } catch {
                                conversation.isPinned.toggle()
                                errorMessage = "Couldn't update pin state. \(error.localizedDescription)"
                            }
                        } label: {
                            Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: conversation.isPinned ? "pin.slash" : "pin")
                        }
                        Divider()
                        Button(role: .destructive) {
                            deleteConversation(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteConversation(conversation)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
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
            .listStyle(.insetGrouped)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            listWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { _, width in
                            listWidth = width
                        }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search chats")
            .simultaneousGesture(
                DragGesture(minimumDistance: 60)
                    .onEnded { value in
                        // Only trigger if swipe started from the right edge of the screen
                        let width = listWidth > 0 ? listWidth : 390
                        if value.startLocation.x > width * 0.7
                            && value.translation.width < -60
                            && abs(value.translation.height) < 50 {
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

                            let sortedAgents = agents.sorted {
                                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                            }

                            ForEach(sortedAgents) { agent in
                                Button {
                                    newChat(agent: agent)
                                } label: {
                                    Text(agent.name)
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
                        do {
                            try modelContext.save()
                        } catch {
                            errorMessage = "Couldn't rename that chat. \(error.localizedDescription)"
                        }
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

    private func deleteConversation(_ conversation: Conversation) {
        if navigationPath.first?.id == conversation.id {
            navigationPath = []
        }
        do {
            try viewModel.deleteConversation(conversation, modelContext: modelContext)
        } catch {
            errorMessage = "Couldn't delete that chat. \(error.localizedDescription)"
        }
    }
}
