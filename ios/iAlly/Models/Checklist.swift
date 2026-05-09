//
//  Checklist.swift
//  iAlly
//
//  Standalone checklist entity for groceries, travel, exams, bill payments, etc.
//  Reuses the existing ChecklistItem value type for individual items.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Checklist {
    var id: UUID = UUID()
    var title: String = ""
    var icon: String = "checklist"
    var colorHex: String = "#4C8BF5"
    var items: [ChecklistItem] = []
    var createdAt: Date = Date()
    var lastUsedDate: Date?
    var isRecurring: Bool = false
    var isDemo: Bool = false
    var isDeleted: Bool = false

    // MARK: - Computed Properties

    var completedCount: Int {
        items.filter { $0.isCompleted }.count
    }

    var totalCount: Int {
        items.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isAllCompleted: Bool {
        totalCount > 0 && completedCount == totalCount
    }

    var color: Color {
        Color(hex: colorHex)
    }

    // MARK: - Init

    init(
        title: String,
        icon: String = "checklist",
        colorHex: String = "#4C8BF5",
        items: [ChecklistItem] = [],
        isRecurring: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.colorHex = colorHex
        self.items = items
        self.createdAt = Date()
        self.isRecurring = isRecurring
    }

    // MARK: - Helpers

    /// Resets all items to uncompleted (useful for recurring checklists).
    func resetAll() {
        for i in items.indices {
            items[i].isCompleted = false
            items[i].completedAt = nil
        }
        lastUsedDate = Date()
    }
}
