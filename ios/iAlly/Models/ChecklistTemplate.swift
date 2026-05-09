//
//  ChecklistTemplate.swift
//  iAlly
//
//  Reusable checklist template (e.g. "Flight Prep", "Grocery Basics").
//  Stored as SwiftData model so templates persist across tasks.
//

import Foundation
import SwiftData

@Model
final class ChecklistTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var icon: String = "checklist"
    var items: [String] = []
    var createdAt: Date = Date()
    var usageCount: Int = 0

    init(name: String, icon: String = "checklist", items: [String]) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.items = items
        self.createdAt = Date()
        self.usageCount = 0
    }
}
