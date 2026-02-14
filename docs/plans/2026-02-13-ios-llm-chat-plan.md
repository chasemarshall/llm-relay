# iOS LLM Chat App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a native SwiftUI iOS 26 chat app for talking to LLMs (OpenAI, Anthropic, OpenRouter) with streaming, markdown rendering, and liquid glass design.

**Architecture:** MVVM with SwiftData persistence, async/await streaming via URLSession, protocol-based service layer for multi-provider support.

**Tech Stack:** SwiftUI, SwiftData, Swift Concurrency, Keychain Services, URLSession SSE streaming. Zero third-party dependencies.

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `LLMChat.xcodeproj` (via xcodebuild or manual)
- Create: `LLMChat/LLMChatApp.swift`
- Create: `LLMChat/ContentView.swift`
- Create: `LLMChat/Info.plist`

**Step 1: Create Xcode project structure**

Create the directory structure and all placeholder files:

```
LLMChat/
├── LLMChatApp.swift
├── ContentView.swift
├── Models/
├── Services/
├── ViewModels/
├── Views/
└── Utilities/
```

**Step 2: Write app entry point**

`LLMChat/LLMChatApp.swift`:
```swift
import SwiftUI
import SwiftData

@main
struct LLMChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Conversation.self, Message.self])
    }
}
```

`LLMChat/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("LLM Chat")
    }
}
```

**Step 3: Create Package.swift for SPM-based project**

Use a Swift Package with an executable target to avoid needing Xcode GUI.

**Step 4: Verify it compiles**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add LLMChat/
git commit -m "feat: scaffold Xcode project with SwiftUI + SwiftData"
```

---

### Task 2: Data Models

**Files:**
- Create: `LLMChat/Models/Provider.swift`
- Create: `LLMChat/Models/Conversation.swift`
- Create: `LLMChat/Models/Message.swift`

**Step 1: Write Provider enum**

`LLMChat/Models/Provider.swift`:
```swift
import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case openai
    case anthropic
    case openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        case .openRouter: "OpenRouter"
        }
    }

    var baseURL: URL {
        switch self {
        case .openai: URL(string: "https://api.openai.com/v1")!
        case .anthropic: URL(string: "https://api.anthropic.com/v1")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1")!
        }
    }

    var availableModels: [(id: String, name: String)] {
        switch self {
        case .openai:
            [("gpt-4o", "GPT-4o"), ("gpt-4o-mini", "GPT-4o Mini"), ("o1", "o1"), ("o1-mini", "o1 Mini")]
        case .anthropic:
            [("claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"), ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"), ("claude-opus-4-6", "Claude Opus 4.6")]
        case .openRouter:
            [("openai/gpt-4o", "GPT-4o"), ("anthropic/claude-sonnet-4-5-20250929", "Claude Sonnet 4.5"), ("google/gemini-2.0-flash-exp", "Gemini 2.0 Flash"), ("meta-llama/llama-3.1-405b-instruct", "Llama 3.1 405B")]
        }
    }
}
```

**Step 2: Write Conversation model**

`LLMChat/Models/Conversation.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Conversation {
    var id: UUID
    var title: String
    var systemPrompt: String?
    var providerRaw: String
    var modelId: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]

    var provider: Provider {
        get { Provider(rawValue: providerRaw) ?? .openai }
        set { providerRaw = newValue.rawValue }
    }

    init(title: String = "New Chat", systemPrompt: String? = nil, provider: Provider = .openai, modelId: String = "gpt-4o") {
        self.id = UUID()
        self.title = title
        self.systemPrompt = systemPrompt
        self.providerRaw = provider.rawValue
        self.modelId = modelId
        self.createdAt = Date()
        self.updatedAt = Date()
        self.messages = []
    }
}
```

**Step 3: Write Message model**

`LLMChat/Models/Message.swift`:
```swift
import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var role: String // "system", "user", "assistant"
    var content: String
    var timestamp: Date
    var isError: Bool

    var conversation: Conversation?

    enum Role: String {
        case system, user, assistant
    }

    var messageRole: Role {
        Role(rawValue: role) ?? .user
    }

    init(role: Role, content: String, isError: Bool = false) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.timestamp = Date()
        self.isError = isError
    }
}
```

**Step 4: Verify it compiles**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add LLMChat/Models/
git commit -m "feat: add SwiftData models for Conversation, Message, Provider"
```

---

### Task 3: Keychain Manager

**Files:**
- Create: `LLMChat/Services/KeychainManager.swift`

