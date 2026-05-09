//
//  MindsetEvent.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import Foundation
import SwiftData

@Model
final class MindsetEvent {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var eventType: EventType = EventType.completed
    var contextNotes: String?
    var emotionalState: EmotionalState?
    
    // Post-completion reflection (captured after task/routine completion)
    var sentiment: TaskSentiment?  // How the user felt about completing this
    var actualEnergy: TaskEnergy?  // Actual energy required (vs predicted)
    var actualTime: ActualTime?  // User-reported actual time taken
    var timeSource: TimeSource?  // How the time was measured
    
    // Relationships
    var task: TaskWork?
    var routine: Routine?
    
    // Inverse relationship for GrowthInsight
    var relatedInsights: [GrowthInsight]?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: EventType,
        contextNotes: String? = nil,
        emotionalState: EmotionalState? = nil,
        sentiment: TaskSentiment? = nil,
        actualEnergy: TaskEnergy? = nil,
        actualTime: ActualTime? = nil,
        timeSource: TimeSource? = nil,
        task: TaskWork? = nil,
        routine: Routine? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.contextNotes = contextNotes
        self.emotionalState = emotionalState
        self.sentiment = sentiment
        self.actualEnergy = actualEnergy
        self.actualTime = actualTime
        self.timeSource = timeSource
        self.task = task
        self.routine = routine
    }
}

// MARK: - Event Type
enum EventType: String, Codable, CaseIterable {
    case missed = "Missed"
    case rescheduled = "Rescheduled"
    case recovered = "Recovered"
    case abandoned = "Abandoned"
    case completed = "Completed"
    case streakBroken = "Streak Broken"
    case streakRecovered = "Streak Recovered"
    
    var icon: String {
        switch self {
        case .missed: return "xmark.circle"
        case .rescheduled: return "calendar.badge.clock"
        case .recovered: return "arrow.uturn.forward.circle.fill"
        case .abandoned: return "trash"
        case .completed: return "checkmark.circle.fill"
        case .streakBroken: return "flame.slash"
        case .streakRecovered: return "flame.fill"
        }
    }
    
    var color: String {
        switch self {
        case .missed, .abandoned, .streakBroken: return "red"
        case .rescheduled: return "orange"
        case .recovered, .completed, .streakRecovered: return "green"
        }
    }
    
    var isPositive: Bool {
        switch self {
        case .recovered, .completed, .streakRecovered: return true
        default: return false
        }
    }
}

// MARK: - Emotional State
enum EmotionalState: String, Codable, CaseIterable {
    case motivated = "Motivated"
    case overwhelmed = "Overwhelmed"
    case confident = "Confident"
    case anxious = "Anxious"
    case accomplished = "Accomplished"
    case frustrated = "Frustrated"
    case neutral = "Neutral"
    
    var icon: String {
        switch self {
        case .motivated: return "bolt.fill"
        case .overwhelmed: return "exclamationmark.triangle"
        case .confident: return "star.fill"
        case .anxious: return "cloud.rain"
        case .accomplished: return "trophy.fill"
        case .frustrated: return "exclamationmark.circle"
        case .neutral: return "minus.circle"
        }
    }
    
    var color: String {
        switch self {
        case .motivated, .confident, .accomplished: return "green"
        case .overwhelmed, .anxious, .frustrated: return "red"
        case .neutral: return "gray"
        }
    }
}

// MARK: - Task Sentiment (Post-Completion)
enum TaskSentiment: String, Codable, CaseIterable {
    case energizing = "Energizing"
    case neutral = "Neutral"
    case draining = "Draining"
    
    var emoji: String {
        switch self {
        case .energizing: return "😊"
        case .neutral: return "😐"
        case .draining: return "😓"
        }
    }
    
    var color: String {
        switch self {
        case .energizing: return "green"
        case .neutral: return "gray"
        case .draining: return "orange"
        }
    }
}

// MARK: - Actual Time (Post-Completion)
enum ActualTime: String, Codable, CaseIterable {
    case veryShort = "< 15 min"
    case short = "15-30 min"
    case medium = "30-60 min"
    case long = "1-2 hrs"
    case veryLong = "2+ hrs"
    
    var emoji: String {
        switch self {
        case .veryShort: return "⚡"
        case .short: return "⏱️"
        case .medium: return "⏰"
        case .long: return "🕐"
        case .veryLong: return "📅"
        }
    }
    
    var midpointMinutes: Double {
        switch self {
        case .veryShort: return 7.5  // < 15 min
        case .short: return 22.5     // 15-30 min
        case .medium: return 45      // 30-60 min
        case .long: return 90        // 1-2 hrs
        case .veryLong: return 150   // 2+ hrs (estimate 2.5 hrs)
        }
    }
}

// MARK: - Time Source (Data Confidence)
enum TimeSource: String, Codable {
    case focusTimer = "Focus Timer"      // Highest confidence: measured
    case userReported = "User Reported"  // High confidence: user input
    case estimated = "Estimated"         // Low confidence: completion - creation time
    
    var confidence: Double {
        switch self {
        case .focusTimer: return 1.0
        case .userReported: return 0.8
        case .estimated: return 0.3
        }
    }
}
