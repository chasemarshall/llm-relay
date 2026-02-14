import Foundation
import SwiftData

@MainActor
enum MemoryManager {

    /// After a conversation exchange, ask the LLM to extract any facts worth remembering.
    static func extractMemories(
        userMessage: String,
        assistantMessage: String,
        existingMemories: [Memory],
        modelContext: ModelContext
    ) {
        guard let apiKey = KeychainManager.apiKey() else { return }
        let service = ServiceFactory.service(for: .openRouter)

        let existingList = existingMemories.map { "- \($0.content)" }.joined(separator: "\n")

        let systemPrompt = """
        You are a memory extraction system. Your job is to identify important facts about the user from their conversation that are worth remembering long-term.

        Extract ONLY concrete, reusable facts like:
        - Personal details (name, age, location, job, etc.)
        - Preferences (likes, dislikes, dietary restrictions, etc.)
        - Goals and projects they're working on
        - Important people in their life
        - Technical skills or tools they use
        - Recurring topics or interests

        Do NOT extract:
        - Conversational filler or greetings
        - Temporary/one-time requests
        - Things that are only relevant to this specific conversation
        - Opinions about the current topic being discussed
        - Anything already in existing memories

        EXISTING MEMORIES (do not duplicate these):
        \(existingList.isEmpty ? "(none yet)" : existingList)

        If there are new facts worth remembering, respond with ONLY the facts, one per line, as short declarative statements. Example:
        User's name is Alex
        User is a software engineer at Google
        User prefers Python over JavaScript

        If there is NOTHING worth remembering, respond with exactly: NONE
        """

        let messages = [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: "User said: \(userMessage)\n\nAssistant replied: \(assistantMessage)")
        ]

        Task {
            var result = ""
            do {
                let stream = service.streamCompletion(
                    messages: messages,
                    model: "anthropic/claude-haiku-4.5",
                    apiKey: apiKey
                )
                for try await token in stream {
                    result += token
                }

                let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard cleaned.uppercased() != "NONE", !cleaned.isEmpty else { return }

                let newFacts = cleaned.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for fact in newFacts {
                    // Skip if too similar to an existing memory
                    let isDuplicate = existingMemories.contains { existing in
                        existing.content.lowercased() == fact.lowercased() ||
                        existing.content.lowercased().contains(fact.lowercased()) ||
                        fact.lowercased().contains(existing.content.lowercased())
                    }
                    guard !isDuplicate else { continue }

                    let memory = Memory(content: fact, source: "auto")
                    modelContext.insert(memory)
                }
                try? modelContext.save()
            } catch {
                // Silently fail — memory extraction is best-effort
            }
        }
    }

    /// Check if the user's message contains a memory command like "remember that..." or "forget that..."
    /// Returns the command type and content, or nil if no command found.
    static func parseMemoryCommand(from text: String) -> MemoryCommand? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // "remember that..." / "remember:" / "please remember..."
        let rememberPatterns = ["remember that ", "remember: ", "please remember ", "remember i ", "remember my ", "remember me "]
        for pattern in rememberPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) {
                if let range = lower.range(of: pattern) {
                    let fact = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !fact.isEmpty {
                        return .save(fact)
                    }
                }
            }
        }

        // "forget that..." / "forget about..." / "don't remember..."
        let forgetPatterns = ["forget that ", "forget about ", "forget my ", "don't remember ", "stop remembering "]
        for pattern in forgetPatterns {
            if lower.hasPrefix(pattern) || lower.contains(pattern) {
                if let range = lower.range(of: pattern) {
                    let query = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !query.isEmpty {
                        return .forget(query)
                    }
                }
            }
        }

        return nil
    }

    /// Save a memory from a user command
    static func saveMemory(_ content: String, modelContext: ModelContext) {
        let memory = Memory(content: content, source: "manual")
        modelContext.insert(memory)
        try? modelContext.save()
    }

    /// Forget memories matching a query
    static func forgetMemories(matching query: String, modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Memory>()
        guard let memories = try? modelContext.fetch(descriptor) else { return 0 }

        let queryLower = query.lowercased()
        var deletedCount = 0
        for memory in memories {
            if memory.content.lowercased().contains(queryLower) {
                modelContext.delete(memory)
                deletedCount += 1
            }
        }
        if deletedCount > 0 {
            try? modelContext.save()
        }
        return deletedCount
    }

    enum MemoryCommand {
        case save(String)
        case forget(String)
    }
}
