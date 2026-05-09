//
//  Task.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import Foundation
import SwiftData

@Model
final class TaskWork {
    var id: UUID = UUID()
    var title: String = ""
    var detail: String?
    var createdAt: Date = Date()
    var dueDate: Date?
    var completedAt: Date?
    var completionReflection: String?  // Reflection note when task completed
    
    // Task attributes from domain architecture
    var energy: TaskEnergy?  // Optional: Can be set upfront or learned from completion
    var size: TaskSize = TaskSize.medium
    var category: String?
    var whyItMatters: String?
    var priority: Priority?
    var lifeDomain: LifeDomain?
    
    // Relationships
    var plan: Plan?
    var journey: Journey?
    var milestone: Milestone?  // Week 1 enhancement: Link to specific milestone
    var routine: Routine? // Link to parent routine if auto-generated
    var tags: [Tag]? = []  // Many-to-many relationship with tags
    
    // Subtask relationships
    var parentTask: TaskWork?
    @Relationship(deleteRule: .cascade, inverse: \TaskWork.parentTask)
    var subtasks: [TaskWork]?
    
    var timeBlocks: [TimeBlock]? // Inverse relationship
    
    @Relationship(deleteRule: .cascade, inverse: \FocusSession.task)
    var focusSessions: [FocusSession]?
    
    // Recurrence properties
    var isRecurring: Bool = false // True if generated from a routine
    var generatedDate: Date? // When this task was auto-generated
    var scheduledDate: Date? // The target date for this recurring task instance
    
    // Demo data flag
    var isDemo: Bool = false // True if this is demo data that can be removed

    // Inbox origin flag — true when task was created from the Inbox tab's "+" button.
    // Inbox tasks with a future due date appear in both Inbox and Upcoming.
    // On the due date they move to Today only (Inbox filter excludes today/past dates).
    var isInbox: Bool = false
    
    // Checklist — lightweight checkbox items within this task
    var checklistItems: [ChecklistItem] = []

    // Growth Mindset tracking
    var missCount: Int = 0 // Number of times task was missed/overdue
    var rescheduleCount: Int = 0 // Number of times task was rescheduled
    var recoveryCount: Int = 0 // Number of times task was completed after being overdue
    var wasOverdueWhenCompleted: Bool = false // Track if completed after overdue
    
    // Relationship to mindset events
    @Relationship(deleteRule: .cascade, inverse: \MindsetEvent.task) var mindsetEvents: [MindsetEvent]?
    
    // Computed
    var isCompleted: Bool {
        completedAt != nil
    }
    
    // Subtask computed properties
    var isSubtask: Bool {
        parentTask != nil
    }
    
    var hasSubtasks: Bool {
        !(subtasks?.isEmpty ?? true)
    }
    
    var completionProgress: Double {
        guard let subtasks = subtasks, !subtasks.isEmpty else { return 0 }
        let completed = subtasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(subtasks.count)
    }
    
    var completedSubtaskCount: Int {
        subtasks?.filter { $0.isCompleted }.count ?? 0
    }
    
    var totalSubtaskCount: Int {
        subtasks?.count ?? 0
    }

    // Checklist computed properties
    var hasChecklist: Bool {
        !checklistItems.isEmpty
    }

    var checklistProgress: Double {
        guard !checklistItems.isEmpty else { return 0 }
        let completed = checklistItems.filter { $0.isCompleted }.count
        return Double(completed) / Double(checklistItems.count)
    }

    var completedChecklistCount: Int {
        checklistItems.filter { $0.isCompleted }.count
    }

    var totalChecklistCount: Int {
        checklistItems.count
    }

    // Validation: prevent circular references and nesting
    func canSetParent(_ potentialParent: TaskWork) -> Bool {
        // Can't be own parent
        if potentialParent.id == self.id { return false }
        // Can't set a subtask as parent (no nesting)
        if potentialParent.isSubtask { return false }
        // Can't set own subtask as parent
        if potentialParent.parentTask?.id == self.id { return false }
        return true
    }
    
    // MARK: - Color Coding
    
