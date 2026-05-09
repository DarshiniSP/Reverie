//
//  TaskRepository.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Repository for Task entity with domain-specific queries
final class TaskRepository: BaseRepository<TaskWork> {
    
    // MARK: - Task-Specific Queries
    
    /// Fetch incomplete tasks
    func fetchIncomplete() throws -> [TaskWork] {
        let predicate = #Predicate<TaskWork> { $0.completedAt == nil }
        return try fetch(where: predicate)
    }
    
    /// Fetch completed tasks
    func fetchCompleted() throws -> [TaskWork] {
        let predicate = #Predicate<TaskWork> { $0.completedAt != nil }
        let sortBy = [SortDescriptor<TaskWork>(\.completedAt, order: .reverse)]
        return try fetch(where: predicate, sortBy: sortBy)
    }
    
    /// Fetch tasks due today
    func fetchDueToday() throws -> [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = #Predicate<TaskWork> { task in
            task.completedAt == nil &&
            task.dueDate != nil &&
            task.dueDate! >= today &&
            task.dueDate! < tomorrow
        }
        
        let sortBy = [SortDescriptor<TaskWork>(\.dueDate)]
        return try fetch(where: predicate, sortBy: sortBy)
    }
    
    /// Fetch overdue tasks
    /// Technical Note: Due to SwiftData predicate limitations with Date comparisons,
    /// we fetch all incomplete tasks and filter in memory
    /// Performance: O(n) - acceptable for typical task counts (< 10k)
    /// Business Rule: Overdue = has due date AND due date < now AND not completed
    func fetchOverdue() throws -> [TaskWork] {
        // Due to SwiftData predicate limitations with Date comparisons,
        // we fetch all incomplete tasks and filter in memory
        let incompleteTasks = try fetchIncomplete()
        return incompleteTasks.filter { $0.isOverdue }
    }
    
    /// Fetch tasks by energy level
    /// Technical Note: SwiftData doesn't support enum predicates (as of iOS 17)
    /// Workaround: Fetch all incomplete tasks, filter in-memory
    /// See: https://developer.apple.com/documentation/swiftdata/predicate
    func fetch(byEnergy energy: TaskEnergy) throws -> [TaskWork] {
        // SwiftData doesn't support enum predicates, filter in memory
        let allTasks = try fetchIncomplete()
        return allTasks.filter { $0.energy == energy }
    }
    
    /// Fetch tasks by size
    func fetch(bySize size: TaskSize) throws -> [TaskWork] {
        // SwiftData doesn't support enum predicates, filter in memory
        let allTasks = try fetchIncomplete()
        return allTasks.filter { $0.size == size }
    }
    
    /// Fetch tasks for a specific plan
    func fetch(forPlan planId: UUID) throws -> [TaskWork] {
        let allTasks = try fetchIncomplete()
        return allTasks.filter { $0.plan?.id == planId }
    }
    
    /// Fetch tasks for a specific journey
    func fetch(forJourney journeyId: UUID) throws -> [TaskWork] {
        let allTasks = try fetchIncomplete()
        return allTasks.filter { $0.journey?.id == journeyId }
    }
    
    /// Fetch inbox tasks (no plan, no journey)
    /// Business Rule: Inbox tasks are "unorganized" - not yet assigned to a plan or journey
    /// Use Case: Quick capture tasks that need GTD-style processing
    /// Performance: In-memory filter after fetching incomplete tasks
    func fetchInbox() throws -> [TaskWork] {
        let allTasks = try fetchIncomplete()
        return allTasks.filter { $0.plan == nil && $0.journey == nil }
    }
    
    /// Fetch tasks with specific tag
    func fetch(withTag tagName: String) throws -> [TaskWork] {
        let allTasks = try fetchAll()
        return allTasks.filter { task in
            task.tags?.contains { $0.name.localizedCaseInsensitiveCompare(tagName) == .orderedSame } ?? false
        }
    }
    
    /// Search tasks by title or detail
    func search(query: String) throws -> [TaskWork] {
        guard !query.isEmpty else { return [] }
        
        let allTasks = try fetchAll()
        let lowercasedQuery = query.lowercased()
        
        return allTasks.filter { task in
            task.title.lowercased().contains(lowercasedQuery) ||
            (task.detail?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    /// Fetch tasks within date range
    func fetch(from startDate: Date, to endDate: Date) throws -> [TaskWork] {
        let allTasks = try fetchAll()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startDate && dueDate <= endDate
        }
    }
    
    /// Fetch tasks scheduled for a specific date
    func fetchScheduled(for date: Date) throws -> [TaskWork] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let allTasks = try fetchIncomplete()
        return allTasks.filter { task in
            guard let scheduledDate = task.scheduledDate else { return false }
            return scheduledDate >= startOfDay && scheduledDate < endOfDay
        }
    }
    
    // MARK: - Statistics
    
    /// Count incomplete tasks
    func countIncomplete() throws -> Int {
        let predicate = #Predicate<TaskWork> { $0.completedAt == nil }
        return try count(where: predicate)
    }
    
    /// Count completed tasks
    func countCompleted() throws -> Int {
        let predicate = #Predicate<TaskWork> { $0.completedAt != nil }
        return try count(where: predicate)
    }
    
    /// Count overdue tasks
    func countOverdue() throws -> Int {
        return try fetchOverdue().count
    }
    
    /// Count tasks due today
    func countDueToday() throws -> Int {
        return try fetchDueToday().count
    }
    
    /// Get completion rate (percentage)
    func getCompletionRate() throws -> Double {
        let total = try count()
        guard total > 0 else { return 0 }
        
        let completed = try countCompleted()
        return Double(completed) / Double(total) * 100
    }
    
    // MARK: - Bulk Operations
    
    /// Mark task as complete
    func complete(_ task: TaskWork) throws {
        task.completedAt = Date()
        try update(task)
    }
    
    /// Mark multiple tasks as complete
    func complete(_ tasks: [TaskWork]) throws {
        let now = Date()
        for task in tasks {
            task.completedAt = now
        }
        try save()
    }
    
    /// Mark task as incomplete
    func uncomplete(_ task: TaskWork) throws {
        task.completedAt = nil
        try update(task)
    }
    
    /// Move task to plan
    func move(_ task: TaskWork, toPlan plan: Plan?) throws {
        task.plan = plan
        try update(task)
    }
    
    /// Move task to journey
    func move(_ task: TaskWork, toJourney journey: Journey?) throws {
        task.journey = journey
        try update(task)
    }
    
    /// Archive completed tasks older than a certain date
    /// Deletes completed tasks older than `date`.
    /// The TaskWork model has no `isArchived` property; archival is implemented as
    /// permanent deletion of old completed tasks. PAIMemoryBridge will record these
    /// completions in PAI episodic memory before deletion, preserving the history.
    func archiveCompleted(olderThan date: Date) throws {
        let allCompleted = try fetchCompleted()
        let toDelete = allCompleted.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt < date
        }
        try delete(toDelete)
    }
    
    /// Delete all completed tasks
    func deleteCompleted() throws {
        let completed = try fetchCompleted()
        try delete(completed)
    }
}
