import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var role: String
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
