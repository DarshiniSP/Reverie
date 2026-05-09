//
//  Repository.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Base protocol for all repositories
/// Provides consistent CRUD operations and query interface
protocol Repository {
    associatedtype Entity: PersistentModel
    
    var context: ModelContext { get }
    
    // MARK: - CRUD Operations
    
    /// Create and insert a new entity
    func create(_ entity: Entity) throws
    
    /// Fetch entity by ID
    func fetch(id: PersistentIdentifier) throws -> Entity?
    
    /// Fetch all entities
    func fetchAll() throws -> [Entity]
    
    /// Update an entity (save context)
    func update(_ entity: Entity) throws
    
    /// Delete an entity
    func delete(_ entity: Entity) throws
    
    /// Delete multiple entities
    func delete(_ entities: [Entity]) throws
    
    /// Save changes to context
    func save() throws
}

/// Default implementations for Repository protocol
extension Repository {
    func create(_ entity: Entity) throws {
        context.insert(entity)
        try save()
    }
    
    func fetch(id: PersistentIdentifier) throws -> Entity? {
        return context.model(for: id) as? Entity
    }
    
    func fetchAll() throws -> [Entity] {
        let descriptor = FetchDescriptor<Entity>()
        return try context.fetch(descriptor)
    }
    
    func update(_ entity: Entity) throws {
        try save()
    }
    
    func delete(_ entity: Entity) throws {
        context.delete(entity)
        try save()
    }
    
    func delete(_ entities: [Entity]) throws {
        for entity in entities {
            context.delete(entity)
        }
        try save()
    }
    
    func save() throws {
        try context.save()
    }
}

/// Base repository implementation
class BaseRepository<T: PersistentModel>: Repository {
    typealias Entity = T
    
    let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Advanced Query Methods
    
    /// Fetch with custom fetch descriptor
    func fetch(descriptor: FetchDescriptor<T>) throws -> [T] {
        return try context.fetch(descriptor)
    }
    
    /// Fetch with predicate
    func fetch(where predicate: Predicate<T>?) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetch(descriptor)
    }
    
    /// Fetch with sorting
    func fetch(sortBy: [SortDescriptor<T>]) throws -> [T] {
        let descriptor = FetchDescriptor<T>(sortBy: sortBy)
        return try context.fetch(descriptor)
    }
    
    /// Fetch with predicate and sorting
    func fetch(
        where predicate: Predicate<T>?,
        sortBy: [SortDescriptor<T>]
    ) throws -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: predicate,
            sortBy: sortBy
        )
        return try context.fetch(descriptor)
    }
    
    /// Count entities
    func count() throws -> Int {
        let descriptor = FetchDescriptor<T>()
        return try context.fetchCount(descriptor)
    }
    
    /// Count with predicate
    func count(where predicate: Predicate<T>?) throws -> Int {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }
    
    /// Check if entity exists
    func exists(id: PersistentIdentifier) -> Bool {
        return (try? fetch(id: id)) != nil
    }
    
    /// Batch delete with predicate
    func batchDelete(where predicate: Predicate<T>?) throws {
        let entities = try fetch(where: predicate)
        try delete(entities)
    }
}

/// Error types for repository operations
enum RepositoryError: LocalizedError {
    case entityNotFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidContext
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "Entity not found in database"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete: \(error.localizedDescription)"
        case .invalidContext:
            return "Invalid model context"
        }
    }
}
