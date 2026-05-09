//
//  ArchiveService.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import Foundation
import SwiftData

@MainActor
class ArchiveService {
    private let modelContext: ModelContext
    private let archiveThresholdDays: Int
    
    init(modelContext: ModelContext, archiveThresholdDays: Int = 30) {
        self.modelContext = modelContext
        self.archiveThresholdDays = archiveThresholdDays
    }
    
    // MARK: - Cleanup (Delete Old Completed Tasks)
    
    /// Permanently deletes a task
    func deletePermanently(_ task: TaskWork) {
        modelContext.delete(task)
        try? modelContext.save()
    }
    
    // MARK: - Auto-Cleanup (Stale Data)
    
    /// Identifies and archives stale tasks and routines
    func performAutoCleanup() async -> (archivedTasks: Int, archivedRoutines: Int) {
        let (staleTasks, staleRoutines) = await identifyStalelItems()
        
        var archivedTaskCount = 0
        var archivedRoutineCount = 0
        
        // Delete stale tasks (completed >30 days ago)
        for task in staleTasks {
            modelContext.delete(task)
            archivedTaskCount += 1
        }
        
        // Routines are still hard-deleted/or logic implies they are different. 
        // For now, we will keeping existing routine logic but use 'archiveRoutine' (private).
        for routine in staleRoutines {
            archiveRoutine(routine)
            archivedRoutineCount += 1
        }
        
        try? modelContext.save()
        
        return (archivedTaskCount, archivedRoutineCount)
    }
    
    /// Identifies tasks and routines that haven't had activity in threshold days
    private func identifyStalelItems() async -> (tasks: [TaskWork], routines: [Routine]) {
        let calendar = Calendar.current
        let thresholdDate = calendar.date(byAdding: .day, value: -archiveThresholdDays, to: Date())!
        
        // Fetch all tasks
        let taskDescriptor = FetchDescriptor<TaskWork>(
        )
        let allTasks = (try? modelContext.fetch(taskDescriptor)) ?? []
        
        // Find stale tasks: incomplete, no recent activity, older than threshold
        let staleTasks = allTasks.filter { task in
            guard task.completedAt == nil else { return false }
            
            // Check if task is older than threshold
            guard task.createdAt < thresholdDate else { return false }
            
            // Check if no recent updates
            if let dueDate = task.dueDate, dueDate > thresholdDate {
                return false // Has a future due date, keep it
            }
            
            // Check if any recent mindset events
            if let events = task.mindsetEvents, !events.isEmpty {
                let recentEvents = events.filter { $0.timestamp > thresholdDate }
                if !recentEvents.isEmpty {
                    return false // Has recent activity
                }
            }
            
            return true
        }
        
        // Fetch all routines
        let routineDescriptor = FetchDescriptor<Routine>()
        let allRoutines = (try? modelContext.fetch(routineDescriptor)) ?? []
        
        // Find stale routines: inactive for threshold days
        let staleRoutines = allRoutines.filter { routine in
            guard !routine.isActive else { return false }
            
            // Check if any recent mindset events
            if let events = routine.mindsetEvents, !events.isEmpty {
                let recentEvents = events.filter { $0.timestamp > thresholdDate }
                if !recentEvents.isEmpty {
                    return false // Has recent activity
                }
            }
            
            // No recent activity and inactive
            return true
        }
        
        return (staleTasks, staleRoutines)
    }
    
    /// Archives a routine by recording event and deleting it
    private func archiveRoutine(_ routine: Routine) {
        // Record event before deleting
        let event = MindsetEvent(
            eventType: .abandoned,
            contextNotes: "Auto-archived routine after \(archiveThresholdDays) days inactive",
            emotionalState: nil,
            routine: routine
        )
        modelContext.insert(event)
        
        // Delete routine (generated tasks will be orphaned but kept)
        modelContext.delete(routine)
    }
    
    /// Preview what would be archived without actually doing it
    func previewCleanup() async -> (taskCount: Int, routineCount: Int, items: [(String, String)]) {
        let (staleTasks, staleRoutines) = await identifyStalelItems()
        
        var items: [(String, String)] = []
        
        for task in staleTasks {
            let age = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
            items.append(("Task", "\(task.title) (\(age) days old)"))
        }
        
        for routine in staleRoutines {
            items.append(("Routine", routine.title))
        }
        
        return (staleTasks.count, staleRoutines.count, items)
    }
}

// MARK: - Settings for Auto-Cleanup
struct ArchiveSettings {
    static let enableAutoCleanup = "enableAutoCleanup"
    static let archiveThresholdDays = "archiveThresholdDays"
    
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enableAutoCleanup) }
        set { UserDefaults.standard.set(newValue, forKey: enableAutoCleanup) }
    }
    
    static var thresholdDays: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: archiveThresholdDays)
            return value > 0 ? value : 30 // Default 30 days
        }
        set { UserDefaults.standard.set(newValue, forKey: archiveThresholdDays) }
    }
}
