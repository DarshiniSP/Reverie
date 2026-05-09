//
//  AppDelegate.swift
//  iAlly
//
//  P4-A: UIApplicationDelegate that handles APNs device token registration
//  and incoming silent push notifications.
//
//  Integrated via @UIApplicationDelegateAdaptor in iAllyApp.swift.
//

import UIKit
import SwiftData

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - APNs Token Registration (P4-A)

    /// Called when iOS successfully registers for remote notifications.
    /// Token stored locally for future use.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(tokenString, forKey: "apns.deviceToken")
    }

    /// Called when APNs registration fails (e.g. simulator without push entitlement).
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
#if DEBUG
        print("⚠️ APNs registration failed: \(error.localizedDescription)")
#endif
    }

    // MARK: - Silent Push (P4-A)

    /// Handles content-available: 1 silent pushes from PAIService.
    /// Wakes the app in background, runs the intelligence cycle, then completes.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Guard: only process PAI-sourced silent pushes
        guard let container = ProactiveIntelligenceEngine.shared.modelContainer else {
            completionHandler(.noData)
            return
        }

        SilentPushHandler.shared.handleSilentPush(
            userInfo: userInfo,
            container: container,
            completionHandler: completionHandler
        )
    }
}
