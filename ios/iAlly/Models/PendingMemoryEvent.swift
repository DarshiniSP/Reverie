//
//  PendingMemoryEvent.swift
//  iAlly
//
//  GAP 1: Persistent Offline Memory Queue
//  When PAIService is unreachable, memory events are persisted here in SwiftData
//  instead of being silently lost. ProactiveIntelligenceEngine.runCycle() and
//  PAIServiceClient connection-restore events flush the queue automatically.
//

import Foundation
import SwiftData

@Model
final class PendingMemoryEvent {

    var id: UUID = UUID()
    var content: String = ""
    var memoryType: String = "episodic"    // "episodic" | "semantic"

    // Stored as a JSON string so the attribute is a CloudKit-native String type.
    // `[String: String]` would map to a Transformable attribute which CloudKit rejects.
    var metadataJSON: String = "{}"

    var createdAt: Date = Date()
    var retryCount: Int = 0
    var lastError: String? = nil

    // MARK: - Retry logic

    /// Maximum number of delivery attempts before the event is discarded.
    static let maxRetries = 5

    var hasExceededRetryLimit: Bool { retryCount >= PendingMemoryEvent.maxRetries }

    /// Convenience accessor — decodes the stored JSON string to a dictionary.
    /// This is a computed property (not stored) so SwiftData/CloudKit ignores it.
    var metadata: [String: String] {
        guard let data = metadataJSON.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }

    init(content: String, memoryType: String, metadata: [String: String]) {
        self.content = content
        self.memoryType = memoryType
        // Encode to JSON string for CloudKit-compatible storage
        if let data = try? JSONEncoder().encode(metadata),
           let json = String(data: data, encoding: .utf8) {
            self.metadataJSON = json
        } else {
            self.metadataJSON = "{}"
        }
    }
}
