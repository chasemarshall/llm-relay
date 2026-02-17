import SwiftUI
import SwiftData
import UIKit

enum StreamingPhase: Equatable {
    case idle
    case searching
    case thinking
    case streaming
}

@MainActor @Observable
final class ChatViewModel {
    var conversation: Conversation
    var inputText: String = ""
    var isStreaming: Bool = false
    var streamingPhase: StreamingPhase = .idle
    var isWaitingForToken: Bool = false
    var searchEnabled: Bool = false
    var uiErrorMessage: String?
    var selectedImageData: Data?
    private var streamTask: Task<Void, Never>?
    private var modelContext: ModelContext
    private var tokenBuffer: String = ""
    private var thinkingBuffer: String = ""
    private var lastFlush: Date = .distantPast
    private var waitingTimer: Task<Void, Never>?

    private static let maxToolIterations = 3

    private static let searchTool = ToolDefinition(
        name: "web_search",
        description: "Search the web for current information. Use when the user asks about recent events, facts you're unsure about, or anything that benefits from up-to-date information.",
        parameters: [
            "type": "object",
            "properties": ["query": ["type": "string", "description": "The search query"]],
            "required": ["query"]
        ]
    )

    private static let saveMemoryTool = ToolDefinition(
        name: "save_memory",
        description: "Save an important fact about the user for future conversations. Use when the user shares personal details (name, job, location), preferences, goals, projects, or asks you to remember something. Only save concrete, reusable facts — not temporary or conversational details.",
        parameters: [
            "type": "object",
            "properties": ["fact": ["type": "string", "description": "A short declarative statement about the user, e.g. 'User is a software engineer' or 'User prefers dark mode'"]],
            "required": ["fact"]
        ]
    )

    private static let forgetMemoryTool = ToolDefinition(
        name: "forget_memory",
        description: "Forget/delete a previously saved memory about the user. Use when the user asks you to forget something or says a saved fact is no longer true.",
        parameters: [
            "type": "object",
            "properties": ["query": ["type": "string", "description": "Text to match against existing memories — any memory containing this text will be deleted"]],
            "required": ["query"]
        ]
    )

    init(conversation: Conversation, modelContext: ModelContext) {
        self.conversation = conversation
        self.modelContext = modelContext
    }

    var sortedMessages: [Message] {
        conversation.messages.sorted { $0.timestamp < $1.timestamp }
    }

    /// Tracks the last message content length for scroll-on-stream.
    var streamingText: String {
        sortedMessages.last?.content ?? ""
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageData = selectedImageData
        guard !text.isEmpty || imageData != nil, !isStreaming else { return }

        inputText = ""
        selectedImageData = nil
        HapticManager.send()

        // Persist draft conversation on first send
        if conversation.modelContext == nil {
            modelContext.insert(conversation)
        }

        let userMessage = Message(role: .user, content: text)
        if let imageData {
            userMessage.imageData = compressImage(imageData)
        }
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)

        conversation.updatedAt = Date()
        saveContext(or: "Couldn't save your message.")

        let isFirstMessage = conversation.messages.filter({ $0.messageRole == .user }).count == 1
        streamResponse()

