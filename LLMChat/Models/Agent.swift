import Foundation
import SwiftData

@Model
final class Agent {
    var id: UUID
    var name: String
    var modelId: String
    var systemPrompt: String
    var iconName: String?
    var createdAt: Date

    init(name: String, modelId: String, systemPrompt: String, iconName: String? = nil) {
        self.id = UUID()
        self.name = name
        self.modelId = modelId
        self.systemPrompt = systemPrompt
        self.iconName = iconName
        self.createdAt = Date()
    }
}
