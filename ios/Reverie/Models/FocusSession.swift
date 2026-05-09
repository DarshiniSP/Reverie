//
//  FocusSession.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import Foundation
import SwiftData

@Model
final class FocusSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var completedAt: Date?
    var duration: TimeInterval = 25 * 60  // Planned duration in seconds, default 25 minutes
    var actualDuration: TimeInterval?  // Actual time worked
    var isCompleted: Bool = false
    var taskTitle: String?
    
    // Relationship to task
    var task: TaskWork?
    
    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        duration: TimeInterval = 25 * 60,  // Default 25 minutes
        taskTitle: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.duration = duration
        self.taskTitle = taskTitle
        self.isCompleted = false
    }
    
    func complete(actualDuration: TimeInterval) {
        self.completedAt = Date()
        self.actualDuration = actualDuration
        self.isCompleted = true
    }
}
