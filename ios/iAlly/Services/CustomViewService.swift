//
//  CustomViewService.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

class CustomViewService {
    static let shared = CustomViewService()
    
    private init() {}
    
    // MARK: - Filter Tasks
    
    func filterTasks(_ tasks: [TaskWork], using view: CustomView) -> [TaskWork] {
        var filtered = tasks
        
        // Filter by completion status
        if !view.filterByCompleted {
            filtered = filtered.filter { !$0.isCompleted }
        }
        
        // Filter by overdue
        if view.filterByOverdue {
            filtered = filtered.filter { $0.isOverdue }
        }
        
        // Filter by size
        if !view.filterBySize.isEmpty {
            filtered = filtered.filter { view.filterBySize.contains($0.size) }
        }
        
        // Filter by energy
        if !view.filterByEnergy.isEmpty {
            filtered = filtered.filter { task in
                if let energy = task.energy {
                    return view.filterByEnergy.contains(energy)
                }
                return false
            }
        }
        
        // Filter by tags
        if !view.filterByTags.isEmpty {
            filtered = filtered.filter { task in
                guard let tags = task.tags else { return false }
                let taskTagNames = tags.map { $0.name }
                return !Set(taskTagNames).isDisjoint(with: Set(view.filterByTags))
            }
        }
        
        // Filter by life domains
        if !view.filterByLifeDomains.isEmpty {
            filtered = filtered.filter { task in
                if let domain = task.lifeDomain {
                    return view.filterByLifeDomains.contains(domain)
                }
                return false
            }
        }
        
        // Filter by plan
        if view.filterByPlan {
            filtered = filtered.filter { $0.plan != nil }
        }
        
        // Filter by journey
        if view.filterByJourney {
            filtered = filtered.filter { $0.journey != nil }
        }
        
        // Filter by due date
        if let dueDateFilter = view.filterByDueDate {
            filtered = filterByDueDate(filtered, filter: dueDateFilter)
        }
        
        return filtered
    }
    
    private func filterByDueDate(_ tasks: [TaskWork], filter: DueDateFilter) -> [TaskWork] {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .today:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDateInToday(dueDate)
            }
            
        case .tomorrow:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDateInTomorrow(dueDate)
            }
            
        case .thisWeek:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, equalTo: now, toGranularity: .weekOfYear)
            }
            
        case .nextWeek:
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) else {
                return []
            }
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return calendar.isDate(dueDate, equalTo: nextWeek, toGranularity: .weekOfYear)
            }
            
        case .overdue:
            return tasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < now && !task.isCompleted
            }
            
        case .noDueDate:
            return tasks.filter { $0.dueDate == nil }
        }
    }
    
    // MARK: - Sort Tasks
    
    func sortTasks(_ tasks: [TaskWork], by option: TaskSortOption) -> [TaskWork] {
        switch option {
        case .dueDate:
            return tasks.sorted { task1, task2 in
                // No due date goes last
                if task1.dueDate == nil { return false }
                if task2.dueDate == nil { return true }
                return task1.dueDate! < task2.dueDate!
            }
            
        case .createdDate:
            return tasks.sorted { $0.createdAt > $1.createdAt }
            
        case .title:
            return tasks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
        case .size:
            return tasks.sorted { $0.size.rawValue < $1.size.rawValue }
        }
    }
    
    // MARK: - Group Tasks
    
    func groupTasks(_ tasks: [TaskWork], by option: TaskGroupOption?) -> [String: [TaskWork]] {
        guard let option = option else {
            return ["All": tasks]
        }
        
        switch option {
        case .none:
            return ["All": tasks]
            
        case .energy:
            return Dictionary(grouping: tasks) { task in
                task.energy?.rawValue ?? "No Energy"
            }
            
        case .dueDate:
            let calendar = Calendar.current
            return Dictionary(grouping: tasks) { task in
                guard let dueDate = task.dueDate else { return "No Due Date" }
                
                if calendar.isDateInToday(dueDate) {
                    return "Today"
                } else if calendar.isDateInTomorrow(dueDate) {
                    return "Tomorrow"
                } else if calendar.isDate(dueDate, equalTo: Date(), toGranularity: .weekOfYear) {
                    return "This Week"
                } else if dueDate < Date() {
                    return "Overdue"
                } else {
                    return "Later"
                }
            }
            
        case .size:
            return Dictionary(grouping: tasks) { $0.size.rawValue }
            
        case .completed:
            return Dictionary(grouping: tasks) { task in
                task.isCompleted ? "Completed" : "Incomplete"
            }
        }
    }
    
    // MARK: - Apply View
    
    func applyView(_ view: CustomView, to tasks: [TaskWork]) -> [TaskWork] {
        var result = filterTasks(tasks, using: view)
        result = sortTasks(result, by: view.sortBy)
        return result
    }
    
    // MARK: - Manage Views
    
    func createView(_ view: CustomView, context: ModelContext) throws {
        context.insert(view)
        try context.save()
    }
    
    func updateView(_ view: CustomView, context: ModelContext) throws {
        try context.save()
    }
    
    func deleteView(_ view: CustomView, context: ModelContext) throws {
        guard !view.isDefault else {
            throw CustomViewError.cannotDeleteDefaultView
        }
        
        context.delete(view)
        try context.save()
    }
    
    func getAllViews(context: ModelContext) -> [CustomView] {
        let descriptor = FetchDescriptor<CustomView>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func initializeDefaultViews(context: ModelContext) throws {
        let existing = getAllViews(context: context)
        
        // Only add default views if none exist
        if existing.isEmpty {
            for defaultView in CustomView.defaultViews {
                context.insert(defaultView)
            }
            try context.save()
        }
    }
}

// MARK: - Errors

enum CustomViewError: LocalizedError {
    case cannotDeleteDefaultView
    
    var errorDescription: String? {
        switch self {
        case .cannotDeleteDefaultView:
            return "Cannot delete default views"
        }
    }
}
