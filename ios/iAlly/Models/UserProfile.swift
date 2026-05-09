//
//  UserProfile.swift
//  iAlly
//
//  Lightweight Codable struct backed by UserDefaults. Not a SwiftData @Model because
//  the profile is a single global value, not a collection of records.
//
//  Tier 1 (name, timezone, communicationStyle, currentFocus) — always injected.
//  Tier 2 — auto-derived from SwiftData (Journeys, Plans, Routines) via ProfileContextBuilder.
//  Tier 3 (healthNotes) — never auto-injected, stored on device only.
//

import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var timezone: String = TimeZone.current.identifier
    var updatedAt: Date = Date()

    // MARK: - Tier 1 — always injected (~60 tokens)
    var communicationStyle: String = ""  // e.g. "brief and direct"
    var currentFocus: String = ""        // e.g. "iAlly launch by June"

    // MARK: - Tier 3 — NEVER auto-injected, stored on device only
    var healthNotes: String = ""             // User pastes into Lumina manually if relevant

    // Legacy fields — kept for Codable backward compatibility (ignored in new code)
    var occupation: String = ""
    var primaryGoal: String = ""
    var lifeFocus: [String] = []
    var workContext: String = ""
    var familyContext: String = ""
    var schedulingConstraints: String = ""

    // MARK: - Persistence (UserDefaults)

    static let defaultsKey = "ially.userProfile"

    static var current: UserProfile {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: defaultsKey),
                let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
            else { return UserProfile() }
            return profile
        }
        set {
            var updated = newValue
            updated.updatedAt = Date()
            if let data = try? JSONEncoder().encode(updated) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
    }

    // MARK: - Derived Helpers

    /// True once the user has at minimum provided their name.
    var isComplete: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Tier 1 context (always sent, ~60 tokens)

    /// Compact context always injected into every Lumina call.
    /// Excludes sensitive or domain-specific data — those go in tier2Context.
    var tier1Context: String {
        guard isComplete else { return "" }
        var parts = ["The user's name is \(name)."]
        parts.append("Timezone: \(timezone).")
        if !communicationStyle.isEmpty {
            parts.append("Communication style: \(communicationStyle).")
        }
        if !currentFocus.isEmpty {
            parts.append("Current focus: \(currentFocus).")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Backward-compatibility alias

    /// Delegates to tier1Context. Retained so existing callers compile without changes.
    var luminaContext: String { tier1Context }
}
