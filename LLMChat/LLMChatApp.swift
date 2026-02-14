import SwiftUI
import SwiftData

@main
struct LLMChatApp: App {
    init() {
        // Ensure Application Support directory exists to prevent CoreData errors
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await ModelManager.shared.fetchModels()
                }
        }
        .modelContainer(for: [Conversation.self, Message.self, Agent.self, Memory.self])
    }
}
