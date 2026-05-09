//
//  SilentPushHandler.swift
//  iAlly
//
//  P4-A: Processes content-available: 1 silent push notifications sent by PAIService.
//
//  Flow:
//    1. PAIService (Mac) runs nightly analysis and detects a pattern.
//    2. Sends a silent APNs push to iOS (content-available: 1).
//    3. iOS wakes the app in the background.
//    4. AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)
//       calls SilentPushHandler.handleSilentPush(…).
//    5. Handler runs ProactiveIntelligenceEngine.runCycle() to generate updated nudges.
//    6. If nudges were produced, a visible notification is delivered.
//

import Foundation
import SwiftData
import UIKit

/// P4-A — Silent push handler.
/// Bridges APNs background wakeup to the local ProactiveIntelligenceEngine cycle.
@MainActor
final class SilentPushHandler {

    static let shared = SilentPushHandler()
    private init() {}

    // MARK: - UserDefaults keys

    /// Date the last silent push was received (displayed in Settings).
    static let lastReceivedAtKey = "silentPush.lastReceivedAt"

    // MARK: - Public

    /// Called by AppDelegate when a silent (content-available: 1) push arrives.
    ///
    /// - Parameters:
    ///   - userInfo: The raw APNs payload.
    ///   - container: Live SwiftData ModelContainer for querying user data.
    ///   - completionHandler: iOS background fetch completion block — must be called.
    func handleSilentPush(
        userInfo: [AnyHashable: Any],
        container: ModelContainer,
        completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
#if DEBUG
        let source = userInfo["source"] as? String ?? "pai"
        print("🔔 SilentPushHandler: silent push received from source=\(source)")
#endif
        // Record receipt so Settings can display "Last sync: …"
        UserDefaults.standard.set(Date(), forKey: Self.lastReceivedAtKey)

        Task { @MainActor in
            // Force-run the intelligence cycle so fresh nudges are generated
            // and surfaced as visible system notifications.
            await ProactiveIntelligenceEngine.shared.runCycle(context: container.mainContext)
            completionHandler(.newData)
        }
    }
}