**Step 1: Write KeychainManager**

`LLMChat/Services/KeychainManager.swift`:
```swift
import Foundation
import Security

enum KeychainManager {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func apiKey(for provider: Provider) -> String? {
        load(key: "llmchat_apikey_\(provider.rawValue)")
    }

    static func setApiKey(_ value: String, for provider: Provider) {
        save(key: "llmchat_apikey_\(provider.rawValue)", value: value)
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Services/KeychainManager.swift
git commit -m "feat: add KeychainManager for secure API key storage"
```

---

### Task 4: LLM Service Protocol + OpenAI Implementation

**Files:**
- Create: `LLMChat/Services/LLMService.swift`
- Create: `LLMChat/Services/OpenAIService.swift`

**Step 1: Write LLMService protocol**

`LLMChat/Services/LLMService.swift`:
```swift
import Foundation

struct ChatMessage {
    let role: String
    let content: String
}

protocol LLMService {
    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error>
}

enum LLMError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: "Invalid API key. Check your settings."
        case .rateLimited: "Rate limited. Please wait a moment."
        case .networkError(let msg): "Network error: \(msg)"
        case .invalidResponse(let msg): "Invalid response: \(msg)"
        }
    }
}
```

**Step 2: Write OpenAIService (handles both OpenAI and OpenRouter)**

`LLMChat/Services/OpenAIService.swift`:
```swift
import Foundation

final class OpenAIService: LLMService {
    private let baseURL: URL
    private let session: URLSession
    private let extraHeaders: [String: String]

    init(baseURL: URL, extraHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.session = URLSession.shared
        self.extraHeaders = extraHeaders
    }

    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    for (key, value) in extraHeaders {
                        request.setValue(value, forHTTPHeaderField: key)
                    }

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    switch httpResponse.statusCode {
                    case 200: break
                    case 401: throw LLMError.invalidAPIKey
                    case 429: throw LLMError.rateLimited
                    default: throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))
                        if data == "[DONE]" { break }

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let choices = json["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String else {
                            continue
                        }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

**Step 3: Verify it compiles**

**Step 4: Commit**

```bash
git add LLMChat/Services/LLMService.swift LLMChat/Services/OpenAIService.swift
git commit -m "feat: add LLMService protocol and OpenAI streaming implementation"
```

---

### Task 5: Anthropic Service Implementation

**Files:**
- Create: `LLMChat/Services/AnthropicService.swift`

**Step 1: Write AnthropicService**

`LLMChat/Services/AnthropicService.swift`:
```swift
import Foundation

final class AnthropicService: LLMService {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let session = URLSession.shared

