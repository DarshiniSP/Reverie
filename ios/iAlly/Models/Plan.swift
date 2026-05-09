//
//  Plan.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import Foundation
import SwiftData

@Model
final class Plan {
    var id: UUID = UUID()
    var name: String = ""
    var lifeDomain: LifeDomain = LifeDomain.personal
    var icon: String = "folder.fill"
    var colorHex: String = "#4C8BF5"
    var createdAt: Date = Date()
    
    // Demo data flag
    var isDemo: Bool = false // True if this is demo data that can be removed
    
    // Goal tracking (Week 1 enhancement)
    var goal: String?
    var targetMetric: String?
    var status: PlanStatus?
    
    // Growth Mindset learning data
    var energyDistribution: [String: Int] = [:] // Track high/medium/low energy task completion
    var sizeDistribution: [String: Int] = [:] // Track small/medium/large task completion
    var averageCompletionTime: Double? // In days from creation to completion
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \TaskWork.plan)
    var tasks: [TaskWork]?
    
    // Computed property: Progress based on completed tasks
    var completionRate: Double {
        guard let tasks = tasks, !tasks.isEmpty else { return 0.0 }
        let completedCount = tasks.filter { $0.completedAt != nil }.count
        return Double(completedCount) / Double(tasks.count)
    }
    
    var activeTaskCount: Int {
        tasks?.filter { $0.completedAt == nil }.count ?? 0
    }
    
    var completedTaskCount: Int {
        tasks?.filter { $0.completedAt != nil }.count ?? 0
    }
    
    // Learning insights
    var preferredEnergyLevel: String? {
        guard !energyDistribution.isEmpty else { return nil }
        return energyDistribution.max(by: { $0.value < $1.value })?.key
    }
    
    var preferredTaskSize: String? {
        guard !sizeDistribution.isEmpty else { return nil }
        return sizeDistribution.max(by: { $0.value < $1.value })?.key
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        lifeDomain: LifeDomain,
        icon: String = "folder.fill",
        colorHex: String = "#4C8BF5",
        createdAt: Date = Date(),
        goal: String? = nil,
        targetMetric: String? = nil,
        status: PlanStatus? = .active
    ) {
        self.id = id
        self.name = name
        self.lifeDomain = lifeDomain
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.goal = goal
        self.targetMetric = targetMetric
        self.status = status
    }
}

enum PlanStatus: String, Codable, CaseIterable {
    case active = "Active"
    case onHold = "On Hold"
    case archived = "Archived"
    
    var icon: String {
        switch self {
        case .active: return "play.circle.fill"
        case .onHold: return "pause.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "#2BBB7F"
        case .onHold: return "#F5A623"
        case .archived: return "#8E8E93"
        }
    }
}

enum LifeDomain: String, Codable, CaseIterable {
    case health = "Health"
    case career = "Career"
    case relationships = "Relationships"
    case learning = "Learning"
    case creativity = "Creativity"
    case finance = "Finance"
    case home = "Home"
    case personal = "Personal"
    
    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .career: return "briefcase.fill"
        case .relationships: return "person.2.fill"
        case .learning: return "book.fill"
        case .creativity: return "paintbrush.fill"
        case .finance: return "dollarsign.circle.fill"
        case .home: return "house.fill"
        case .personal: return "star.fill"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .health: return "#2BBB7F"
        case .career: return "#4C8BF5"
        case .relationships: return "#E14B4B"
        case .learning: return "#7A5AF5"
        case .creativity: return "#F5A623"
        case .finance: return "#2BBB7F"
        case .home: return "#4C8BF5"
        case .personal: return "#7A5AF5"
        }
    }
}

