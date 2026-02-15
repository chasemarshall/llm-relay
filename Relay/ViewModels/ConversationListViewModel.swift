import SwiftUI
import SwiftData

@MainActor @Observable
final class ConversationListViewModel {
    var searchText: String = ""
    var showSettings: Bool = false

    func makeDraftConversation(
        provider: Provider = .openRouter,
        modelId: String,
        systemPrompt: String?
    ) -> Conversation {
        let convo = Conversation(provider: provider, modelId: modelId)
        if let prompt = systemPrompt, !prompt.isEmpty {
            convo.systemPrompt = prompt
        }
        return convo
    }

    func deleteConversation(_ conversation: Conversation, modelContext: ModelContext) {
        modelContext.delete(conversation)
        try? modelContext.save()
    }
}