    func streamCompletion(
        messages: [ChatMessage],
        model: String,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: baseURL.appendingPathComponent("messages"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

                    // Separate system from conversation messages
                    let systemMessage = messages.first { $0.role == "system" }
                    let chatMessages = messages.filter { $0.role != "system" }

                    var body: [String: Any] = [
                        "model": model,
                        "messages": chatMessages.map { ["role": $0.role, "content": $0.content] },
                        "max_tokens": 4096,
                        "stream": true
                    ]
                    if let system = systemMessage {
                        body["system"] = system.content
                    }
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMError.networkError("Invalid response")
                    }

                    switch httpResponse.statusCode {
                    case 200: break
                    case 401: throw LLMError.invalidAPIKey
                    case 429: throw LLMError.rateLimited
                    default: throw LLMError.networkError("HTTP \(httpResponse.statusCode)")
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }

                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        guard let jsonData = data.data(using: .utf8),
                              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                              let type = json["type"] as? String else {
                            continue
                        }

                        if type == "content_block_delta",
                           let delta = json["delta"] as? [String: Any],
                           let text = delta["text"] as? String {
                            continuation.yield(text)
                        } else if type == "message_stop" {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Services/AnthropicService.swift
git commit -m "feat: add Anthropic Claude streaming service"
```

---

### Task 6: Service Factory + Haptic Manager

**Files:**
- Create: `LLMChat/Services/ServiceFactory.swift`
- Create: `LLMChat/Utilities/HapticManager.swift`

**Step 1: Write ServiceFactory**

`LLMChat/Services/ServiceFactory.swift`:
```swift
import Foundation

enum ServiceFactory {
    static func service(for provider: Provider) -> LLMService {
        switch provider {
        case .openai:
            OpenAIService(baseURL: provider.baseURL)
        case .anthropic:
            AnthropicService()
        case .openRouter:
            OpenAIService(
                baseURL: provider.baseURL,
                extraHeaders: ["HTTP-Referer": "https://llmchat.app"]
            )
        }
    }
}
```

**Step 2: Write HapticManager**

`LLMChat/Utilities/HapticManager.swift`:
```swift
import UIKit

enum HapticManager {
    static func send() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func receive() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

**Step 3: Verify it compiles**

**Step 4: Commit**

```bash
git add LLMChat/Services/ServiceFactory.swift LLMChat/Utilities/HapticManager.swift
git commit -m "feat: add ServiceFactory and HapticManager utilities"
```

---

### Task 7: Markdown Renderer

**Files:**
- Create: `LLMChat/Utilities/MarkdownRenderer.swift`

**Step 1: Write MarkdownRenderer**

`LLMChat/Utilities/MarkdownRenderer.swift`:
```swift
import SwiftUI

enum MarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        do {
            var result = try AttributedString(markdown: text, options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            ))
            // Style inline code
            for run in result.runs {
                if run.inlinePresentationIntent?.contains(.code) == true {
                    let range = run.range
                    result[range].font = .system(.body, design: .monospaced)
                    result[range].backgroundColor = Color(.systemGray5)
                }
            }
            return result
        } catch {
            return AttributedString(text)
        }
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Utilities/MarkdownRenderer.swift
git commit -m "feat: add markdown renderer with code styling"
```

---

### Task 8: ChatViewModel

**Files:**
- Create: `LLMChat/ViewModels/ChatViewModel.swift`

**Step 1: Write ChatViewModel**

`LLMChat/ViewModels/ChatViewModel.swift`:
```swift
import SwiftUI
import SwiftData

@Observable
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

        // Auto-title from first message
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

        isStreaming = true

        streamTask = Task {
            do {
                let stream = service.streamCompletion(
                    messages: chatMessages,
                    model: conversation.modelId,
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
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/ViewModels/ChatViewModel.swift
git commit -m "feat: add ChatViewModel with streaming and error handling"
```

---

### Task 9: ConversationListViewModel

**Files:**
- Create: `LLMChat/ViewModels/ConversationListViewModel.swift`

**Step 1: Write ConversationListViewModel**

`LLMChat/ViewModels/ConversationListViewModel.swift`:
```swift
import SwiftUI
import SwiftData

@Observable
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
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/ViewModels/ConversationListViewModel.swift
git commit -m "feat: add ConversationListViewModel"
```

---

### Task 10: MessageBubbleView + StreamingIndicator

**Files:**
- Create: `LLMChat/Views/MessageBubbleView.swift`
- Create: `LLMChat/Views/StreamingIndicator.swift`

**Step 1: Write MessageBubbleView**

`LLMChat/Views/MessageBubbleView.swift`:
```swift
import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    var body: some View {
        HStack {
            if message.messageRole == .user { Spacer(minLength: 60) }

            VStack(alignment: message.messageRole == .user ? .trailing : .leading, spacing: 4) {
                if message.isError {
                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text(MarkdownRenderer.render(message.content))
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if message.messageRole == .user {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.tint.opacity(0.15))
                        }
                    }
                    .foregroundStyle(message.isError ? .red : .primary)

                if isStreaming && message.messageRole == .assistant {
                    StreamingIndicator()
                        .padding(.leading, 14)
                }
            }

            if message.messageRole == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
```

**Step 2: Write StreamingIndicator**

`LLMChat/Views/StreamingIndicator.swift`:
```swift
import SwiftUI

struct StreamingIndicator: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(scaleFor(index: index))
                    .opacity(opacityFor(index: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func scaleFor(index: Int) -> CGFloat {
        let offset = Double(index) * 0.2
        return 0.5 + 0.5 * sin((phase + offset) * .pi)
    }

    private func opacityFor(index: Int) -> CGFloat {
        let offset = Double(index) * 0.2
        return 0.3 + 0.7 * sin((phase + offset) * .pi)
    }
}
```

**Step 3: Verify it compiles**

**Step 4: Commit**

```bash
git add LLMChat/Views/MessageBubbleView.swift LLMChat/Views/StreamingIndicator.swift
git commit -m "feat: add MessageBubbleView and StreamingIndicator"
```

---

### Task 11: ChatView

**Files:**
- Create: `LLMChat/Views/ChatView.swift`

**Step 1: Write ChatView**

`LLMChat/Views/ChatView.swift`:
```swift
import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    let conversation: Conversation
    @State private var viewModel: ChatViewModel?

    var body: some View {
        Group {
            if let viewModel {
                chatContent(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ChatViewModel(conversation: conversation, modelContext: modelContext)
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(conversation.title)
                        .font(.headline)
                    Text(conversation.modelId)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func chatContent(viewModel: ChatViewModel) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.sortedMessages.isEmpty {
                            emptyState
                        }
                        ForEach(viewModel.sortedMessages) { message in
                            MessageBubbleView(
                                message: message,
                                isStreaming: viewModel.isStreaming && message.id == viewModel.sortedMessages.last?.id
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: viewModel.sortedMessages.count) {
                    if let last = viewModel.sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            inputBar(viewModel: viewModel)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Start a conversation")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(conversation.modelId)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 100)
    }

    private func inputBar(viewModel: ChatViewModel) -> some View {
        HStack(spacing: 12) {
            TextField("Message...", text: Binding(
                get: { viewModel.inputText },
                set: { viewModel.inputText = $0 }
            ), axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            if viewModel.isStreaming {
                Button {
                    viewModel.stopStreaming()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            } else {
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .tint)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Views/ChatView.swift
git commit -m "feat: add ChatView with streaming, input bar, and empty state"
```

---

### Task 12: NewChatSheet

**Files:**
- Create: `LLMChat/Views/NewChatSheet.swift`

**Step 1: Write NewChatSheet**

`LLMChat/Views/NewChatSheet.swift`:
```swift
import SwiftUI

struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProvider: Provider = .openai
    @State private var selectedModelId: String = "gpt-4o"
    @State private var systemPrompt: String = ""
    let onCreate: (Provider, String, String?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(Provider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) {
                        if let first = selectedProvider.availableModels.first {
                            selectedModelId = first.id
                        }
                    }
                }

                Section("Model") {
                    Picker("Model", selection: $selectedModelId) {
                        ForEach(selectedProvider.availableModels, id: \.id) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                }

                Section("System Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(selectedProvider, selectedModelId, systemPrompt.isEmpty ? nil : systemPrompt)
                        dismiss()
                    }
                }
            }
        }
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Views/NewChatSheet.swift
git commit -m "feat: add NewChatSheet with provider/model picker and system prompt"
```

---

### Task 13: SettingsView

**Files:**
- Create: `LLMChat/Views/SettingsView.swift`

**Step 1: Write SettingsView**

`LLMChat/Views/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var keys: [Provider: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(Provider.allCases) { provider in
                    Section(provider.displayName) {
                        SecureField("API Key", text: Binding(
                            get: { keys[provider] ?? "" },
                            set: { keys[provider] = $0 }
                        ))
                        .textContentType(.password)
                        .autocorrectionDisabled()

                        if let key = keys[provider], !key.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Key saved")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        for (provider, key) in keys {
                            if key.isEmpty {
                                KeychainManager.delete(key: "llmchat_apikey_\(provider.rawValue)")
                            } else {
                                KeychainManager.setApiKey(key, for: provider)
                            }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                for provider in Provider.allCases {
                    keys[provider] = KeychainManager.apiKey(for: provider) ?? ""
                }
            }
        }
    }
}
```

**Step 2: Verify it compiles**

**Step 3: Commit**

```bash
git add LLMChat/Views/SettingsView.swift
git commit -m "feat: add SettingsView with per-provider API key management"
```

---

### Task 14: ConversationListView + ContentView Integration

**Files:**
- Create: `LLMChat/Views/ConversationListView.swift`
- Modify: `LLMChat/ContentView.swift`

**Step 1: Write ConversationListView**

`LLMChat/Views/ConversationListView.swift`:
```swift
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
                            Text("·")
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
```

**Step 2: Update ContentView**

`LLMChat/ContentView.swift`:
```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ConversationListView()
    }
}
```

**Step 3: Verify it compiles**

**Step 4: Commit**

```bash
git add LLMChat/Views/ConversationListView.swift LLMChat/ContentView.swift
git commit -m "feat: add ConversationListView and wire up full app navigation"
```

---

### Task 15: Final Integration + Build Verification

**Step 1: Verify full project compiles**

Run: `xcodebuild build -scheme LLMChat -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED

**Step 2: Run in simulator, smoke test**

- Launch app
- Go to Settings, enter an API key
- Create new chat with model selection
- Send a message, verify streaming works
- Check sidebar shows conversation

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete iOS LLM chat app v1"
```
