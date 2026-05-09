// LocalMemoryItem.swift
// iAlly — On-Device Memory Store
//
// Persists episodic and semantic memory items locally in SwiftData so Lumina
// has a "memory" of the user's life even when the PAI Mac server is offline.
//
// Design:
//   • Written by LocalMemoryService, which is called from PAIMemoryBridge
//     alongside (not instead of) the existing PAI server call.
//   • Searched by LocalMemoryService.search() using a keyword index + recency
//     weighting — no ML model required, works entirely on-device.
//   • Capped at LocalMemoryService.maxItems (500) — older items trimmed on insert.
//   • Mirrors the PAI memory schema: content + type + metadata JSON.

import Foundation
import SwiftData

@Model
final class LocalMemoryItem {

    // MARK: - Stored Properties

    var id:          UUID   = UUID()
    var content:     String = ""          // Full event description (same text sent to PAI)
    var memoryType:  String = "episodic"  // "episodic" | "semantic"
    var metadataJSON: String = "{}"       // JSON-encoded [String: String] metadata dict
    var createdAt:   Date   = Date()

    /// Space-separated lowercase keyword index built at insert time.
    /// Used for fast in-memory keyword matching without requiring Core Data predicates.
    var keywords:    String = ""

    // MARK: - Init

    init(content: String, memoryType: String = "episodic", metadata: [String: String] = [:]) {
        self.content     = content
        self.memoryType  = memoryType
        self.metadataJSON = Self.encodeMetadata(metadata)
        self.keywords    = Self.extractKeywords(from: content)
    }

    // MARK: - Computed

    var metadata: [String: String] {
        guard let data = metadataJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    // MARK: - Static Helpers

    private static func encodeMetadata(_ dict: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(dict),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }

    /// Extract meaningful keywords from a text string for fast local search.
    /// Lowercases, tokenises by whitespace/punctuation, drops common stop words.
    static func extractKeywords(from text: String) -> String {
        let stopWords: Set<String> = [
            "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "shall", "can", "need", "to", "of",
            "in", "on", "at", "for", "from", "with", "by", "about", "into",
            "through", "during", "before", "after", "above", "below", "but", "or",
            "and", "not", "no", "so", "if", "as", "this", "that", "it", "they",
            "i", "you", "he", "she", "we", "my", "your", "his", "her", "its",
            "our", "their", "s", "re", "ve", "ll", "d", "m", "t"
        ]
        let tokens = text
            .lowercased()
            .components(separatedBy: .init(charactersIn: " \t\n\r,.!?;:\"'()[]{}-_/\\|@#$%^&*+=<>~`"))
            .filter { $0.count > 2 && !stopWords.contains($0) }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return tokens.filter { seen.insert($0).inserted }.joined(separator: " ")
    }
}
