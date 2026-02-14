import SwiftUI
import SwiftData

@MainActor @Observable
final class ConversationListViewModel {
    var searchText: String = ""
    var showNewChat: Bool = false
    var showSettings: Bool = false

    func createConversation(
        provider: Provider,
        modelId: String,
        systemPrompt: String?,
        modelContext: ModelContext
    ) -> Conversation {
        let convo = Conversation(
            provider: provider,
            modelId: modelId
        )
        if let prompt = systemPrompt, !prompt.isEmpty {
            convo.systemPrompt = prompt
        }
        modelContext.insert(convo)
        try? modelContext.save()
        return convo
    }

    func deleteConversation(_ conversation: Conversation, modelContext: ModelContext) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
}
