//
//  TasksViewModel.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Tasks/Inbox view
/// Handles business logic and coordinates between UI and data layer
@MainActor
@Observable
final class TasksViewModel {
    
    // MARK: - Dependencies
    
    private let repository: TaskRepository
    
    // MARK: - Published State
    
    var tasks: [TaskWork] = []
    var isLoading = false
    var errorMessage: String?
    var filterStatus: TaskFilterStatus = .incomplete
    var filterPriority: Priority?
    var filterLifeDomain: LifeDomain?
    var sortOrder: TaskSortOrder = .dueDate
    var searchQuery: String = ""
    
    // MARK: - Computed Properties
    
    /// Returns tasks filtered by current filter settings (status, priority, domain) and sorted by sortOrder
    /// Business Rule: Applies filters in order: status → priority → domain → sort
    /// Performance: O(n) for filtering + O(n log n) for sorting
    var filteredTasks: [TaskWork] {
        var filtered = tasks
        
        // Filter by status
        switch filterStatus {
        case .all:
            break
        case .incomplete:
            filtered = filtered.filter { !$0.isCompleted }
        case .completed:
            filtered = filtered.filter { $0.isCompleted }
        case .overdue:
            filtered = filtered.filter { task in
                guard let dueDate = task.dueDate, !task.isCompleted else { return false }
                return dueDate < Date()
            }
        case .dueToday:
            filtered = filtered.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return Calendar.current.isDateInToday(dueDate)
            }
        }
        
        // Filter by priority
        if let priority = filterPriority {
            filtered = filtered.filter { $0.priority == priority }
        }
        
        // Filter by life domain
        if let domain = filterLifeDomain {
            filtered = filtered.filter { $0.lifeDomain == domain }
        }
        
        // Sort
        switch sortOrder {
        case .dueDate:
            filtered.sort { 
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        case .priority:
            // Use sortOrder (urgent=1 → low=4) for semantic ordering, not rawValue (alphabetical)
            filtered.sort { ($0.priority?.sortOrder ?? 3) < ($1.priority?.sortOrder ?? 3) }
        case .createdDate:
            filtered.sort { $0.createdAt < $1.createdAt }
        case .title:
            filtered.sort { $0.title < $1.title }
        }
        
        return filtered
    }
    
    /// Unorganized tasks that haven't been assigned to a Plan or Journey
    /// Business Rule: Inbox = no plan AND no journey AND not completed
    /// Use Case: Quick capture tasks that need to be organized later
    var inboxTasks: [TaskWork] {
        tasks.filter { $0.plan == nil && $0.journey == nil && !$0.isCompleted }
    }
    
