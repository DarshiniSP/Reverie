//
//  JourneyHealthService.swift
//  iAlly
//
//  P2-B: Journey Health Monitor
//  Detects journey drift (inactivity) and deadline proximity, then delivers
//  named push notifications with escalating copy.
//
//  Deduplication: each alert type fires at most once per journey per calendar week.
//  Key format: "journeyAlert_{journeyId}_{type}_{weekKey}"
//  — where type is e.g. "drift_7", "drift_14", "drift_30", "deadline_7", etc.
//
//  Tier 1: purely SwiftData — no PAI required.
//

import Foundation
import SwiftData

@MainActor
final class JourneyHealthService {

    static let shared = JourneyHealthService()
    private init() {}

    // MARK: - Public: Push Notification Scheduling

    /// Schedule journey health push notifications for all active journeys.
    /// Deduplicates per journey+type+week — safe to call on every runCycle.
    func scheduleJourneyHealthNotifications(context: ModelContext) async {
        let nm  = NotificationManager.shared
        guard nm.isAuthorized else { return }

        let journeys = activeJourneys(context: context)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        for journey in journeys {
            let jid      = journey.id.uuidString
            let progress = Int(journey.progress * 100)

            // --- Drift detection — check both tasks and milestones ---
            let lastTaskAct = (journey.tasks ?? [])
                .compactMap { $0.completedAt }.max()
            let lastMilestoneAct = (journey.milestones ?? [])
                .compactMap { $0.completedAt }.max()
            let lastActivity = [lastTaskAct, lastMilestoneAct].compactMap { $0 }.max()

            let daysSinceActivity: Int
            if let last = lastActivity {
                daysSinceActivity = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            } else {
                // No tasks ever completed — measure from journey start date
                daysSinceActivity = cal.dateComponents([.day], from: cal.startOfDay(for: journey.startDate), to: today).day ?? 0
            }

            // Fire the most urgent drift threshold that hasn't fired this week
            if daysSinceActivity >= 30, await shouldFire(journeyId: jid, type: "drift_30") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "drift_30", progress: progress
                )
                await markFired(journeyId: jid, type: "drift_30")
            } else if daysSinceActivity >= 14, await shouldFire(journeyId: jid, type: "drift_14") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "drift_14", progress: progress
                )
                await markFired(journeyId: jid, type: "drift_14")
            } else if daysSinceActivity >= 7, await shouldFire(journeyId: jid, type: "drift_7") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "drift_7", progress: progress
                )
                await markFired(journeyId: jid, type: "drift_7")
            }

            // --- Deadline proximity ---
            guard let targetDate = journey.targetDate else { continue }
            let daysRemaining = cal.dateComponents(
                [.day],
                from: today,
                to: cal.startOfDay(for: targetDate)
            ).day ?? 0

            guard daysRemaining >= 0 else { continue } // Already past deadline

            if daysRemaining <= 7, await shouldFire(journeyId: jid, type: "deadline_7") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "deadline_7", progress: progress,
                    daysUntilDeadline: daysRemaining
                )
                await markFired(journeyId: jid, type: "deadline_7")
            } else if daysRemaining <= 14, await shouldFire(journeyId: jid, type: "deadline_14") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "deadline_14", progress: progress,
                    daysUntilDeadline: daysRemaining
                )
                await markFired(journeyId: jid, type: "deadline_14")
            } else if daysRemaining <= 30, await shouldFire(journeyId: jid, type: "deadline_30") {
                await nm.scheduleJourneyHealthNotification(
                    journeyId: jid, journeyName: journey.title,
                    type: "deadline_30", progress: progress,
                    daysUntilDeadline: daysRemaining
                )
                await markFired(journeyId: jid, type: "deadline_30")
            }
        }
    }

    // MARK: - Public: In-App Nudges

    /// Generate in-app `LuminaNudge` items for drifting journeys.
    /// Call from generateOfflineBriefing and generateNudges for offline-capable display.
    /// Returns at most 2 nudges to avoid card overflow.
    func generateJourneyHealthNudges(context: ModelContext) -> [LuminaNudge] {
        let journeys = activeJourneys(context: context)
        let cal  = Calendar.current
        let today = cal.startOfDay(for: Date())
        var nudges: [LuminaNudge] = []

        for journey in journeys where nudges.count < 2 {
            let progress = Int(journey.progress * 100)

            // Drift check — consider both linked TaskWork completions AND milestone completions.
            // Demo / seeded data often seeds milestones but not linked tasks, so both are needed.
            let lastTaskActivity = (journey.tasks ?? [])
                .compactMap { $0.completedAt }.max()
            let lastMilestoneActivity = (journey.milestones ?? [])
                .compactMap { $0.completedAt }.max()
            let lastActivity = [lastTaskActivity, lastMilestoneActivity]
                .compactMap { $0 }.max()
            let daysSince: Int
            if let last = lastActivity {
                daysSince = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            } else {
                daysSince = cal.dateComponents([.day], from: cal.startOfDay(for: journey.startDate), to: today).day ?? 0
            }

            let body: String
            let urgency: NudgeUrgency
            if daysSince >= 30 {
                body = "'\(journey.title)' has been dormant for a month. Is this still a priority?"
                urgency = .high
            } else if daysSince >= 14 {
                body = "'\(journey.title)' journey is stalling — last activity was 2 weeks ago."
                urgency = .medium
            } else if daysSince >= 7 {
                body = "'\(journey.title)' hasn't had any activity this week. One task keeps momentum alive."
                urgency = .medium
            } else {
                // No drift — check deadline proximity instead
                guard let targetDate = journey.targetDate else { continue }
                let daysLeft = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: targetDate)).day ?? 0
                guard daysLeft >= 0, daysLeft <= 30 else { continue }
                body = "'\(journey.title)' target is in \(daysLeft) day\(daysLeft == 1 ? "" : "s") — you're \(progress)% done."
                urgency = daysLeft <= 7 ? .high : .medium
            }

            nudges.append(LuminaNudge(
                type: .goalDrift,
                title: "Journey Needs Attention",
                body: body,
                icon: NudgeType.goalDrift.defaultIcon,
                urgency: urgency
            ))
        }

        return nudges
    }

    // MARK: - Private Helpers

    private func activeJourneys(context: ModelContext) -> [Journey] {
        let desc = FetchDescriptor<Journey>()
        return ((try? context.fetch(desc)) ?? [])
            .filter { j in
                j.status != .completed && j.status != .paused
            }
            .sorted { ($0.progress) < ($1.progress) } // lowest progress first
    }

    /// Returns true if this alert type has NOT already fired for this journey this week.
    private func shouldFire(journeyId: String, type: String) async -> Bool {
        let key = dedupKey(journeyId: journeyId, type: type)
        return UserDefaults.standard.object(forKey: key) == nil
    }

    /// Mark an alert as fired for the current week (prevents re-firing this week).
    private func markFired(journeyId: String, type: String) async {
        let key = dedupKey(journeyId: journeyId, type: type)
        UserDefaults.standard.set(Date(), forKey: key)
    }

    /// UserDefaults key format: "journeyAlert_{journeyId}_{type}_{year}_{weekOfYear}"
    private func dedupKey(journeyId: String, type: String) -> String {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let week = cal.component(.weekOfYear, from: Date())
        return "journeyAlert_\(journeyId)_\(type)_\(year)_\(week)"
    }
}
