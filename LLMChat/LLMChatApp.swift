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
