// LocalMemoryService.swift
// iAlly — On-Device Memory Service
//
// Provides guaranteed on-device memory storage and retrieval for Lumina.
// Works entirely offline — no network required.
//
// Architecture:
//   ┌─────────────────────────────────────────────────────────────────┐
//   │  PAIMemoryBridge.fireAndForget()                                │
//   │      ├── LocalMemoryService.shared.store()  ← always, instant  │
//   │      └── PAIServiceClient.storeMemory()     ← best-effort      │
//   └─────────────────────────────────────────────────────────────────┘
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │  LuminaConversationService.send()                               │
//   │      ├── LocalMemoryService.shared.search() ← always first     │
//   │      └── pai.searchMemory()                 ← supplement only  │
//   └─────────────────────────────────────────────────────────────────┘
//
// Search algorithm:
//   1. Fetch all LocalMemoryItems created in the last 90 days (max 200)
//   2. Tokenise the search query using the same stopword filter as LocalMemoryItem
//   3. Score each item: keywordOverlap / totalQueryTokens × recencyWeight
//      - recencyWeight: today=1.0, ≤7 days=0.85, ≤30 days=0.65, older=0.40
//   4. Return top N by descending score (minimum score threshold: 0.05)

import Foundation
import SwiftData
import Observation

@Observable @MainActor
final class LocalMemoryService {

    // MARK: - Singleton

    static let shared = LocalMemoryService()
    private init() {}

    // MARK: - Dependencies

    /// Set from iAllyApp alongside PAIMemoryBridge.shared.modelContext assignment.
    var modelContext: ModelContext?

    // MARK: - Constants

    /// Maximum items to retain. Older items are pruned on insert when limit is exceeded.
    private let maxItems = 500
    /// Only fetch items within this window for search (days).
    private let searchWindowDays = 90

    // MARK: - Store

    /// Persist a memory event to the local SwiftData store.
    /// Called synchronously on @MainActor — returns immediately.
    func store(content: String, type: String = "episodic", metadata: [String: String] = [:]) {
        guard !content.isEmpty, let ctx = modelContext else { return }
        let item = LocalMemoryItem(content: content, memoryType: type, metadata: metadata)
        ctx.insert(item)
        // Best-effort save — failure is silent (the item is already in the context)
        try? ctx.save()
        // Trim in the background so insert never blocks
        Task.detached(priority: .background) { [weak self] in
            await self?.trim()
        }
    }

    // MARK: - Search

    /// Search local memory using keyword overlap + recency weighting.
    /// Returns up to `limit` results sorted by descending relevance score.
    func search(query: String, limit: Int = 5) -> [LocalMemoryItem] {
        guard !query.isEmpty, let ctx = modelContext else { return [] }

        // Build query keywords
        let queryTokens = LocalMemoryItem.extractKeywords(from: query)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        guard !queryTokens.isEmpty else { return [] }

        // Fetch items within the search window
        let cutoff = Calendar.current.date(byAdding: .day, value: -searchWindowDays, to: Date()) ?? Date()
        var descriptor = FetchDescriptor<LocalMemoryItem>(
            predicate: #Predicate { $0.createdAt >= cutoff },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 200
        guard let items = try? ctx.fetch(descriptor) else { return [] }

        // Exclude raw conversation turns — they already appear in recentMessages (chat history).
        // Including them in the memory slot causes the model to see the same exchange twice,
        // which reinforces any wrong responses it gave in the current session.
        let actionItems = items.filter { item in
            item.metadata["event_type"] != "conversation_turn"
        }

        // Score and filter
        let now = Date()
        let minScore: Double = 0.05

        let scored: [(item: LocalMemoryItem, score: Double)] = actionItems.compactMap { item in
            let itemTokens = Set(item.keywords.components(separatedBy: " ").filter { !$0.isEmpty })
            guard !itemTokens.isEmpty else { return nil }

            // Keyword overlap ratio
            let matches = queryTokens.filter { itemTokens.contains($0) }.count
            guard matches > 0 else { return nil }
            let overlap = Double(matches) / Double(queryTokens.count)

            // Recency weight
            let ageSeconds = now.timeIntervalSince(item.createdAt)
            let ageDays = ageSeconds / 86_400
            let recency: Double
            switch ageDays {
            case ..<1:   recency = 1.00
            case ..<7:   recency = 0.85
            case ..<30:  recency = 0.65
            default:     recency = 0.40
            }

            let score = overlap * recency
            return score >= minScore ? (item, score) : nil
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.item }
    }

    // MARK: - Trim

    /// Remove the oldest items when the store exceeds `maxItems`.
    /// Runs in the background — never blocks the main thread.
    private func trim() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<LocalMemoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)] // oldest first
        )
        guard let all = try? ctx.fetch(descriptor), all.count > maxItems else { return }
        let excess = all.count - maxItems
        all.prefix(excess).forEach { ctx.delete($0) }
        try? ctx.save()
    }

    // MARK: - Debug / Utility

    /// Total number of local memory items (for developer tools / InferenceLogView).
    var count: Int {
        guard let ctx = modelContext else { return 0 }
        let descriptor = FetchDescriptor<LocalMemoryItem>()
        return (try? ctx.fetchCount(descriptor)) ?? 0
    }

    /// Wipe all local memory items (developer / reset action).
    func clearAll() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<LocalMemoryItem>()
        guard let all = try? ctx.fetch(descriptor) else { return }
        all.forEach { ctx.delete($0) }
        try? ctx.save()
    }
}
