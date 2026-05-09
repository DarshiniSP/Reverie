//
//  AppConstants.swift
//  iAlly
//
//  Created on 11/12/2025.
//
//  Central configuration for all app constants, magic numbers, and settings
//

import Foundation

// MARK: - App Configuration
struct AppConfig {
    /// App bundle identifier
    static let bundleIdentifier = "Irigam-Innovations.iAlly"
    
    /// App group identifier for data sharing between app and widgets
    static let appGroupIdentifier = "group.Irigam-Innovations.iAlly"
    
    /// App name for display
    static let appName = "iAlly"
    
    /// App version (read from Info.plist)
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Build number (read from Info.plist)
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - UI Constants
struct UIConstants {
    // MARK: - Spacing
    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 24
        static let huge: CGFloat = 32
        static let massive: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 6
        static let standard: CGFloat = 8
        static let medium: CGFloat = 10
        static let large: CGFloat = 12
        static let extraLarge: CGFloat = 16
        static let round: CGFloat = 20
    }
    
    // MARK: - Icon Sizes
    struct IconSize {
        static let tiny: CGFloat = 12
        static let small: CGFloat = 16
        static let standard: CGFloat = 20
        static let medium: CGFloat = 24
        static let large: CGFloat = 32
        static let extraLarge: CGFloat = 40
        static let huge: CGFloat = 48
        static let massive: CGFloat = 64
    }
    
    // MARK: - Opacity Values
    struct Opacity {
        static let subtle: Double = 0.1
        static let light: Double = 0.15
        static let medium: Double = 0.2
        static let standard: Double = 0.3
        static let visible: Double = 0.5
        static let strong: Double = 0.6
        static let prominent: Double = 0.8
    }
    
    // MARK: - Border Width
    struct BorderWidth {
        static let thin: CGFloat = 0.5
        static let standard: CGFloat = 1
        static let medium: CGFloat = 1.5
        static let thick: CGFloat = 2
        static let bold: CGFloat = 3
    }
    
    // MARK: - Animation Duration
    struct Animation {
        static let fast: Double = 0.2
        static let standard: Double = 0.3
        static let slow: Double = 0.5
        static let verySlow: Double = 0.8
    }
}

// MARK: - Tag Constants
struct TagConstants {
    /// Tag badge background opacity
    static let badgeOpacity = UIConstants.Opacity.light
    
    /// Tag icon size in badges
    static let badgeIconSize: CGFloat = 8
    
    /// Tag text size in badges
    static let badgeTextSize: CGFloat = 10
    
    /// Tag badge corner radius
    static let badgeCornerRadius = UIConstants.CornerRadius.standard
    
    /// Tag badge horizontal padding
    static let badgePaddingHorizontal: CGFloat = 6
    
    /// Tag badge vertical padding
    static let badgePaddingVertical: CGFloat = 3
    
    /// Tag row icon size
    static let rowIconSize = UIConstants.IconSize.standard
    
    /// Tag selection border width
    static let selectionBorderWidth = UIConstants.BorderWidth.thick
}

// MARK: - Search Constants
struct SearchConstants {
    /// Minimum characters before searching
    static let minimumSearchLength = 0 // Search starts immediately
    
    /// Number of search results to show per category
    static let resultsPerCategory = 50
    
    /// Search debounce delay (seconds)
    static let debounceDelay: Double = 0.3
}

// MARK: - Task Constants
struct TaskConstants {
    /// Maximum title length
    static let maxTitleLength = 200
    
    /// Maximum detail length
    static let maxDetailLength = 1000
    
    /// Default task size
    static let defaultSize = TaskSize.medium
    
    /// Task row icon size
    static let rowIconSize: CGFloat = 20
    
    /// Task row padding
    static let rowPadding = UIConstants.Spacing.medium
    
    /// Task row corner radius
    static let rowCornerRadius = UIConstants.CornerRadius.standard
}

// MARK: - Timing Constants
struct TimingConstants {
    /// Animation standard duration
    static let standardAnimation: Double = 0.3

    /// Toast display duration
    static let toastDuration: Double = 2.0

    /// Auto-dismiss delay for success messages
    static let successMessageDuration: Double = 1.5
}

// MARK: - Feature Flags
struct FeatureFlags {
    /// Enable CloudKit sync (set to .none for widget testing)
    static let cloudKitEnabled = true
    
    /// Enable growth insights
    static let insightsEnabled = true
    
    /// Enable focus mode
    static let focusModeEnabled = true
    
    /// Enable journey milestones
    static let milestonesEnabled = true
    
    /// Enable routine templates
    static let routineTemplatesEnabled = true
    
    /// Enable natural language processing
    static let nlpEnabled = true
    
    /// Enable Siri shortcuts
    static let siriShortcutsEnabled = true
    
    /// Enable tag filtering
    static let tagFilteringEnabled = true
    
    /// Enable search
    static let searchEnabled = true

    // Phase 2: Lumina Knowledge Layer
    /// Enable Lumina knowledge capture and PAI memory
    static let luminaKnowledgeEnabled = true

    // Phase 3: Proactive Intelligence
    /// Enable background proactive intelligence engine (BGAppRefreshTask)
    static let proactiveIntelligenceEnabled = true

    /// Enable daily Lumina briefing card in Today view
    static let dailyBriefingEnabled = true

    /// Enable journey narrative view ("Ask Lumina" about a journey)
    static let journeyNarrativeEnabled = true

    /// Enable Life Pulse PAI narrative in Analytics dashboard
    static let lifePulseEnabled = true

    /// Debug mode (shows additional logging)
    static let debugMode = false
}

// MARK: - Notification Constants
struct NotificationConstants {
    /// Daily review reminder identifier
    static let dailyReviewId = "daily-review"
    
    /// Task reminder prefix
    static let taskReminderPrefix = "task-reminder-"
    
    /// Routine reminder prefix
    static let routineReminderPrefix = "routine-reminder-"
    
    /// Default review time (hour)
    static let defaultReviewHour = 20 // 8 PM
    
    /// Default review time (minute)
    static let defaultReviewMinute = 0
}

// MARK: - URL Schemes
struct URLSchemes {
    /// App URL scheme
    static let appScheme = "iAlly"
    
    /// Deep link paths
    struct DeepLink {
        static let today = "today"
        static let inbox = "inbox"
        static let plans = "plans"
        static let journeys = "journeys"
        static let focus = "focus"
        static let taskCreated = "task/created"
    }
}

// MARK: - Data Limits
struct DataLimits {
    /// Maximum tags per task
    static let maxTagsPerTask = 10
    
    /// Maximum milestones per journey
    static let maxMilestonesPerJourney = 20
    
    /// Maximum tasks per milestone
    static let maxTasksPerMilestone = 50
    
    /// Maximum routines
    static let maxRoutines = 100
    
    /// Maximum plans (one per life domain)
    static let maxPlans = LifeDomain.allCases.count
}

// MARK: - Default Values
struct Defaults {
    /// Default tags to create on first launch
    static let defaultTags = [
        ("Work", "#4C8BF5", "briefcase.fill"),
        ("Personal", "#51CF66", "person.fill"),
        ("Urgent", "#FF6B6B", "exclamationmark.triangle.fill"),
        ("Important", "#FFD43B", "star.fill"),
        ("Health", "#20C997", "heart.fill"),
        ("Learning", "#9775FA", "book.fill")
    ]
    
    /// Default life domains
    static let lifeDomains = LifeDomain.allCases
}
