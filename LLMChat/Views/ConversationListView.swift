import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @Query(sort: \Agent.createdAt) private var agents: [Agent]
    @State private var viewModel = ConversationListViewModel()
    @State private var navigationPath: [Conversation] = []
    @State private var modelManager = ModelManager.shared

    var filteredConversations: [Conversation] {
        if viewModel.searchText.isEmpty { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(viewModel.searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(filteredConversations) { conversation in
                    Button {
                        navigationPath = [conversation]
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(modelManager.modelName(for: conversation.modelId))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .foregroundStyle(.primary)
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
            .navigationTitle("Chats")
            .navigationDestination(for: Conversation.self) { conversation in
                ChatView(conversation: conversation, onNewChat: { newChat() })
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if agents.isEmpty {
                        Button {
                            newChat()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    } else {
                        Menu {
                            Button {
                                newChat()
                            } label: {
                                Label("New Chat", systemImage: "bubble.left")
                            }

                            Divider()

                            ForEach(agents) { agent in
                                Button {
                                    newChat(agent: agent)
                                } label: {
                                    Label(agent.name, systemImage: "person.circle")
                                }
                            }
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
        }
    }

    private func newChat(agent: Agent? = nil) {
        let convo = viewModel.createConversation(
            modelId: agent?.modelId ?? SettingsManager.defaultModelId,
            systemPrompt: agent?.systemPrompt,
            modelContext: modelContext
        )
        if let agent {
            convo.title = agent.name
        }
        // Replace the navigation stack so we navigate to the new chat
        navigationPath = [convo]
    }
}
