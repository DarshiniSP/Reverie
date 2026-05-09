//
//  CustomView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

@Model
final class CustomView {
    var id: UUID = UUID()
    var name: String = "New View"
    var icon: String = "list.bullet"
    var colorHex: String = "#007AFF"
    var isDefault: Bool = false
    var createdAt: Date = Date()
    
    // Filter criteria
    var filterByCompleted: Bool = false // Include completed tasks
    var filterByOverdue: Bool = false // Show only overdue
    var filterBySize: [TaskSize] = []
    var filterByEnergy: [TaskEnergy] = []
    var filterByTags: [String] = [] // Tag names
    var filterByLifeDomains: [LifeDomain] = [] // Filter by life domains
    var filterByDueDate: DueDateFilter?
    var filterByPlan: Bool = false // Has plan
    var filterByJourney: Bool = false // Has journey
    
    // Sort and group options
    var sortBy: TaskSortOption = TaskSortOption.dueDate
    var groupBy: TaskGroupOption?
    
    // Layout
    var layoutType: ViewLayoutType = ViewLayoutType.list
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "list.bullet",
        colorHex: String = "#007AFF",
        isDefault: Bool = false,
        createdAt: Date = Date(),
        filterByCompleted: Bool = false,
        filterByOverdue: Bool = false,
        filterBySize: [TaskSize] = [],
        filterByEnergy: [TaskEnergy] = [],
        filterByTags: [String] = [],
        filterByLifeDomains: [LifeDomain] = [],
        filterByDueDate: DueDateFilter? = nil,
        filterByPlan: Bool = false,
        filterByJourney: Bool = false,
        sortBy: TaskSortOption = .dueDate,
        groupBy: TaskGroupOption? = nil,
        layoutType: ViewLayoutType = .list
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.filterByCompleted = filterByCompleted
        self.filterByOverdue = filterByOverdue
        self.filterBySize = filterBySize
        self.filterByEnergy = filterByEnergy
        self.filterByTags = filterByTags
        self.filterByLifeDomains = filterByLifeDomains
        self.filterByDueDate = filterByDueDate
        self.filterByPlan = filterByPlan
        self.filterByJourney = filterByJourney
        self.sortBy = sortBy
        self.groupBy = groupBy
        self.layoutType = layoutType
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - Enums

enum DueDateFilter: String, Codable, CaseIterable {
    case today
    case tomorrow
    case thisWeek
    case nextWeek
    case overdue
    case noDueDate
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .nextWeek: return "Next Week"
        case .overdue: return "Overdue"
        case .noDueDate: return "No Due Date"
        }
    }
}

enum TaskSortOption: String, Codable, CaseIterable {
    case dueDate
    case createdDate
    case title
    case size
    
    var displayName: String {
        switch self {
        case .dueDate: return "Due Date"
        case .createdDate: return "Created Date"
        case .title: return "Title"
        case .size: return "Size"
        }
    }
    
    var icon: String {
        switch self {
        case .dueDate: return "calendar"
        case .createdDate: return "clock"
        case .title: return "textformat"
        case .size: return "chart.bar"
        }
    }
}

enum TaskGroupOption: String, Codable, CaseIterable {
    case none
    case energy
    case dueDate
    case size
    case completed
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .energy: return "Energy"
        case .dueDate: return "Due Date"
        case .size: return "Size"
        case .completed: return "Completed"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "minus"
        case .energy: return "bolt.fill"
        case .dueDate: return "calendar"
        case .size: return "chart.bar"
        case .completed: return "checkmark.circle"
        }
    }
}

enum ViewLayoutType: String, Codable, CaseIterable {
    case list
    case grid
    case kanban
    
    var displayName: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .kanban: return "Kanban"
        }
    }
    
    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .kanban: return "rectangle.split.3x1"
        }
    }
}

// MARK: - Default Views

extension CustomView {
    static var defaultViews: [CustomView] {
        [
            CustomView(
                name: "This Week",
                icon: "calendar",
                colorHex: "#007AFF",
                isDefault: true,
                filterByDueDate: .thisWeek,
                sortBy: .dueDate
            ),
            CustomView(
                name: "Overdue",
                icon: "clock.badge.exclamationmark",
                colorHex: "#FF9500",
                isDefault: true,
                filterByOverdue: true,
                sortBy: .dueDate
            ),
            CustomView(
                name: "Quick Wins",
                icon: "bolt.fill",
                colorHex: "#34C759",
                isDefault: true,
                filterBySize: [.small],
                sortBy: .dueDate
            ),
            CustomView(
                name: "By Size",
                icon: "chart.bar",
                colorHex: "#5856D6",
                isDefault: true,
                sortBy: .size,
                groupBy: .size,
                layoutType: .kanban
            )
        ]
    }
}
