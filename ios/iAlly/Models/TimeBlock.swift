//
//  TimeBlock.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import Foundation
import SwiftData

@Model
class TimeBlock {
    var id: UUID = UUID()
    var title: String = "New Time Block"
    var startTime: Date = Date()
    var endTime: Date = Date().addingTimeInterval(3600)
    var colorHex: String = "#4C8BF5"
    var lifeDomain: LifeDomain = LifeDomain.health
    var isCompleted: Bool = false
    var notes: String?
    var createdAt: Date = Date()
    
    // Relationships
    @Relationship(deleteRule: .nullify, inverse: \TaskWork.timeBlocks) var task: TaskWork?
    @Relationship(deleteRule: .nullify, inverse: \Routine.timeBlocks) var routine: Routine?
    
    // Computed properties
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var durationMinutes: Int {
        Int(duration / 60)
    }
    
    var durationText: String {
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var isHappening: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var isUpcoming: Bool {
        Date() < startTime
    }
    
    var isPast: Bool {
        Date() > endTime
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        startTime: Date,
        endTime: Date,
        colorHex: String = "#4C8BF5",
        lifeDomain: LifeDomain = .health,
        isCompleted: Bool = false,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.colorHex = colorHex
        self.lifeDomain = lifeDomain
        self.isCompleted = isCompleted
        self.notes = notes
        self.createdAt = createdAt
    }
    
    // Check if this time block conflicts with another
    func conflicts(with other: TimeBlock) -> Bool {
        // Same day check
        let calendar = Calendar.current
        guard calendar.isDate(startTime, inSameDayAs: other.startTime) else {
            return false
        }
        
        // Time overlap check
        return (startTime < other.endTime) && (endTime > other.startTime)
    }
    
    // Get the overlapping duration with another time block
    func overlapDuration(with other: TimeBlock) -> TimeInterval? {
        guard conflicts(with: other) else { return nil }
        
        let overlapStart = max(startTime, other.startTime)
        let overlapEnd = min(endTime, other.endTime)
        
        return overlapEnd.timeIntervalSince(overlapStart)
    }
}