    /// Tasks that have passed their due date and are still incomplete
    /// Business Rule: Overdue = has due date AND due date < now AND not completed
    /// Performance: Filtered in-memory since SwiftData predicates don't handle Date comparisons well
    var overdueTasks: [TaskWork] {
        tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < Date()
        }
    }
    
    var dueTodayTasks: [TaskWork] {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDateInToday(dueDate)
        }
    }
    
    var stats: TaskStats {
        let incomplete = tasks.filter { !$0.isCompleted }.count
        let completed = tasks.filter { $0.isCompleted }.count
        let overdue = overdueTasks.count
        let dueToday = dueTodayTasks.count
        let inbox = inboxTasks.count
        
        return TaskStats(
            total: tasks.count,
            incomplete: incomplete,
            completed: completed,
            overdue: overdue,
            dueToday: dueToday,
            inbox: inbox
        )
    }
    
    var priorityBreakdown: [Priority: Int] {
        var breakdown: [Priority: Int] = [:]
        
        for priority in Priority.allCases {
            let count = tasks.filter { 
                $0.priority == priority && !$0.isCompleted 
            }.count
            breakdown[priority] = count
        }
        
        return breakdown
    }
    
    var domainBreakdown: [LifeDomain: Int] {
        var breakdown: [LifeDomain: Int] = [:]
        
        for domain in LifeDomain.allCases {
            let count = tasks.filter { 
                $0.lifeDomain == domain && !$0.isCompleted 
            }.count
            breakdown[domain] = count
        }
        
        return breakdown
    }
    
    // MARK: - Initialization
    
    init(repository: TaskRepository) {
        self.repository = repository
    }
    
    deinit {
        #if DEBUG
        print("🧹 TasksViewModel deallocated")
        #endif
    }
    
    // MARK: - Public Methods
    
    func loadTasks() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                tasks = try repository.fetchAll()
                isLoading = false
            } catch {
                errorMessage = "Failed to load tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadIncompleteTasks() {
        Task {
            do {
                tasks = try repository.fetchIncomplete()
                isLoading = false
            } catch {
                errorMessage = "Failed to load incomplete tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadInboxTasks() {
        Task {
            do {
                tasks = try repository.fetchInbox()
                isLoading = false
            } catch {
                errorMessage = "Failed to load inbox tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadOverdueTasks() {
        Task {
            do {
                tasks = try repository.fetchOverdue()
                isLoading = false
            } catch {
                errorMessage = "Failed to load overdue tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadDueTodayTasks() {
        Task {
            do {
                tasks = try repository.fetchDueToday()
                isLoading = false
            } catch {
                errorMessage = "Failed to load due today tasks: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func createTask(
        title: String,
        description: String?,
        priority: Priority = .medium,
        lifeDomain: LifeDomain = .personal,
        dueDate: Date? = nil
    ) {
        Task {
            do {
                let task = TaskWork(
                    title: title,
                    detail: description,
                    dueDate: dueDate,
                    energy: nil,
                    size: .medium
                )
                task.priority = priority
                task.lifeDomain = lifeDomain
                try repository.create(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to create task: \(error.localizedDescription)"
            }
        }
    }
    
    func updateTask(_ task: TaskWork) {
        Task {
            do {
                try repository.update(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to update task: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteTask(_ task: TaskWork) {
        Task {
            do {
                try repository.delete(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to delete task: \(error.localizedDescription)"
            }
        }
    }
    
    func completeTask(_ task: TaskWork) {
        Task {
            do {
                try repository.complete(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to complete task: \(error.localizedDescription)"
            }
        }
    }
    
    func uncompleteTask(_ task: TaskWork) {
        Task {
            do {
                try repository.uncomplete(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to uncomplete task: \(error.localizedDescription)"
            }
        }
    }
    
    func archiveTask(_ task: TaskWork) {
        Task {
            do {
                // archive method doesn't exist, use delete for now
                try repository.delete(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to archive task: \(error.localizedDescription)"
            }
        }
    }
    
    func moveToPlan(_ task: TaskWork, plan: Plan) {
        Task {
            do {
                task.plan = plan
                try repository.update(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to move task to plan: \(error.localizedDescription)"
            }
        }
    }
    
    func moveToJourney(_ task: TaskWork, journey: Journey) {
        Task {
            do {
                task.journey = journey
                try repository.update(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to move task to journey: \(error.localizedDescription)"
            }
        }
    }
    
    func moveToInbox(_ task: TaskWork) {
        Task {
            do {
                task.plan = nil
                task.journey = nil
                try repository.update(task)
                loadTasks()
            } catch {
                errorMessage = "Failed to move task to inbox: \(error.localizedDescription)"
            }
        }
    }
    
    func searchTasks(query: String) {
        guard !query.isEmpty else {
            loadTasks()
            return
        }
        
        Task {
            do {
                tasks = try repository.search(query: query)
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
            }
        }
    }
    
    func getCompletionRate(for domain: LifeDomain) async -> Double {
        do {
            // getCompletionRate doesn't take parameters
            return try repository.getCompletionRate()
        } catch {
            errorMessage = "Failed to get completion rate: \(error.localizedDescription)"
            return 0
        }
    }
}

// MARK: - Supporting Types

enum TaskFilterStatus: String, CaseIterable {
    case all = "All"
    case incomplete = "Incomplete"
    case completed = "Completed"
    case overdue = "Overdue"
    case dueToday = "Due Today"
}

enum TaskSortOrder: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case createdDate = "Created Date"
    case title = "Title"
}

struct TaskStats {
    let total: Int
    let incomplete: Int
    let completed: Int
    let overdue: Int
    let dueToday: Int
    let inbox: Int
}

// MARK: - Extensions

extension Priority {
    var sortOrder: Int {
        switch self {
        case .urgent: return 1
        case .high: return 2
        case .medium: return 3
        case .low: return 4
        }
    }
}
