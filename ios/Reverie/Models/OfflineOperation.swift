//
//  OfflineOperation.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Represents an operation that was attempted while offline
/// These operations are queued and retried when connectivity is restored
@Model
final class OfflineOperation {
    
    /// Unique identifier for this operation
    var id: UUID = UUID()
    
    /// Type of operation (create, update, delete)
    var operationType: OperationType = OperationType.create
    
    /// Entity type affected (Task, Plan, Journey, Routine)
    var entityType: EntityType = EntityType.task
    
    /// Entity ID for the operation (stored as string for PersistentIdentifier compatibility)
    var entityId: String = ""
    
    /// Serialized data for the operation (JSON)
    var data: Data = Data()
    
    /// Timestamp when operation was created
    var createdAt: Date = Date()
    
    /// Number of retry attempts
    var retryCount: Int = 0
    
    /// Last error message if operation failed
    var lastError: String?
    
    /// Maximum number of retries before giving up
    static let maxRetries = 5
    
    init(
        id: UUID = UUID(),
        operationType: OperationType,
        entityType: EntityType,
        entityId: String,
        data: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.data = data
        self.createdAt = createdAt
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

// MARK: - Supporting Types

/// Types of operations that can be queued
enum OperationType: String, Codable {
    case create
    case update
    case delete
    case complete
    case archive
}

/// Entity types that support offline operations
enum EntityType: String, Codable {
    case task
    case plan
    case journey
    case routine
    case milestone
}

// MARK: - Codable Conformance

extension OfflineOperation {
    
    /// Decode the operation data into a dictionary
    func decodeData() -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    /// Check if operation has exceeded retry limit
    var hasExceededRetryLimit: Bool {
        retryCount >= Self.maxRetries
    }
    
    /// Increment retry count
    func incrementRetry(error: String? = nil) {
        retryCount += 1
        lastError = error
    }
}
