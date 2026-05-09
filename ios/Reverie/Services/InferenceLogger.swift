// InferenceLogger.swift
// iAlly
//
// In-memory log of every Lumina inference call.
// Captures the full payload sent to the provider and the raw response received.
// Cleared on app restart — this is a developer debug tool, not persistent storage.

import Foundation

// MARK: - Log Entry

struct InferenceLog: Identifiable {
    let id         = UUID()
    let timestamp  : Date
    let provider   : String           // e.g. "Mercury · mercury-2"
    let userMsg    : String           // last user message (used for list preview)
    let payload    : [PAIChatMessage] // complete messages array sent to the provider
    let response   : String           // full raw response before marker stripping
    let durationMs : Int              // wall-clock time from first byte sent to stream end
    let error      : String?          // non-nil when the call threw an error
}

// MARK: - Logger Singleton

/// Thread-safe (MainActor) store for the last 50 inference call logs.
@Observable
@MainActor
final class InferenceLogger {

    static let shared = InferenceLogger()
    private init() {}

    private(set) var logs: [InferenceLog] = []
    private let maxLogs = 50

    /// Prepend a new log entry, evicting the oldest if over the cap.
    func add(_ log: InferenceLog) {
        logs.insert(log, at: 0)
        if logs.count > maxLogs { logs.removeLast() }
    }

    /// Wipe all stored logs.
    func clear() { logs.removeAll() }
}
