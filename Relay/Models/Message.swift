import Foundation
import SwiftData

@Model
final class Message {
    var id: UUID
    var role: String
    var content: String
    var timestamp: Date
    var isError: Bool
    var thinkingContent: String?
    var searchSourcesRaw: String?
    @Attribute(.externalStorage) var imageData: Data?
    var promptTokens: Int?
    var completionTokens: Int?
    var latencyMs: Int?
    var durationMs: Int?

    var conversation: Conversation?

    enum Role: String {
        case system, user, assistant
    }

    var messageRole: Role {
        Role(rawValue: role) ?? .user
    }

    struct Source: Identifiable, Codable {
        var id = UUID()
        let title: String
        let url: String
    }

    var searchSources: [Source] {
        guard let raw = searchSourcesRaw,
              let data = raw.data(using: .utf8),
              let sources = try? JSONDecoder().decode([Source].self, from: data) else { return [] }
        return sources
    }

    func setSearchSources(_ results: [(title: String, url: String)]) {
        let sources = results.map { Source(title: $0.title, url: $0.url) }
        if let data = try? JSONEncoder().encode(sources) {
            searchSourcesRaw = String(data: data, encoding: .utf8)
        }
    }

    init(role: Role, content: String, isError: Bool = false) {
        self.id = UUID()
        self.role = role.rawValue
        self.content = content
        self.timestamp = Date()
        self.isError = isError
    }
}
