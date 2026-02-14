import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var viewModel = ConversationListViewModel()
    @State private var selectedConversation: Conversation?

    var filteredConversations: [Conversation] {
        if viewModel.searchText.isEmpty { return conversations }
        return conversations.filter {
            $0.title.localizedCaseInsensitiveContains(viewModel.searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            List(filteredConversations, selection: $selectedConversation) { conversation in
                NavigationLink(value: conversation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.headline)
                            .lineLimit(1)
                        HStack {
                            Text(conversation.provider.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\u{00B7}")
                                .foregroundStyle(.tertiary)
                            Text(conversation.modelId)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.deleteConversation(conversation, modelContext: modelContext)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search chats")
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
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
            .sheet(isPresented: $viewModel.showNewChat) {
                NewChatSheet { provider, modelId, systemPrompt in
                    let convo = viewModel.createConversation(
                        provider: provider,
                        modelId: modelId,
                        systemPrompt: systemPrompt,
                        modelContext: modelContext
                    )
                    selectedConversation = convo
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
        } detail: {
            if let conversation = selectedConversation {
                ChatView(conversation: conversation)
            } else {
                ContentUnavailableView(
                    "No Chat Selected",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Select a conversation or create a new one")
                )
            }
        }
    }
}
