//
//  Journey.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import Foundation
import SwiftData

@Model
final class Journey {
    var id: UUID = UUID()
    var title: String = ""
    var vision: String?
    var createdAt: Date = Date()
    var startDate: Date = Date()
    var targetDate: Date?
    var colorHex: String = "#7A5AF5"
    var icon: String = "flag.fill"
    var lifeDomain: LifeDomain = LifeDomain.personal
    
    // Demo data flag
    var isDemo: Bool = false // True if this is demo data that can be removed
    
    // Status tracking (Week 1 enhancement)
    var status: JourneyStatus?
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Milestone.journey)
    var milestones: [Milestone]?
    
    @Relationship(deleteRule: .nullify, inverse: \TaskWork.journey)
    var tasks: [TaskWork]?
    
    // Computed progress (0.0 to 1.0 based on completed milestones)
    var progress: Double {
        guard let milestones = milestones, !milestones.isEmpty else { return 0.0 }
        let completedCount = milestones.filter { $0.isCompleted }.count
        return Double(completedCount) / Double(milestones.count)
    }
    
    // Check if journey is overdue
    var isOverdue: Bool {
        guard let targetDate = targetDate else { return false }
        return Date() > targetDate && status != .completed && status != nil
    }
    
    // Days remaining until target date
    var daysRemaining: Int? {
        guard let targetDate = targetDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
        return components.day
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        vision: String? = nil,
        createdAt: Date = Date(),
        startDate: Date = Date(),
        targetDate: Date? = nil,
        colorHex: String = "#7A5AF5",
        icon: String = "flag.fill",
        status: JourneyStatus? = .notStarted,
        lifeDomain: LifeDomain = .personal
    ) {
        self.id = id
        self.title = title
        self.vision = vision
        self.createdAt = createdAt
        self.startDate = startDate
        self.targetDate = targetDate
        self.colorHex = colorHex
        self.icon = icon
        self.status = status
        self.lifeDomain = lifeDomain
    }
}

enum JourneyStatus: String, Codable, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case completed = "Completed"
    case paused = "Paused"
    
    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .inProgress: return "arrow.clockwise.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .notStarted: return "#8E8E93"
        case .inProgress: return "#4C8BF5"
        case .completed: return "#2BBB7F"
        case .paused: return "#F5A623"
        }
    }
}

@Model
final class Milestone {
    var id: UUID = UUID()
    var title: String = ""
    var targetDate: Date?
    var completedAt: Date?
    var order: Int = 0
    
    // Relationships
    var journey: Journey?
    
    @Relationship(deleteRule: .nullify, inverse: \TaskWork.milestone)
    var tasks: [TaskWork]?  // Week 1 enhancement: Tasks linked to this milestone
    
    var isCompleted: Bool {
        completedAt != nil
    }
    
    // Check if all tasks attached to milestone are completed
    var canBeCompleted: Bool {
        guard let tasks = tasks, !tasks.isEmpty else { return true }
        return tasks.allSatisfy { $0.completedAt != nil }
    }
    
    // Check if milestone is overdue
    var isOverdue: Bool {
        guard let targetDate = targetDate else { return false }
        return Date() > targetDate && !isCompleted
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        targetDate: Date? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.order = order
    }
}
