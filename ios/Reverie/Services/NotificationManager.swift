//
//  NotificationManager.swift
//  iAlly
//
//  Created on 8/12/2025.
//

import Foundation
import UserNotifications
import SwiftData
import Combine

@MainActor
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    // Notification Categories
    enum NotificationType: String {
        case taskDue = "TASK_DUE"
        case taskOverdue = "TASK_OVERDUE"
        case milestoneDue = "MILESTONE_DUE"
        case focusComplete = "FOCUS_COMPLETE"
        case dailyReview = "DAILY_REVIEW"
        case timeBlockReminder = "TIME_BLOCK_REMINDER"
        // Phase 3: Proactive Intelligence
        case luminaNudge = "LUMINA_NUDGE"
        // P1-D: Context-aware smart notifications
        case streakRisk = "STREAK_RISK"
        case journeyDrift = "JOURNEY_DRIFT"
    }
    
    // Notification Actions
    enum NotificationAction: String {
        case complete = "COMPLETE_ACTION"
        case snooze = "SNOOZE_ACTION"
        case view = "VIEW_ACTION"
    }
    
    private override init() {
        super.init()
        // Set self as delegate to handle foreground notifications
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            UNUserNotificationCenter.current().delegate = self
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // This allows notifications to show as banners even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show banner, play sound, and update badge even when app is open
        return [.banner, .sound, .badge]
    }
    
    // Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        _ = response.notification.request.identifier
        
        // Handle action responses here (e.g., complete task, snooze, view)
        switch actionIdentifier {
        case NotificationAction.complete.rawValue:
            break
        case NotificationAction.snooze.rawValue:
            break
        case NotificationAction.view.rawValue, UNNotificationDefaultActionIdentifier:
            break
        default:
            break
        }
    }
    
    // MARK: - Permission Management
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await checkAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Setup
    
    func setupNotificationCategories() {
        let completeAction = UNNotificationAction(
            identifier: NotificationAction.complete.rawValue,
            title: "Complete",
            options: [.foreground]
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: NotificationAction.snooze.rawValue,
            title: "Snooze 1 hour",
            options: []
        )
        
        let viewAction = UNNotificationAction(
            identifier: NotificationAction.view.rawValue,
            title: "View",
            options: [.foreground]
        )
        
        // Task categories
        let taskCategory = UNNotificationCategory(
            identifier: NotificationType.taskDue.rawValue,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        let overdueCategory = UNNotificationCategory(
            identifier: NotificationType.taskOverdue.rawValue,
            actions: [completeAction, viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let milestoneCategory = UNNotificationCategory(
            identifier: NotificationType.milestoneDue.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let focusCategory = UNNotificationCategory(
            identifier: NotificationType.focusComplete.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let reviewCategory = UNNotificationCategory(
            identifier: NotificationType.dailyReview.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        let timeBlockCategory = UNNotificationCategory(
            identifier: NotificationType.timeBlockReminder.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Phase 3: Lumina nudge category
        let luminaCategory = UNNotificationCategory(
            identifier: NotificationType.luminaNudge.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        // P1-D: Streak risk category
        let streakRiskCategory = UNNotificationCategory(
            identifier: NotificationType.streakRisk.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        // P1-D: Journey drift category
        let journeyDriftCategory = UNNotificationCategory(
            identifier: NotificationType.journeyDrift.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            taskCategory,
            overdueCategory,
            milestoneCategory,
            focusCategory,
            reviewCategory,
            timeBlockCategory,
            luminaCategory,
            streakRiskCategory,
            journeyDriftCategory
        ])
    }

    // MARK: - Phase 3: Lumina Proactive Nudge Notifications

    /// Deliver a rich system notification for a high-urgency Lumina nudge.
    func deliverLuminaNudge(_ nudge: LuminaNudge) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Lumina · \(nudge.title)"
        content.body = nudge.body
        content.sound = .default
        content.categoryIdentifier = NotificationType.luminaNudge.rawValue
        content.userInfo = [
            "nudgeId": nudge.id.uuidString,
            "nudgeType": nudge.type.rawValue,
            "type": NotificationType.luminaNudge.rawValue
        ]

        // Fire immediately (for proactive nudges generated on schedule)
        let request = UNNotificationRequest(
            identifier: "lumina-nudge-\(nudge.id.uuidString)",
            content: content,
            trigger: nil // immediate delivery
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Task Notifications
    
    /// Schedule notification for task due date using user's preferred reminder time
    /// Phase 1: Uses global default time from Settings
    /// Phase 2: Will support per-task custom reminder times (see PHASE_2_FEATURES.md)
    func scheduleTaskDueNotification(taskId: String, taskTitle: String, dueDate: Date) async {
        guard isAuthorized else { return }
        
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        
        // Check if the due date has a specific time (not 00:00:00)
        // If user set a specific time, use it. Otherwise use preference.
        let hasSpecificTime = components.hour != 0 || components.minute != 0
        
        if !hasSpecificTime {
            // Read user preference for reminder time (default 9 AM if not set)
            let reminderHour = UserDefaults.standard.double(forKey: "reminderTime")
            let hour = reminderHour > 0 ? Int(reminderHour) : 9
            components.hour = hour
            components.minute = 0
        }
        
        // P1-D: Context-aware copy — use the actual task title as the headline,
        // and add a supportive sub-line rather than a generic "Task Due Today".
        let content = UNMutableNotificationContent()
        content.title = taskTitle
        content.body = hasSpecificTime
            ? "Due at \(formatShortTime(from: dueDate)) — tap to mark complete."
            : "On your list for today — give it the attention it deserves."
        content.sound = .default
        content.categoryIdentifier = NotificationType.taskDue.rawValue
        content.userInfo = ["taskId": taskId, "type": NotificationType.taskDue.rawValue]
        
        // Trigger at the specific time
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "task-due-\(taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            if FeatureFlags.debugMode {
            print("🔔 Scheduled notification for '\(taskTitle)' at \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        } catch {
            if FeatureFlags.debugMode {
            print("❌ Failed to schedule notification: \(error)")
            }
        }
    }
    
    func scheduleOverdueReminder(taskId: String, taskTitle: String) async {
        guard isAuthorized else { return }
        
        // Read user preference for reminder time (default 9 AM)
        let reminderHour = UserDefaults.standard.double(forKey: "reminderTime")
        let hour = reminderHour > 0 ? Int(reminderHour) : 9
        
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Overdue Task"
        content.body = taskTitle
        content.sound = .default
        content.categoryIdentifier = NotificationType.taskOverdue.rawValue
        content.userInfo = ["taskId": taskId, "type": NotificationType.taskOverdue.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "task-overdue-\(taskId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently fail - notification scheduling is not critical
        }
    }
    
    // MARK: - Milestone Notifications
    
    func scheduleMilestoneReminder(milestoneId: String, milestoneTitle: String, targetDate: Date, journeyTitle: String) async {
        guard isAuthorized else { return }
        
        // Notify 3 days before milestone due date
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: targetDate) else { return }
        
        var components = Calendar.current.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 18 // 6 PM
        components.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Milestone Approaching"
        content.body = "\(milestoneTitle) in \(journeyTitle) is due in 3 days"
        content.sound = .default
        content.categoryIdentifier = NotificationType.milestoneDue.rawValue
        content.userInfo = ["milestoneId": milestoneId, "type": NotificationType.milestoneDue.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "milestone-due-\(milestoneId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently fail - notification scheduling is not critical
        }
    }
    
    // MARK: - Focus Session Notifications
    
    func scheduleFocusCompleteNotification(sessionId: String, taskTitle: String?, duration: Int) async {
        guard isAuthorized else { return }
        
        // Immediate notification when focus session completes
        let content = UNMutableNotificationContent()
        content.title = "Focus Session Complete! 🎉"
        if let taskTitle = taskTitle {
            content.body = "Great work on \(taskTitle)! (\(duration) minutes)"
        } else {
            content.body = "Great work! (\(duration) minutes)"
        }
        content.sound = .default
        content.categoryIdentifier = NotificationType.focusComplete.rawValue
        content.userInfo = ["sessionId": sessionId, "type": NotificationType.focusComplete.rawValue]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "focus-complete-\(sessionId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently fail - notification scheduling is not critical
        }
    }
    
    // MARK: - Daily Review Notification
    
    func scheduleDailyReviewReminder() async {
        guard isAuthorized else { return }
        
        // Read user preference for review time (default 8 PM)
        let reviewHour = UserDefaults.standard.double(forKey: "reviewTime")
        let hour = reviewHour > 0 ? Int(reviewHour) : 20
        
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        
        let content = UNMutableNotificationContent()
        content.title = "Time for Reflection"
        content.body = "Review your progress and plan for tomorrow"
        content.sound = .default
        content.categoryIdentifier = NotificationType.dailyReview.rawValue
        content.userInfo = ["type": NotificationType.dailyReview.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-review",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently fail - notification scheduling is not critical
        }
    }
    
    // MARK: - Weekly Resilience Report Notification

    /// Schedule a recurring Sunday-evening prompt to view the weekly Resilience report.
    /// Fires every Sunday at 7 PM. Safe to call multiple times — deduped by identifier.
    func scheduleWeeklyResilienceReport() async {
        guard isAuthorized else { return }

        var components = DateComponents()
        components.weekday = 1  // Sunday (1 = Sunday in Gregorian calendar)
        components.hour = 19    // 7 PM
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Weekly Resilience Report"
        content.body = "How did your week go? Check your Resilience Index and see your progress."
        content.sound = .default
        content.userInfo = ["type": "weeklyResilienceReport", "tabIndex": 3]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "weekly-resilience-report",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Silently fail — notification scheduling is not critical
        }
    }

    func cancelWeeklyResilienceReport() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly-resilience-report"]
        )
    }

    // MARK: - Time Block Notifications

    /// Schedule notification for scheduled task (time block)
    /// Notifies 5 minutes before the scheduled start time
    func scheduleTimeBlockNotification(timeBlockId: String, taskTitle: String, startTime: Date) async {
        guard isAuthorized else { return }
        
        // Schedule notification 5 minutes before start time
        guard let notificationTime = Calendar.current.date(byAdding: .minute, value: -5, to: startTime) else { return }
        
        // Don't schedule if notification time is in the past
        guard notificationTime > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
        
        let content = UNMutableNotificationContent()
        content.title = "Scheduled Task Starting Soon"
        content.body = "\(taskTitle) starts in 5 minutes"
        content.sound = .default
        content.categoryIdentifier = NotificationType.timeBlockReminder.rawValue
        content.userInfo = ["timeBlockId": timeBlockId, "type": NotificationType.timeBlockReminder.rawValue]
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "timeblock-\(timeBlockId)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            if FeatureFlags.debugMode {
            print("🔔 Scheduled time block notification for '\(taskTitle)' at \(notificationTime.formatted(date: .omitted, time: .shortened))")
            }
        } catch {
            if FeatureFlags.debugMode {
            print("❌ Failed to schedule time block notification: \(error)")
            }
        }
    }
    
    func cancelTimeBlockNotification(timeBlockId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["timeblock-\(timeBlockId)"]
        )
    }
    
    // MARK: - Cancel Notifications
    
    func cancelTaskNotifications(taskId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "task-due-\(taskId)",
                "task-overdue-\(taskId)"
            ]
        )
    }
    
    func cancelMilestoneNotification(milestoneId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["milestone-due-\(milestoneId)"]
        )
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - P1-D / P2-E: Streak Risk Notifications

    /// Notify the user that a streak they care about is at risk if they don't act today.
    /// P2-E: Fires at 8 PM with streak-length-scaled copy (only for streaks > 3).
    /// Only call this when the routine has NOT been completed today — caller is responsible
    /// for checking `lastCompletedDate` before scheduling.
    /// - Parameters:
    ///   - routineId: Stable identifier for the routine (used as notification ID)
    ///   - routineName: Display name of the routine
    ///   - currentStreak: Number of consecutive days the routine has been completed
    func scheduleStreakRiskNotification(routineId: String, routineName: String, currentStreak: Int) async {
        guard isAuthorized, currentStreak > 3 else { return }

        var components = DateComponents()
        components.hour = 20   // 8 PM — P2-E: moved from 7pm
        components.minute = 0

        // P2-E: Scale notification copy to streak milestone
        let title: String
        let body: String
        switch currentStreak {
        case _ where currentStreak > 30:
            title = "💪 Legendary Streak!"
            body  = "\(currentStreak)-day streak on '\(routineName)'. Don't stop now."
        case _ where currentStreak > 14:
            title = "🏆 Real Habit Alert"
            body  = "\(currentStreak) days on '\(routineName)' — this is a real habit now. Keep it alive."
        case _ where currentStreak > 7:
            title = "🔥 Streak Milestone"
            body  = "Don't break your \(currentStreak)-day streak on '\(routineName)'. You've got this."
        default: // > 3
            title = "🔥 Streak at Risk"
            body  = "\(currentStreak)-day streak on '\(routineName)' — still time tonight."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = NotificationType.streakRisk.rawValue
        content.userInfo = [
            "routineId": routineId,
            "type": NotificationType.streakRisk.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-risk-\(routineId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelStreakRiskNotification(routineId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["streak-risk-\(routineId)"]
        )
    }

    // MARK: - P1-D: Journey Drift Notifications

    /// Notify when a journey has stalled (< 10% progress, target date within 60 days).
    /// Fires at 9 AM on the day after the journey is detected as drifting.
    /// - Parameters:
    ///   - journeyId: Stable identifier for the journey
    ///   - journeyName: Display name of the journey
    ///   - progressPercent: 0–100 integer representation of current progress
    ///   - daysRemaining: Days until the journey target date
    func scheduleJourneyDriftNotification(
        journeyId: String,
        journeyName: String,
        progressPercent: Int,
        daysRemaining: Int
    ) async {
        guard isAuthorized else { return }

        // Only notify for genuinely drifting journeys to avoid noise
        guard progressPercent < 15, daysRemaining > 0, daysRemaining < 60 else { return }

        let fireDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour = 9
        components.minute = 0

        let urgencyPrefix = daysRemaining <= 14 ? "⚠️ " : ""
        let content = UNMutableNotificationContent()
        content.title = "\(urgencyPrefix)'\(journeyName)' needs momentum"
        content.body = "\(progressPercent)% progress with \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") remaining. What's one task you can do today?"
        content.sound = .default
        content.categoryIdentifier = NotificationType.journeyDrift.rawValue
        content.userInfo = [
            "journeyId": journeyId,
            "type": NotificationType.journeyDrift.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "journey-drift-\(journeyId)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelJourneyDriftNotification(journeyId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["journey-drift-\(journeyId)"]
        )
    }

    // MARK: - P2-B: Journey Health Notifications (drift + deadline proximity)

    /// Schedule a journey health notification with named threshold copy.
    /// Uses a stable identifier per journey+type so duplicate requests are overwritten.
    /// - Parameters:
    ///   - journeyId: Journey UUID string
    ///   - journeyName: Journey display title
    ///   - type: "drift_7" | "drift_14" | "drift_30" | "deadline_30" | "deadline_14" | "deadline_7"
    ///   - progress: 0-100 integer
    ///   - daysUntilDeadline: nil for drift notifications
    func scheduleJourneyHealthNotification(
        journeyId: String,
        journeyName: String,
        type: String,
        progress: Int,
        daysUntilDeadline: Int? = nil
    ) async {
        guard isAuthorized else { return }

        // Fire at 10 AM next morning
        let fireDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: fireDate)
        components.hour   = 10
        components.minute = 0

        let (title, body): (String, String)
        switch type {
        case "drift_7":
            title = "📍 '\(journeyName)' needs momentum"
            body  = "No activity this week on '\(journeyName)'. What's one task you can do today?"
        case "drift_14":
            title = "⚠️ '\(journeyName)' is stalling"
            body  = "Last activity was 2 weeks ago on '\(journeyName)'. It's time to get back on track."
        case "drift_30":
            title = "🚨 '\(journeyName)' has been dormant"
            body  = "'\(journeyName)' has had no activity for a month. Is this journey still relevant to you?"
        case "deadline_30":
            title = "📅 '\(journeyName)' target in 30 days"
            body  = "You're \(progress)% done with 30 days remaining. Stay consistent to reach your goal."
        case "deadline_14":
            title = "⚠️ '\(journeyName)' due in 2 weeks"
            body  = "'\(journeyName)' is due in 2 weeks — you're \(progress)% done. Time to accelerate."
        case "deadline_7":
            title = "🚨 One week left on '\(journeyName)'"
            body  = "'\(journeyName)' is due in 7 days at \(progress)% complete. What needs to happen now?"
        default:
            title = "'\(journeyName)' needs attention"
            body  = "\(progress)% progress with \(daysUntilDeadline.map { "\($0) days" } ?? "an approaching deadline") remaining."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        content.categoryIdentifier = NotificationType.journeyDrift.rawValue
        content.userInfo = [
            "journeyId": journeyId,
            "alertType": type,
            "type": NotificationType.journeyDrift.rawValue
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "journey-health-\(journeyId)-\(type)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private Helpers

    private func formatShortTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Debug

    func getPendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}