    /// Category color based on plan/journey/routine
    var categoryColor: String {
        if let plan = plan {
            return plan.colorHex
        } else if let journey = journey {
            return journey.colorHex
        } else if let routine = routine {
            return routine.colorHex
        } else {
            return "#007AFF" // Blue for standalone tasks (more visible)
        }
    }
    
    /// Display color with opacity for subtasks
    var displayColorHex: String {
        return categoryColor
    }
    
    /// Opacity for visual hierarchy (1.0 for tasks, 0.5 for subtasks)
    var displayOpacity: Double {
        return isSubtask ? 0.5 : 1.0
    }
    
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date()
    }
    
    var resilienceScore: Double {
        let totalEvents = missCount + rescheduleCount + recoveryCount
        guard totalEvents > 0 else { return 1.0 }
        return Double(recoveryCount) / Double(totalEvents)
    }
    
    // MARK: - Time Tracking
    
    // Get actual time from most reliable source
    var actualTimeMinutes: Double? {
        // Priority 1: Focus timer data (most accurate)
        if let sessions = focusSessions, !sessions.isEmpty {
            let totalSeconds = sessions.compactMap { $0.actualDuration }.reduce(0, +)
            if totalSeconds > 0 {
                return totalSeconds / 60.0
            }
        }
        
        // Priority 2: User-reported time from mindset event
        if let event = mindsetEvents?.first(where: { $0.actualTime != nil }) {
            return event.actualTime?.midpointMinutes
        }
        
        return nil
    }
    
    var timeSource: TimeSource? {
        // Determine which source we used
        if let sessions = focusSessions, !sessions.isEmpty {
            let totalSeconds = sessions.compactMap { $0.actualDuration }.reduce(0, +)
            if totalSeconds > 0 {
                return .focusTimer
            }
        }
        
        if mindsetEvents?.first(where: { $0.actualTime != nil }) != nil {
            return .userReported
        }
        
        return nil
    }
    
    var estimatedTimeMinutes: Double {
        switch size {
        case .small: return 30
        case .medium: return 45  // Midpoint of 30-60
        case .large: return 90
        }
    }
    
    var timeAccuracyRatio: Double? {
        guard let actual = actualTimeMinutes else { return nil }
        return actual / estimatedTimeMinutes
    }
    
    var timeVarianceDescription: String? {
        guard let ratio = timeAccuracyRatio else { return nil }
        
        if ratio < 0.5 {
            return "Took much less time than expected"
        } else if ratio < 0.8 {
            return "Took less time than expected"
        } else if ratio > 2.0 {
            return "Took much longer than expected"
        } else if ratio > 1.5 {
            return "Took longer than expected"
        } else {
            return "About as expected"
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        dueDate: Date? = nil,
        energy: TaskEnergy? = nil,  // Now optional
        size: TaskSize = .medium,
        category: String? = nil,
        whyItMatters: String? = nil,
        isRecurring: Bool = false,
        generatedDate: Date? = nil,
        scheduledDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.energy = energy
        self.size = size
        self.category = category
        self.whyItMatters = whyItMatters
        self.isRecurring = isRecurring
        self.generatedDate = generatedDate
        self.scheduledDate = scheduledDate
    }
}

enum TaskEnergy: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var icon: String {
        switch self {
        case .low: return "battery.25"
        case .medium: return "battery.50"
        case .high: return "battery.100"
        }
    }
}

enum TaskSize: String, Codable, CaseIterable {
    case small = "Small"   // < 30 min
    case medium = "Medium" // 30-60 min
    case large = "Large"   // > 60 min
    
    var icon: String {
        switch self {
        case .small: return "circle.fill"
        case .medium: return "circle.circle.fill"
        case .large: return "circle.hexagongrid.fill"
        }
    }
    
    var timeDescription: String {
        switch self {
        case .small: return "< 30 min"
        case .medium: return "30-60 min"
        case .large: return "> 60 min"
        }
    }
}

enum Priority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"
    
    var icon: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .urgent: return "exclamationmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#8E8E93"
        case .medium: return "#007AFF"
        case .high: return "#FF9500"
        case .urgent: return "#FF3B30"
        }
    }
}
