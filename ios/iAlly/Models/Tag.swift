//
//  Tag.swift
//  iAlly
//
//  Created by Irigam Developer on 11/12/25.
//

import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#4C8BF5"  // Default blue
    var icon: String = "tag.fill"
    var createdAt: Date = Date()
    
    // Relationships
    var tasks: [TaskWork]? = []
    
    // Computed
    var taskCount: Int {
        tasks?.count ?? 0
    }
    
    var activeTaskCount: Int {
        tasks?.filter { $0.completedAt == nil }.count ?? 0
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#4C8BF5",
        icon: String = "tag.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.createdAt = createdAt
    }
}

// MARK: - Predefined Tag Colors
extension Tag {
    static let predefinedColors: [String] = [
        "#FF6B6B",  // Red
        "#4C8BF5",  // Blue
        "#51CF66",  // Green
        "#FFD43B",  // Yellow
        "#9775FA",  // Purple
        "#FF8787",  // Orange
        "#20C997",  // Teal
        "#FF6B9D",  // Pink
        "#868E96"   // Gray
    ]
    
    static let predefinedIcons: [String] = [
        "tag.fill",
        "star.fill",
        "heart.fill",
        "flag.fill",
        "bookmark.fill",
        "paperclip",
        "pin.fill",
        "circle.fill",
        "square.fill",
        "diamond.fill"
    ]
}
