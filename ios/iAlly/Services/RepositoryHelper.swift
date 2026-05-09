//
//  RepositoryHelper.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Helper for executing repository operations with automatic offline queueing
/// Business Rule: All write operations should use this helper for offline support
/// Use Case: Ensures data is never lost even when network is unavailable
@MainActor
struct RepositoryHelper {
    
    /// Execute a repository operation with automatic offline queueing on failure
    /// - Parameters:
    ///   - operation: The repository operation to execute
    ///   - queueData: Data to queue if operation fails (must be Encodable)
    ///   - operationType: Type of operation for queue
    ///   - entityType: Entity type for queue
    ///   - entityId: Entity identifier
    /// - Returns: Result of the operation
    /// - Throws: Error if operation fails and queuing is not possible
    static func execute<T>(
        _ operation: () async throws -> T,
        queueOnFailure queueData: Encodable? = nil,
        operationType: OperationType? = nil,
        entityType: EntityType? = nil,
        entityId: PersistentIdentifier? = nil
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            // ⚠️ OFFLINE QUEUE DISABLED - See KNOWN_ISSUES.md
            // If offline queue data provided, queue the operation
//            if let queueData = queueData,
//               let operationType = operationType,
//               let entityType = entityType,
//               let entityId = entityId,
//               !OfflineOperationQueue.shared.isOnline {
//                
//                // Queue for retry when online
//                try await OfflineOperationQueue.shared.enqueue(
//                    operationType: operationType,
//                    entityType: entityType,
//                    entityId: entityId,
//                    data: queueData
//                )
//                
//                print("⏸️  Operation queued for offline retry")
//            }
            
            // Re-throw the error
            throw error
        }
    }
}

/// Codable wrapper for common operation data.
/// Note: `isArchived` has been removed — the TaskWork/Plan/Journey/Routine models use
/// a `status` enum for lifecycle state (active, completed, archived). There is no
/// separate `isArchived` boolean property on any model.
struct OperationData: Codable {
    let title: String?
    let description: String?
    let priority: String?
    let lifeDomain: String?
    let isCompleted: Bool?

    init(
        title: String? = nil,
        description: String? = nil,
        priority: String? = nil,
        lifeDomain: String? = nil,
        isCompleted: Bool? = nil
    ) {
        self.title = title
        self.description = description
        self.priority = priority
        self.lifeDomain = lifeDomain
        self.isCompleted = isCompleted
    }
}
