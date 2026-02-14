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

        // Check for memory commands
        if let command = MemoryManager.parseMemoryCommand(from: text) {
            handleMemoryCommand(command, originalText: text)
            return
        }

        let userMessage = Message(role: .user, content: text)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)

        conversation.updatedAt = Date()
        try? modelContext.save()

        let isFirstMessage = conversation.messages.filter({ $0.messageRole == .user }).count == 1
        streamResponse()

        if isFirstMessage {
            generateTitle(from: text)
        }
    }

    private func handleMemoryCommand(_ command: MemoryManager.MemoryCommand, originalText: String) {
        // Still show the user's message in chat
        let userMessage = Message(role: .user, content: originalText)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)

        let responseText: String
        switch command {
        case .save(let fact):
            MemoryManager.saveMemory(fact, modelContext: modelContext)
            responseText = "Got it, I'll remember that."
        case .forget(let query):
            let count = MemoryManager.forgetMemories(matching: query, modelContext: modelContext)
            if count > 0 {
                responseText = "Done, I've forgotten \(count == 1 ? "that" : "those \(count) memories")."
            } else {
                responseText = "I don't have any memories matching that."
            }
        }

        let assistantMessage = Message(role: .assistant, content: responseText)
        assistantMessage.conversation = conversation
        conversation.messages.append(assistantMessage)
        conversation.updatedAt = Date()
        try? modelContext.save()
        HapticManager.receive()
    }

    func streamResponse() {
        let provider = conversation.provider
        guard let apiKey = KeychainManager.apiKey(for: provider) else {
            let errorMsg = Message(role: .assistant, content: "No API key set. Go to Settings to add your OpenRouter key.", isError: true)
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

        // Fetch existing memories
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt)])
        let existingMemories = (try? modelContext.fetch(descriptor)) ?? []

        // Build system prompt: base prompt + memory instructions + memories
        var systemParts: [String] = []
        let basePrompt = conversation.systemPrompt ?? SettingsManager.globalSystemPrompt
        if let prompt = basePrompt, !prompt.isEmpty {
            systemParts.append(prompt)
        }

        // Inject memories with context
        if !existingMemories.isEmpty {
            let memoryText = existingMemories.map { "- \($0.content)" }.joined(separator: "\n")
            systemParts.append("""
            USER MEMORIES (important facts about the user — always keep these in mind and reference them naturally when relevant):
            \(memoryText)
            """)
        }

        if !systemParts.isEmpty {
            chatMessages.append(ChatMessage(role: "system", content: systemParts.joined(separator: "\n\n")))
        }

        // Only send the last 20 messages to save tokens
        let recentMessages = sortedMessages
            .filter { $0.id != assistantMessage.id && !$0.isError }
            .suffix(20)
        for msg in recentMessages {
            chatMessages.append(ChatMessage(role: msg.role, content: msg.content))
        }

        let modelId = conversation.modelId
        let lastUserMessage = recentMessages.last(where: { $0.messageRole == .user })?.content ?? ""
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

                // Auto-extract memories in the background
                let responseContent = assistantMessage.content
                if !lastUserMessage.isEmpty && !responseContent.isEmpty {
                    MemoryManager.extractMemories(
                        userMessage: lastUserMessage,
                        assistantMessage: responseContent,
                        existingMemories: existingMemories,
                        modelContext: modelContext
                    )
                }
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

    private func generateTitle(from firstMessage: String) {
        guard let apiKey = KeychainManager.apiKey() else { return }
        let service = ServiceFactory.service(for: .openRouter)

        Task {
            var title = ""
            let messages = [
                ChatMessage(role: "system", content: "Summarize what the user is asking about in 2-5 words. Be casual and specific, not generic. Reply with ONLY those words, nothing else. No quotes, no punctuation."),
                ChatMessage(role: "user", content: firstMessage)
            ]
            do {
                let stream = service.streamCompletion(
                    messages: messages,
                    model: "anthropic/claude-haiku-4.5",
                    apiKey: apiKey
                )
                for try await token in stream {
                    title += token
                }
                let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    conversation.title = cleaned
                    try? modelContext.save()
                }
            } catch {
                // Fall back to truncated first message
                conversation.title = String(firstMessage.prefix(40))
                try? modelContext.save()
            }
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
