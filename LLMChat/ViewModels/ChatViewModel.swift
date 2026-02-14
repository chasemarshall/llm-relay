import SwiftUI
import SwiftData

@MainActor @Observable
final class ChatViewModel {
    var conversation: Conversation
    var inputText: String = ""
    var isStreaming: Bool = false
    private var streamTask: Task<Void, Never>?
    private var modelContext: ModelContext

    init(conversation: Conversation, modelContext: ModelContext) {
        self.conversation = conversation
        self.modelContext = modelContext
    }

    var sortedMessages: [Message] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        inputText = ""
        HapticManager.send()

        let userMessage = Message(role: .user, content: text)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)

        if conversation.messages.filter({ $0.messageRole == .user }).count == 1 {
            conversation.title = String(text.prefix(40))
        }

        conversation.updatedAt = Date()
        try? modelContext.save()

        streamResponse()
    }

    func streamResponse() {
        let provider = conversation.provider
        guard let apiKey = KeychainManager.apiKey(for: provider) else {
            let errorMsg = Message(role: .assistant, content: "No API key set for \(provider.displayName). Go to Settings to add one.", isError: true)
            errorMsg.conversation = conversation
            conversation.messages.append(errorMsg)
            try? modelContext.save()
            HapticManager.error()
            return
        }

        let service = ServiceFactory.service(for: provider)
        let assistantMessage = Message(role: .assistant, content: "")
        assistantMessage.conversation = conversation
        conversation.messages.append(assistantMessage)

        var chatMessages: [ChatMessage] = []
        if let systemPrompt = conversation.systemPrompt, !systemPrompt.isEmpty {
            chatMessages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        for msg in sortedMessages where msg.id != assistantMessage.id {
            if msg.isError { continue }
            chatMessages.append(ChatMessage(role: msg.role, content: msg.content))
        }

        let modelId = conversation.modelId
        isStreaming = true

        streamTask = Task {
            do {
                let stream = service.streamCompletion(
                    messages: chatMessages,
                    model: modelId,
                    apiKey: apiKey
                )
                for try await token in stream {
                    if Task.isCancelled { break }
                    assistantMessage.content += token
                }
                HapticManager.receive()
            } catch {
                assistantMessage.content = error.localizedDescription
                assistantMessage.isError = true
                HapticManager.error()
            }

            isStreaming = false
            conversation.updatedAt = Date()
            try? modelContext.save()
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
    }

    func retryLastMessage() {
        guard let lastMsg = sortedMessages.last, lastMsg.isError else { return }
        conversation.messages.removeAll { $0.id == lastMsg.id }
        modelContext.delete(lastMsg)
        try? modelContext.save()
        streamResponse()
    }
}
