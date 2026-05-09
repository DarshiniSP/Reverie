// ProfileContextBuilder.swift
// iAlly
//
// Auto-derives Tier 2 profile context from SwiftData models (Journeys, Plans, Routines).
// Replaces manual UserProfile Tier 2 fields with freeform summaries generated on-the-fly.
//
// Called by:
//   - LuminaConversationService: builds tier2Context string for system prompt injection
//   - LuminaProfileView: shows read-only preview of what Lumina sees

import Foundation

struct ProfileContextBuilder {

    // MARK: - Goals context (from Journeys)

    /// Freeform summary of the user's active goals derived from their Journeys.
    /// e.g. "Active goals: Launch iAlly (Career, 60% done, target Mar 2026), Run a marathon (Health, 30% done)."
    static func goalsContext(from journeys: [Journey]) -> String {
        let active = journeys
            .filter { $0.status == .inProgress || $0.status == .notStarted }
            .prefix(5)

        guard !active.isEmpty else { return "" }

        let items = active.map { j -> String in
            var parts = ["\(j.title) (\(j.lifeDomain.rawValue)"]
            let pct = Int(j.progress * 100)
            if pct > 0 { parts[0] += ", \(pct)% done" }
            if let target = j.targetDate {
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM yyyy"
                parts[0] += ", target \(fmt.string(from: target))"
            }
            return parts[0] + ")"
        }

        return "Active goals: \(items.joined(separator: ", "))."
    }

    // MARK: - Lifestyle context (from Plans & Routines)

    /// Freeform summary of the user's active plans and routines.
    /// e.g. "Active plans: Home Renovation (Personal, 40% done). Daily routines: Morning Meditation (Health, 15-day streak), Evening Review (Career)."
    static func lifestyleContext(from plans: [Plan], routines: [Routine]) -> String {
        var parts: [String] = []

        // Plans
        let activePlans = plans
            .filter { $0.status == .active }
            .prefix(5)

        if !activePlans.isEmpty {
            let items = activePlans.map { p -> String in
                var desc = "\(p.name) (\(p.lifeDomain.rawValue)"
                let pct = Int(p.completionRate * 100)
                if pct > 0 { desc += ", \(pct)% done" }
                desc += ")"
                return desc
            }
            parts.append("Active plans: \(items.joined(separator: ", ")).")
        }

        // Routines
        let activeRoutines = routines
            .filter { $0.isActive }
            .prefix(5)

        if !activeRoutines.isEmpty {
            let items = activeRoutines.map { r -> String in
                var desc = "\(r.title) (\(r.lifeDomain.rawValue)"
                if r.currentStreak > 0 { desc += ", \(r.currentStreak)-day streak" }
                desc += ")"
                return desc
            }
            parts.append("Routines: \(items.joined(separator: ", ")).")
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Domain-filtered Tier 2 context

    /// Produces the full Tier 2 context string filtered by detected conversation domains.
    /// Only includes relevant sections so the system prompt stays lean (~0-100 tokens).
    static func tier2Context(
        journeys: [Journey],
        plans: [Plan],
        routines: [Routine],
        for domains: Set<ConversationDomain>
    ) -> String {
        var parts: [String] = []

        // Goal context → journey, milestone, plan domains
        let goalDomains: Set<ConversationDomain> = [
            .journeyCreate, .journeyModify, .milestoneCreate, .milestoneModify,
            .planCreate, .planModify
        ]
        if !domains.isDisjoint(with: goalDomains) {
            let goals = goalsContext(from: journeys)
            if !goals.isEmpty { parts.append(goals) }
        }

        // Lifestyle context → task, routine, plan domains
        let lifestyleDomains: Set<ConversationDomain> = [
            .taskCreate, .taskModify, .routineCreate, .routineModify,
            .planCreate, .planModify
        ]
        if !domains.isDisjoint(with: lifestyleDomains) {
            let lifestyle = lifestyleContext(from: plans, routines: routines)
            if !lifestyle.isEmpty { parts.append(lifestyle) }
        }

        return parts.joined(separator: " ")
    }

    // MARK: - Full preview (for LuminaProfileView — all sections, no domain filter)

    /// Returns the complete auto-derived context for display in the profile settings view.
    static func fullPreview(
        journeys: [Journey],
        plans: [Plan],
        routines: [Routine]
    ) -> String {
        var parts: [String] = []

        let goals = goalsContext(from: journeys)
        if !goals.isEmpty { parts.append(goals) }

        let lifestyle = lifestyleContext(from: plans, routines: routines)
        if !lifestyle.isEmpty { parts.append(lifestyle) }

        return parts.joined(separator: "\n\n")
    }
}
