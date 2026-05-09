//
//  FocusLiveActivity.swift
//  iAlly
//
//  P4-B: ActivityKit Live Activity and Dynamic Island integration for Focus Sessions.
//
//  The Live Activity shows:
//    • Compact Dynamic Island: 🎯 Focus · MM:SS remaining
//    • Expanded Dynamic Island: task title, circular progress ring, time remaining
//    • Lock screen banner: task title + progress bar + time left
//
//  Usage:
//    FocusLiveActivityManager.shared.startLiveActivity(taskTitle:durationSeconds:)
//    FocusLiveActivityManager.shared.updateLiveActivity(timeRemainingSeconds:)
//    FocusLiveActivityManager.shared.endLiveActivity()
//

import Foundation
import ActivityKit
import SwiftUI

// MARK: - Activity Attributes (P4-B)

/// Describes the static attributes of a Focus Session Live Activity.
/// `ContentState` holds the mutable UI state that can be pushed via APNs.
struct FocusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Current task being focused on.
        var taskTitle: String
        /// Seconds remaining in the session.
        var timeRemainingSeconds: Int
        /// Total session duration in seconds (used to compute progress).
        var totalDurationSeconds: Int

        /// Fraction of session elapsed (0 → 1).
        var progressFraction: Double {
            guard totalDurationSeconds > 0 else { return 0 }
            return 1.0 - Double(timeRemainingSeconds) / Double(totalDurationSeconds)
        }

        /// Human-readable "MM:SS" countdown string.
        var timeString: String {
            let m = timeRemainingSeconds / 60
            let s = timeRemainingSeconds % 60
            return String(format: "%02d:%02d", m, s)
        }
    }

    /// Stable identifier for the session (created once, stays constant).
    var sessionId: String
}

// MARK: - Live Activity Manager (P4-B)

/// Manages the lifecycle of the Focus Session Live Activity.
/// Gracefully no-ops when Live Activities are unavailable (simulator / older iOS).
@MainActor
final class FocusLiveActivityManager {

    static let shared = FocusLiveActivityManager()
    private init() {}

    // Holds the currently running activity, if any.
    private var currentActivity: Activity<FocusActivityAttributes>?

    /// Returns `true` if a Live Activity is currently active.
    var isLiveActivityActive: Bool {
        currentActivity != nil
    }

    // MARK: - Lifecycle

    /// Start a new Focus Live Activity.
    /// Safe to call even if Live Activities are disabled or unsupported.
    func startLiveActivity(taskTitle: String, durationSeconds: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
#if DEBUG
            print("⚠️ FocusLiveActivityManager: Live Activities not enabled on this device/simulator")
#endif
            return
        }

        let attributes = FocusActivityAttributes(sessionId: UUID().uuidString)
        let initialState = FocusActivityAttributes.ContentState(
            taskTitle: taskTitle,
            timeRemainingSeconds: durationSeconds,
            totalDurationSeconds: durationSeconds
        )
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            currentActivity = try Activity<FocusActivityAttributes>.request(
                attributes: attributes,
                content: content
            )
#if DEBUG
            print("🏝️ Focus Live Activity started: \(taskTitle) (\(durationSeconds)s)")
#endif
        } catch {
#if DEBUG
            print("⚠️ FocusLiveActivityManager: failed to start — \(error)")
#endif
        }
    }

    /// Push an updated countdown to the Live Activity.
    func updateLiveActivity(timeRemainingSeconds: Int) {
        guard let activity = currentActivity else { return }
        let updatedState = FocusActivityAttributes.ContentState(
            taskTitle: activity.content.state.taskTitle,
            timeRemainingSeconds: timeRemainingSeconds,
            totalDurationSeconds: activity.content.state.totalDurationSeconds
        )
        Task {
            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
        }
    }

    /// End the Live Activity and dismiss it from the Dynamic Island / Lock Screen.
    func endLiveActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
#if DEBUG
        print("🏝️ Focus Live Activity ended")
#endif
    }
}
