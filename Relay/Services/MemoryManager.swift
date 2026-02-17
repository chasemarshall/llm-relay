import Foundation
import SwiftData

@MainActor
enum MemoryManager {

    /// Save a memory fact
    static func saveMemory(_ content: String, modelContext: ModelContext) throws {
        // Skip if too similar to an existing memory
        let descriptor = FetchDescriptor<Memory>(sortBy: [SortDescriptor(\.createdAt)])
        let existing = try modelContext.fetch(descriptor)
        let isDuplicate = existing.contains { mem in
            mem.content.lowercased() == content.lowercased() ||
            mem.content.lowercased().contains(content.lowercased()) ||
            content.lowercased().contains(mem.content.lowercased())
        }
        guard !isDuplicate else { return }

        let memory = Memory(content: content, source: "auto")
        modelContext.insert(memory)
        try modelContext.save()
    }

    /// Forget memories matching a query
    static func forgetMemories(matching query: String, modelContext: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<Memory>()
        let memories = try modelContext.fetch(descriptor)

        let queryLower = query.lowercased()
        var deletedCount = 0
        for memory in memories {
            if memory.content.lowercased().contains(queryLower) {
                modelContext.delete(memory)
                deletedCount += 1
            }
        }
        if deletedCount > 0 {
            try modelContext.save()
        }
        return deletedCount
    }
}
