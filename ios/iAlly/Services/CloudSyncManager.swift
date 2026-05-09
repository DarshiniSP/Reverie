// CloudSyncManager.swift
// iAlly
//
// Real-time iCloud sync monitoring using NSPersistentCloudKitContainer events.
// SwiftData's automatic CloudKit sync fires .import / .export / .setup events
// that this manager observes and surfaces to the UI.
//
// Usage:
//   - Call startMonitoring() once after ModelContainer is created (iAllyApp.swift)
//   - SettingsView observes @Published properties for live status display

import Foundation
import SwiftUI
import Network
import CoreData
import Combine

@MainActor
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    // MARK: - Published State

    @Published var syncStatus: SyncStatus = .idle
    @Published var isNetworkAvailable = true
    @Published var lastImportDate: Date?       // Last successful import (CloudKit → device)
    @Published var lastExportDate: Date?       // Last successful export (device → CloudKit)
    @Published var lastError: String?          // Most recent error message
    @Published var importCount: Int = 0        // Session import event count
    @Published var exportCount: Int = 0        // Session export event count

    // MARK: - Sync Status

    enum SyncStatus: Equatable {
        case idle              // No active sync
        case importing         // CloudKit → device (restore / download)
        case exporting         // Device → CloudKit (upload)
        case setup             // Initial CloudKit schema setup
        case synced            // Last sync completed successfully
        case error(String)     // Last sync failed
        case disabled          // CloudKit feature flag is off

        var displayText: String {
            switch self {
            case .idle:             return "iCloud Sync Active"
            case .importing:        return "Restoring from iCloud..."
            case .exporting:        return "Syncing to iCloud..."
            case .setup:            return "Setting up iCloud..."
            case .synced:           return "Synced with iCloud"
            case .error(let msg):   return "Sync Error: \(msg)"
            case .disabled:         return "iCloud Sync Disabled"
            }
        }

        var icon: String {
            switch self {
            case .idle:       return "icloud"
            case .importing:  return "icloud.and.arrow.down"
            case .exporting:  return "icloud.and.arrow.up"
            case .setup:      return "arrow.triangle.2.circlepath.icloud"
            case .synced:     return "checkmark.icloud"
            case .error:      return "exclamationmark.icloud"
            case .disabled:   return "icloud.slash"
            }
        }

        var color: Color {
            switch self {
            case .idle:       return .blue
            case .importing:  return .orange
            case .exporting:  return .orange
            case .setup:      return .orange
            case .synced:     return DSColors.success
            case .error:      return DSColors.error
            case .disabled:   return DSColors.textTertiary
            }
        }
    }

    // MARK: - Private

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "CloudSyncManager.network")
    private var eventObserver: NSObjectProtocol?
    private var idleResetTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        startNetworkMonitoring()
    }

    // MARK: - Public API

    /// Call once after ModelContainer is created. Subscribes to real CloudKit sync events.
    func startMonitoring() {
        guard FeatureFlags.cloudKitEnabled else {
            syncStatus = .disabled
            return
        }

        // Already monitoring
        guard eventObserver == nil else { return }

        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract event on the callback queue to avoid Sendable issues
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }
            let eventSnapshot = CloudKitEventSnapshot(event: event)
            Task { @MainActor [weak self] in
                self?.handleCloudKitEvent(eventSnapshot)
            }
        }

#if DEBUG
        print("[CloudSync] Monitoring started — listening for CloudKit events")
#endif
    }

    /// Dismisses the current error state.
    func dismissError() {
        if case .error = syncStatus {
            lastError = nil
            syncStatus = .idle
        }
    }

    // MARK: - CloudKit Event Handling

    private func handleCloudKitEvent(_ snapshot: CloudKitEventSnapshot) {
#if DEBUG
        let status = snapshot.endDate == nil ? "started" : (snapshot.succeeded ? "succeeded" : "failed")
        print("[CloudSync] Event: \(snapshot.typeName) \(status)")
#endif

        if snapshot.endDate == nil {
            // Event in progress
            idleResetTask?.cancel()
            switch snapshot.type {
            case .import: syncStatus = .importing
            case .export: syncStatus = .exporting
            case .setup:  syncStatus = .setup
            @unknown default: break
            }
        } else {
            // Event completed
            if snapshot.succeeded {
                switch snapshot.type {
                case .import:
                    lastImportDate = snapshot.endDate
                    importCount += 1
                case .export:
                    lastExportDate = snapshot.endDate
                    exportCount += 1
                case .setup:
                    break
                @unknown default:
                    break
                }
                syncStatus = .synced
                scheduleIdleReset()
            } else if let errorMessage = snapshot.errorMessage {
                lastError = errorMessage
                syncStatus = .error(errorMessage)
#if DEBUG
                print("[CloudSync] Error: \(errorMessage)")
#endif
            }
        }
    }

    // MARK: - Helpers

    /// Resets status to .idle after a brief display of .synced.
    private func scheduleIdleReset() {
        idleResetTask?.cancel()
        idleResetTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if case .synced = syncStatus {
                syncStatus = .idle
            }
        }
    }

    /// Converts CloudKit errors into user-friendly messages.
    static func friendlyErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        // CKErrorDomain common codes
        switch nsError.code {
        case 1:  return "iCloud account not available"       // CKError.internalError
        case 6:  return "Not signed in to iCloud"            // CKError.notAuthenticated
        case 9:  return "iCloud storage full"                // CKError.quotaExceeded
        case 14: return "Network unavailable"                // CKError.networkUnavailable
        case 15: return "Network failure"                    // CKError.networkFailure
        case 26: return "iCloud account changed"             // CKError.changeTokenExpired
        default: return error.localizedDescription
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    deinit {
        networkMonitor.cancel()
        if let observer = eventObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Sendable CloudKit Event Snapshot

/// Captures the essential data from an NSPersistentCloudKitContainer.Event
/// so it can be safely transferred across concurrency boundaries.
struct CloudKitEventSnapshot: Sendable {
    let type: NSPersistentCloudKitContainer.EventType
    let succeeded: Bool
    let endDate: Date?
    let errorMessage: String?
    let typeName: String

    init(event: NSPersistentCloudKitContainer.Event) {
        self.type = event.type
        self.succeeded = event.succeeded
        self.endDate = event.endDate
        self.errorMessage = event.error.map {
            CloudSyncManager.friendlyErrorMessage($0)
        }
        switch event.type {
        case .setup:  self.typeName = "setup"
        case .import: self.typeName = "import"
        case .export: self.typeName = "export"
        @unknown default: self.typeName = "unknown"
        }
    }
}
