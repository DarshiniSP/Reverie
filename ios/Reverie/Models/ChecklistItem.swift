//
//  ChecklistItem.swift
//  iAlly
//
//  Lightweight checkbox item stored as a Codable array on TaskWork.
//  Not a SwiftData model — these are value types embedded in the task.
//

import Foundation

struct ChecklistItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var order: Int
    var completedAt: Date?

    init(title: String, order: Int = 0, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.order = order
        self.isCompleted = isCompleted
    }
}
