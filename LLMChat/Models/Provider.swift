import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case openRouter

    var id: String { rawValue }
    var displayName: String { "OpenRouter" }

    var baseURL: URL {
        URL(string: "https://openrouter.ai/api/v1")!
    }
}
