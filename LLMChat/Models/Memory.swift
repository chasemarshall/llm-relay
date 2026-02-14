import Foundation
import SwiftData

@Model
final class Memory {
    var id: UUID
    var content: String
    var source: String // "manual" or "auto"
    var createdAt: Date

    init(content: String, source: String = "manual") {
        self.id = UUID()
        self.content = content
        self.source = source
        self.createdAt = Date()
    }
}
