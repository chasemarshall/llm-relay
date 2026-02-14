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