        if isFirstMessage {
            generateTitle(from: text)
        }
    }

    func streamResponse() {
        let provider = conversation.provider
        guard let apiKey = KeychainManager.apiKey(for: provider) else {
            let errorMsg = Message(role: .assistant, content: "No API key set. Go to Settings to add your \(provider.displayName) key.", isError: true)
            errorMsg.conversation = conversation
            conversation.messages.append(errorMsg)
            saveContext(or: "Couldn't save the API key error message.")
            HapticManager.error()
            return
        }

        let service = provider.createService()
        let assistantMessage = Message(role: .assistant, content: "")
        assistantMessage.conversation = conversation
        conversation.messages.append(assistantMessage)

        let modelId = conversation.modelId
        let shouldSearch = searchEnabled
        isStreaming = true
        streamingPhase = .thinking

        streamTask = Task {
            do {
                let baseChatMessages = buildChatMessages(excluding: assistantMessage)
                var tools: [ToolDefinition] = [Self.saveMemoryTool, Self.forgetMemoryTool]
                let searchToolEnabled = shouldSearch && KeychainManager.searchApiKey() != nil
                if searchToolEnabled {
                    tools.append(Self.searchTool)
                }

                // Tool-use loop: stream → detect tool calls → execute → re-stream
                var loopMessages = baseChatMessages
                var iteration = 0

                while iteration < Self.maxToolIterations {
                    let forceToolName: String? = (searchToolEnabled && iteration == 0) ? "web_search" : nil

                    streamingPhase = .thinking
                    tokenBuffer = ""
                    thinkingBuffer = ""
                    lastFlush = Date()
                    isWaitingForToken = true

                    let streamStartTime = Date()
                    var firstTokenTime: Date?
                    var pendingToolCalls: [Int: ToolCall] = [:]
                    var contentAccumulated = ""
                    var finishReason: String?

                    let stream = service.streamCompletion(
                        messages: loopMessages,
                        model: modelId,
                        apiKey: apiKey,
                        tools: tools,
                        forceToolName: forceToolName
                    )

                    for try await token in stream {
                        if Task.isCancelled { break }

                        isWaitingForToken = false
                        waitingTimer?.cancel()
                        waitingTimer = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            if !Task.isCancelled { isWaitingForToken = true }
                        }

                        switch token {
                        case .reasoning(let text):
                            if firstTokenTime == nil { firstTokenTime = Date() }
                            if streamingPhase != .thinking { streamingPhase = .thinking }
                            thinkingBuffer += text
                        case .content(let text):
                            if firstTokenTime == nil { firstTokenTime = Date() }
                            if streamingPhase != .streaming { streamingPhase = .streaming }
                            tokenBuffer += text
                            contentAccumulated += text
                        case .toolCall(let index, let id, let name, let arguments):
                            var existing = pendingToolCalls[index] ?? ToolCall(id: "", name: "", arguments: "")
                            if let id { existing.id = id }
                            if let name { existing.name = name }
                            if let arguments { existing.arguments += arguments }
                            pendingToolCalls[index] = existing
                        case .finishReason(let reason):
                            finishReason = reason
                        case .usage(let prompt, let completion):
                            assistantMessage.promptTokens = prompt
                            assistantMessage.completionTokens = completion
                        }

                        let now = Date()
                        if now.timeIntervalSince(lastFlush) >= 0.05 {
                            flushBuffers(to: assistantMessage)
                        }
                    }

                    waitingTimer?.cancel()
                    isWaitingForToken = false
                    flushBuffers(to: assistantMessage)

                    // Store timing metrics
                    let streamEndTime = Date()
                    if let firstToken = firstTokenTime {
                        assistantMessage.latencyMs = Int(firstToken.timeIntervalSince(streamStartTime) * 1000)
                    }
                    assistantMessage.durationMs = Int(streamEndTime.timeIntervalSince(streamStartTime) * 1000)

                    // Check if model wants to call tools
                    let toolCallsList = pendingToolCalls.sorted(by: { $0.key < $1.key }).map(\.value)

                    if finishReason == "tool_calls" || !toolCallsList.isEmpty {
                        streamingPhase = .searching

                        // Add assistant message with tool calls to conversation history
                        loopMessages.append(ChatMessage(
                            role: "assistant",
                            content: contentAccumulated,
                            toolCalls: toolCallsList
                        ))

                        // Execute each tool call and append results
                        for call in toolCallsList {
                            let result = await executeToolCall(call, storeOn: assistantMessage)
                            loopMessages.append(ChatMessage(
                                role: "tool",
                                content: result,
                                toolCallId: call.id
                            ))
                        }

                        iteration += 1
                        continue
                    }

                    // No tool calls — done
                    break
                }

                if Task.isCancelled { return }

                HapticManager.receive()
            } catch {
                flushBuffers(to: assistantMessage)
                var errorText = error.localizedDescription
                if let statusNote = await Self.checkProviderStatusNote(for: provider) {
                    errorText += "\n\n\(statusNote)"
                }
                assistantMessage.content = errorText
                assistantMessage.isError = true
                HapticManager.error()
            }

            isStreaming = false
            streamingPhase = .idle
            conversation.updatedAt = Date()
            saveContext(or: "Couldn't save the latest response.")
        }
    }

    private func flushBuffers(to message: Message) {
        if !thinkingBuffer.isEmpty {
            message.thinkingContent = (message.thinkingContent ?? "") + thinkingBuffer
            thinkingBuffer = ""
        }
        if !tokenBuffer.isEmpty {
            message.content += tokenBuffer
            tokenBuffer = ""
        }
        lastFlush = Date()
    }

    private func executeToolCall(_ call: ToolCall, storeOn message: Message) async -> String {
        guard let data = call.arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "Invalid arguments"
        }

        switch call.name {
        case "web_search":
            guard let query = args["query"] as? String else { return "Missing query" }
            do {
                let results = try await SearchService.search(query: query)
                message.setSearchSources(results.map { (title: $0.title, url: $0.url) })
                return results.map { "[\($0.title)](\($0.url)): \($0.snippet)" }.joined(separator: "\n\n")
            } catch {
                return "Search failed: \(error.localizedDescription)"
            }

        case "save_memory":
            guard let fact = args["fact"] as? String, !fact.isEmpty else { return "Missing fact" }
            do {
                try MemoryManager.saveMemory(fact, modelContext: modelContext)
                return "Memory saved: \(fact)"
            } catch {
                return "Memory save failed: \(error.localizedDescription)"
            }

        case "forget_memory":
            guard let query = args["query"] as? String, !query.isEmpty else { return "Missing query" }
            do {
                let count = try MemoryManager.forgetMemories(matching: query, modelContext: modelContext)
                return count > 0 ? "Deleted \(count) memory(s) matching '\(query)'" : "No memories found matching '\(query)'"
            } catch {
                return "Forget memory failed: \(error.localizedDescription)"
            }

        default:
            return "Unknown tool: \(call.name)"
        }
    }

    private func buildChatMessages(excluding assistantMessage: Message) -> [ChatMessage] {
        var chatMessages: [ChatMessage] = []

        // Fetch existing memories
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt)])
        let existingMemories = (try? modelContext.fetch(descriptor)) ?? []

        // Build system prompt
        var systemParts: [String] = []
        let basePrompt = conversation.systemPrompt ?? SettingsManager.globalSystemPrompt
        if let prompt = basePrompt, !prompt.isEmpty {
            systemParts.append(prompt)
        }

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

        let recentMessages = sortedMessages
            .filter { $0.id != assistantMessage.id && !$0.isError }
            .suffix(20)
        for msg in recentMessages {
            let base64 = msg.imageData?.base64EncodedString()
            chatMessages.append(ChatMessage(role: msg.role, content: msg.content, imageBase64: base64))
        }

        return chatMessages
    }

    private func generateTitle(from firstMessage: String) {
        let provider = conversation.provider
        guard let apiKey = KeychainManager.apiKey(for: provider) else { return }
        let service = provider.createService()

        Task {
            var title = ""
            let messages = [
                ChatMessage(role: "system", content: "Your job is to create a short creative title (2-6 words) that captures the vibe or intent of the user's message. Be witty and interpretive, not literal. Examples: 'Hello' → 'Friendly greeting', 'testing' → 'Quick test run', 'help me with python' → 'Python assistance', 'I'm bored' → 'Seeking entertainment'. Reply with ONLY the title. No quotes, no punctuation."),
                ChatMessage(role: "user", content: firstMessage)
            ]
            do {
                let stream = service.streamCompletion(
                    messages: messages,
                    model: SettingsManager.defaultModelIdForProvider(provider),
                    apiKey: apiKey
                )
                for try await token in stream {
                    if case .content(let text) = token {
                        title += text
                    }
                }
                let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    conversation.title = cleaned
                    saveContext()
                }
            } catch {
                // Fall back to truncated first message
                conversation.title = String(firstMessage.prefix(40))
                saveContext()
            }
        }
    }

    func stopStreaming() {
        streamTask?.cancel()
        isStreaming = false
        streamingPhase = .idle
    }

    func retryLastMessage() {
        guard let lastMsg = sortedMessages.last, lastMsg.isError else { return }
        conversation.messages.removeAll { $0.id == lastMsg.id }
        modelContext.delete(lastMsg)
        saveContext(or: "Couldn't retry because saving failed.")
        streamResponse()
    }

    func regenerateMessage(_ message: Message) {
        guard !isStreaming, message.messageRole == .assistant else { return }
        conversation.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        saveContext(or: "Couldn't regenerate because saving failed.")
        streamResponse()
    }

    func editMessage(_ message: Message) {
        guard !isStreaming, message.messageRole == .user else { return }
        // Put the message text back in the input field and delete the message + its response
        inputText = message.content
        deleteMessagePair(message)
    }

    func deleteMessagePair(_ message: Message) {
        guard !isStreaming, message.messageRole == .user else { return }
        let sorted = sortedMessages
        // Find the AI response that directly follows this user message
        if let index = sorted.firstIndex(where: { $0.id == message.id }),
           index + 1 < sorted.count,
           sorted[index + 1].messageRole == .assistant {
            let response = sorted[index + 1]
            conversation.messages.removeAll { $0.id == response.id }
            modelContext.delete(response)
        }
        conversation.messages.removeAll { $0.id == message.id }
        modelContext.delete(message)
        saveContext(or: "Couldn't delete that message.")
    }

    private func saveContext(or fallbackMessage: String = "Couldn't save changes.") {
        do {
            try modelContext.save()
        } catch {
            uiErrorMessage = "\(fallbackMessage) \(error.localizedDescription)"
        }
    }

    private func compressImage(_ data: Data) -> Data {
        guard let uiImage = UIImage(data: data) else { return data }
        // Resize if too large (max 1024px on longest side)
        let maxDimension: CGFloat = 1024
        let size = uiImage.size
        if size.width > maxDimension || size.height > maxDimension {
            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in uiImage.draw(in: CGRect(origin: .zero, size: newSize)) }
            return resized.jpegData(compressionQuality: 0.7) ?? data
        }
        return uiImage.jpegData(compressionQuality: 0.7) ?? data
    }

    private static func checkProviderStatusNote(for provider: Provider) async -> String? {
        guard let feedURL = provider.statusFeedURL else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            let delegate = RSSStatusDelegate()
            let parser = XMLParser(data: data)
            parser.delegate = delegate
            parser.parse()

            guard let latest = delegate.latestItem else { return nil }
            let descLower = latest.description.lowercased()
            let isResolved = descLower.contains("resolved") || descLower.contains("back to normal") || descLower.contains("operational")
            let isOld = latest.pubDate.map { Date().timeIntervalSince($0) > 86_400 } ?? false

            if !isResolved && !isOld {
                if latest.link.isEmpty {
                    return "\(provider.displayName) may be experiencing issues: \(latest.title)"
                }
                return "\(provider.displayName) may be experiencing issues: [\(latest.title)](\(latest.link))"
            }
        } catch { }
        return nil
    }
}

private final class RSSStatusDelegate: NSObject, XMLParserDelegate {
    struct Item {
        var title: String = ""
        var link: String = ""
        var description: String = ""
        var pubDate: Date?
    }

    var latestItem: Item?
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var insideItem = false
    private var foundFirst = false
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" && !foundFirst {
            insideItem = true
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        if elementName == "item" && insideItem {
            insideItem = false
            foundFirst = true
            latestItem = Item(
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
                description: currentDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                pubDate: Self.dateFormatter.date(from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            parser.abortParsing()
        }
    }
}
