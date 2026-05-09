//
//  BatchOperationService.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import Foundation
import SwiftData

/// Service for performing batch operations on tasks
class BatchOperationService {
    static let shared = BatchOperationService()
    
    private init() {}
    
    // MARK: - Complete Operations
    
    /// Complete multiple tasks at once
    func completeTasks(_ tasks: [TaskWork], energy: TaskEnergy?, context: ModelContext) {
        for task in tasks {
            task.completedAt = Date()
            task.energy = energy

            // Cancel pending notifications
            let taskId = task.id.uuidString
            _Concurrency.Task {
                await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
            }

            // Record to PAI memory
            PAIMemoryBridge.shared.recordTaskCompleted(task)

            // Update routine streak if applicable
            if let routine = task.routine {
                RoutineManager.shared.updateStreakForRoutine(routine, completionDate: Date(), context: context)
            }
        }
        try? context.save()
        WidgetHelper.shared.reloadAllWidgets()
    }
    
    /// Uncomplete multiple tasks
    func uncompleteTasks(_ tasks: [TaskWork], context: ModelContext) {
        for task in tasks {
            task.completedAt = nil
            task.energy = nil
        }
        try? context.save()
    }
    
    // MARK: - Delete Operations
    
    /// Delete multiple tasks
    func deleteTasks(_ tasks: [TaskWork], context: ModelContext) {
        for task in tasks {
            // Cancel pending notifications before deleting
            let taskId = task.id.uuidString
            _Concurrency.Task {
                await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
            }
            context.delete(task)
        }
        try? context.save()
        WidgetHelper.shared.reloadAllWidgets()
    }
    
    // MARK: - Tag Operations
    
    /// Add tags to multiple tasks
    func addTags(_ tags: [Tag], to tasks: [TaskWork], context: ModelContext) {
        for task in tasks {
            if task.tags == nil {
                task.tags = []
            }
            
            for tag in tags {
                if !(task.tags?.contains(where: { $0.id == tag.id }) ?? false) {
                    task.tags?.append(tag)
                }
            }
        }
        try? context.save()
    }
    
    /// Remove tags from multiple tasks
    func removeTags(_ tags: [Tag], from tasks: [TaskWork], context: ModelContext) {
        for task in tasks {
            task.tags?.removeAll { tag in
                tags.contains(where: { $0.id == tag.id })
            }
        }
        try? context.save()
    }
    
    // MARK: - Reschedule Operations
    
    /// Reschedule multiple tasks to a new date
    func rescheduleTasks(_ tasks: [TaskWork], to date: Date, context: ModelContext) {
        for task in tasks {
            task.dueDate = date
            // Reschedule notifications
            let taskId = task.id.uuidString
            let title = task.title
            _Concurrency.Task {
                await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
                if date > Date() {
                    await NotificationManager.shared.scheduleTaskDueNotification(
                        taskId: taskId, taskTitle: title, dueDate: date
                    )
                }
            }
        }
        try? context.save()
    }
    
    /// Clear due dates from multiple tasks
    func clearDueDates(from tasks: [TaskWork], context: ModelContext) {
        for task in tasks {
            task.dueDate = nil
        }
        try? context.save()
    }
    
    // MARK: - Move Operations
    
    /// Move tasks to a different plan
    func moveTasks(_ tasks: [TaskWork], to plan: Plan?, context: ModelContext) {
        for task in tasks {
            task.plan = plan
            task.journey = nil // Clear journey when moving to plan
        }
        try? context.save()
    }
    
    /// Move tasks to a journey
    func moveTasks(_ tasks: [TaskWork], to journey: Journey?, context: ModelContext) {
        for task in tasks {
            task.journey = journey
            task.plan = nil // Clear plan when moving to journey
        }
        try? context.save()
    }
    
    // MARK: - Size Operations
    
    /// Change size for multiple tasks
    func changeSize(of tasks: [TaskWork], to size: TaskSize, context: ModelContext) {
        for task in tasks {
            task.size = size
        }
        try? context.save()
    }
    
    // MARK: - Archive Operations
    // Note: Archive functionality not yet implemented in Task model
    
    // Future: Archive multiple tasks
    // func archiveTasks(_ tasks: [TaskWork], context: ModelContext) {
    //     for task in tasks {
    //         task.isArchived = true
    //     }
    //     try? context.save()
    // }
    
    // Future: Unarchive multiple tasks
    // func unarchiveTasks(_ tasks: [TaskWork], context: ModelContext) {
    //     for task in tasks {
    //         task.isArchived = false
    //     }
    //     try? context.save()
    // }
}

// MARK: - Batch Operation Result

struct BatchOperationResult {
    let successCount: Int
    let failureCount: Int
    let operation: String
    
    var message: String {
        if failureCount == 0 {
            return "\(successCount) tasks \(operation) successfully"
        } else {
            return "\(successCount) tasks \(operation), \(failureCount) failed"
        }
    }
}
