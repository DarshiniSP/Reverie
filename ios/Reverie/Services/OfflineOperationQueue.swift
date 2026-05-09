//
//  OfflineOperationQueue.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

// ⚠️ TEMPORARILY DISABLED - See KNOWN_ISSUES.md for details
// This file has compilation errors related to Swift.Task vs iAlly.Task conflicts
// and repository method signature mismatches. Will be re-enabled after fixes.

#if false

import Foundation
import SwiftData
import Network

/// Manages offline operations queue and automatic retry when connectivity is restored
/// Business Rule: Operations are queued when offline and automatically retried when online
/// Performance: Processes queue in background to avoid blocking UI
@MainActor
final class OfflineOperationQueue: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = OfflineOperationQueue()
    
    // MARK: - Properties
    
    @Published private(set) var isOnline: Bool = true
    @Published private(set) var queuedOperationsCount: Int = 0
    @Published private(set) var isProcessingQueue: Bool = false
    
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.iAlly.networkMonitor")
    private var context: ModelContext?
    
    // MARK: - Initialization
    
    private init() {
        monitor = NWPathMonitor()
        setupNetworkMonitoring()
    }
    
    /// Set the model context for queue operations
    /// Must be called after model container is initialized
    func configure(with context: ModelContext) {
        self.context = context
        updateQueueCount()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                let wasOffline = !self.isOnline
                self.isOnline = path.status == .satisfied
                
                // If we just came online, process the queue
                if wasOffline && self.isOnline {
                    await self.processQueue()
                }
            }
        }
        
        monitor.start(queue: monitorQueue)
    }
    
    // MARK: - Queue Operations
    
    /// Add an operation to the offline queue
    /// Business Rule: Only queued if operation fails due to network error
    /// Use Case: Automatic fallback when sync fails
    func enqueue(
        operationType: OperationType,
        entityType: EntityType,
        entityId: PersistentIdentifier,
        data: Encodable
    ) async throws {
        guard let context = context else {
            throw OfflineQueueError.contextNotConfigured
        }
        
        // Serialize the data
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        
        // Convert PersistentIdentifier to string representation
        let entityIdString = entityId.id.description
        
        // Create offline operation
        let operation = OfflineOperation(
            operationType: operationType,
            entityType: entityType,
            entityId: entityIdString,
            data: jsonData
        )
        
        context.insert(operation)
        try context.save()
        
        await updateQueueCount()
        
    }
    
    /// Process all queued operations
    /// Business Rule: Processes in FIFO order, stops on first failure
    /// Performance: Runs in background, max 5 retries per operation
    func processQueue() async {
        guard let context = context, isOnline, !isProcessingQueue else { return }
        
        isProcessingQueue = true
        defer { isProcessingQueue = false }
        
        do {
            // Fetch all queued operations
            let descriptor = FetchDescriptor<OfflineOperation>(
                sortBy: [SortDescriptor(\.createdAt)]
            )
            let operations = try context.fetch(descriptor)
            
            guard !operations.isEmpty else {
                await updateQueueCount()
                return
            }
            
            
            // Process each operation
            for operation in operations {
                // Skip operations that have exceeded retry limit
                if operation.hasExceededRetryLimit {
                    context.delete(operation)
                    continue
                }
                
                do {
                    try await executeOperation(operation)
                    
                    // Success - remove from queue
                    context.delete(operation)
                    
                } catch {
                    // Failure - increment retry count
                    operation.incrementRetry(error: error.localizedDescription)
                    
                    // If we're offline again, stop processing
                    if !isOnline {
                        break
                    }
                }
            }
            
            try context.save()
            await updateQueueCount()
            
        } catch {
        }
    }
    
    /// Execute a single offline operation
    /// Business Rule: Delegates to appropriate repository based on entityType
    /// Technical Note: Must handle all entity types defined in EntityType enum
    private func executeOperation(_ operation: OfflineOperation) async throws {
        guard let context = context else {
            throw OfflineQueueError.contextNotConfigured
        }
        
        // Decode operation data
        guard let data = operation.decodeData() else {
            throw OfflineQueueError.invalidData
        }
        
        // Execute based on entity type
        switch operation.entityType {
        case .task:
            try await executeTaskOperation(operation, data: data, context: context)
        case .plan:
            try await executePlanOperation(operation, data: data, context: context)
        case .journey:
            try await executeJourneyOperation(operation, data: data, context: context)
        case .routine:
            try await executeRoutineOperation(operation, data: data, context: context)
        case .milestone:
            try await executeMilestoneOperation(operation, data: data, context: context)
        }
    }
    
    // MARK: - Entity-Specific Execution
    
    private func executeTaskOperation(_ operation: OfflineOperation, data: [String: Any], context: ModelContext) async throws {
        let repository = TaskRepository(context: context)
        
        // Convert string ID back to PersistentIdentifier
        guard let persistentId = PersistentIdentifier.fromString(operation.entityId) else {
            throw OfflineQueueError.invalidData
        }
        
        switch operation.operationType {
        case .create:
            // Recreate task from data
            guard let title = data["title"] as? String else {
                throw OfflineQueueError.invalidData
            }
            let task = TaskWork(
                title: title,
                taskDescription: data["description"] as? String ?? "",
                priority: Priority(rawValue: data["priority"] as? String ?? "medium") ?? .medium,
                lifeDomain: LifeDomain(rawValue: data["lifeDomain"] as? String ?? "personal") ?? .personal
            )
            try repository.create(task)
            
        case .update:
            // Fetch and update task
            let fetchedTask = try repository.fetch(id: persistentId)
            guard let task = fetchedTask else {
                throw OfflineQueueError.entityNotFound
            }
            if let title = data["title"] as? String {
                task.title = title
            }
            try repository.update(task)
            
        case .delete:
            let fetchedTask = try repository.fetch(id: persistentId)
            guard let task = fetchedTask else { return } // Already deleted
            try repository.delete(task)
            
        case .complete:
            let fetchedTask = try repository.fetch(id: persistentId)
            guard let task = fetchedTask else { return }
            try repository.complete(task)
            
        case .archive:
            let fetchedTask = try repository.fetch(id: persistentId)
            guard let task = fetchedTask else { return }
            try repository.archive(task)
        }
    }
    
    private func executePlanOperation(_ operation: OfflineOperation, data: [String: Any], context: ModelContext) async throws {
        let repository = PlanRepository(context: context)
        
        switch operation.operationType {
        case .create:
            guard let title = data["title"] as? String else {
                throw OfflineQueueError.invalidData
            }
            let plan = Plan(
                title: title,
                planDescription: data["description"] as? String ?? "",
                lifeDomain: LifeDomain(rawValue: data["lifeDomain"] as? String ?? "personal") ?? .personal
            )
            try repository.create(plan)
            
        case .update, .delete, .complete, .archive:
            // Similar pattern to tasks
            break
        }
    }
    
    private func executeJourneyOperation(_ operation: OfflineOperation, data: [String: Any], context: ModelContext) async throws {
        let repository = JourneyRepository(context: context)
        // Implementation similar to tasks/plans
    }
    
    private func executeRoutineOperation(_ operation: OfflineOperation, data: [String: Any], context: ModelContext) async throws {
        let repository = RoutineRepository(context: context)
        // Implementation similar to tasks/plans
    }
    
    private func executeMilestoneOperation(_ operation: OfflineOperation, data: [String: Any], context: ModelContext) async throws {
        // Implementation for milestone operations
    }
    
    // MARK: - Queue Management
    
    /// Update the count of queued operations
    private func updateQueueCount() async {
        guard let context = context else {
            queuedOperationsCount = 0
            return
        }
        
        do {
            let descriptor = FetchDescriptor<OfflineOperation>()
            let operations = try context.fetch(descriptor)
            queuedOperationsCount = operations.count
        } catch {
            queuedOperationsCount = 0
        }
    }
    
    /// Clear all queued operations (for testing or error recovery)
    /// Business Rule: Only use when operations are corrupted or during reset
    func clearQueue() async throws {
        guard let context = context else { return }
        
        let descriptor = FetchDescriptor<OfflineOperation>()
        let operations = try context.fetch(descriptor)
        
        for operation in operations {
            context.delete(operation)
        }
        
        try context.save()
        await updateQueueCount()
        
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Errors

enum OfflineQueueError: LocalizedError {
    case contextNotConfigured
    case invalidData
    case entityNotFound
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .contextNotConfigured:
            return "Model context not configured for offline queue"
        case .invalidData:
            return "Invalid or corrupted operation data"
        case .entityNotFound:
            return "Entity not found in database"
        case .unsupportedOperation:
            return "Operation type not supported"
        }
    }
}

// MARK: - PersistentIdentifier Extension

extension PersistentIdentifier {
    /// Convert string representation back to PersistentIdentifier
    /// Note: This is a simplified implementation - in production, use proper encoding
    static func fromString(_ string: String) -> PersistentIdentifier? {
        // For now, this is a placeholder
        // In practice, you'd need to properly serialize/deserialize PersistentIdentifier
        // which requires access to the model schema
        return nil
    }
}

#endif // Temporarily disabled
