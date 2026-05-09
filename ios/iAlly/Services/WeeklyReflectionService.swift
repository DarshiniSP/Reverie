//
//  WeeklyReflectionService.swift
//  iAlly
//
//  P2-A: Weekly Reflection Service
//  P3-D: Honest Weekly Pattern Report (3 observation types, max 3 per week)
//
//  Fires every Sunday at 8pm with a data-driven weekly summary.
//  Purely SwiftData — no PAI required. Tier 1 intelligence.
//
//  Data model is Codable and cached in UserDefaults so it's available
//  in-app without rerunning the query on every view appear.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - Weekly Report Domain Breakdown

struct WeeklyReportDomain: Codable, Identifiable {
    var id: String { domain }
    let domain: String
    let planned: Int
    let completed: Int

    var completionRate: Double {
        planned > 0 ? Double(completed) / Double(planned) : 0.0
    }

    var completionPercent: Int { Int(completionRate * 100) }
}

// MARK: - Weekly Report

struct WeeklyReport: Codable {
    let weekEnding: Date
    let totalPlanned: Int
    let totalCompleted: Int
    let domains: [WeeklyReportDomain]      // sorted by domain name
    let bestStreakRoutine: String?
    let bestStreak: Int
    /// P3-D: Up to 3 honest observations (uncomfortable truths).
    let honestObservations: [String]
    let generatedAt: Date

    // MARK: Backward compatibility

    /// First observation for views that only show one. Alias for honestObservations.first.
    var honestObservation: String? { honestObservations.first }

    // MARK: Codable (backward compat with old single `honestObservation: String?` format)

    enum CodingKeys: String, CodingKey {
        case weekEnding, totalPlanned, totalCompleted, domains
        case bestStreakRoutine, bestStreak
        case honestObservations   // new array key
        case honestObservation    // old single-string key (read-only, for migration)
        case generatedAt
    }

    init(
        weekEnding: Date,
        totalPlanned: Int,
        totalCompleted: Int,
        domains: [WeeklyReportDomain],
        bestStreakRoutine: String?,
        bestStreak: Int,
        honestObservations: [String],
        generatedAt: Date = Date()
    ) {
        self.weekEnding = weekEnding
        self.totalPlanned = totalPlanned
        self.totalCompleted = totalCompleted
        self.domains = domains
        self.bestStreakRoutine = bestStreakRoutine
        self.bestStreak = bestStreak
        self.honestObservations = honestObservations
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekEnding       = try c.decode(Date.self,                    forKey: .weekEnding)
        totalPlanned     = try c.decode(Int.self,                     forKey: .totalPlanned)
        totalCompleted   = try c.decode(Int.self,                     forKey: .totalCompleted)
        domains          = try c.decode([WeeklyReportDomain].self,    forKey: .domains)
        bestStreakRoutine = try c.decodeIfPresent(String.self,        forKey: .bestStreakRoutine)
        bestStreak       = try c.decodeIfPresent(Int.self,            forKey: .bestStreak) ?? 0
        generatedAt      = try c.decodeIfPresent(Date.self,           forKey: .generatedAt) ?? Date()
        // Migration: prefer new array format; fall back to old single-string format.
        // Use a do/catch so decodeIfPresent returns T? directly (no double-optional).
        do {
            if let arr = try c.decodeIfPresent([String].self, forKey: .honestObservations) {
                honestObservations = arr
            } else if let s = try c.decodeIfPresent(String.self, forKey: .honestObservation) {
                honestObservations = [s]
            } else {
                honestObservations = []
            }
        } catch {
            honestObservations = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(weekEnding,        forKey: .weekEnding)
        try c.encode(totalPlanned,      forKey: .totalPlanned)
        try c.encode(totalCompleted,    forKey: .totalCompleted)
        try c.encode(domains,           forKey: .domains)
        try c.encodeIfPresent(bestStreakRoutine, forKey: .bestStreakRoutine)
        try c.encode(bestStreak,        forKey: .bestStreak)
        try c.encode(honestObservations, forKey: .honestObservations)
        try c.encode(generatedAt,       forKey: .generatedAt)
    }

    // MARK: Computed

    var completionRate: Double {
        totalPlanned > 0 ? Double(totalCompleted) / Double(totalPlanned) : 0.0
    }

    var completionPercent: Int { Int(completionRate * 100) }

    /// Worst-performing domain (min completion rate, at least 1 task planned).
    var worstDomain: WeeklyReportDomain? {
        domains.filter { $0.planned > 0 }.min(by: { $0.completionRate < $1.completionRate })
    }

    /// Short summary for the push notification body.
    var notificationSummary: String {
        var lines: [String] = ["✅ \(totalCompleted)/\(totalPlanned) tasks (\(completionPercent)%)"]
        if let obs = honestObservations.first {
            lines.append("⚠️ \(obs)")
        }
        if bestStreak >= 5, let name = bestStreakRoutine {
            lines.append("🔥 \(name): \(bestStreak)-day streak")
        }
        return lines.joined(separator: " · ")
    }
}

// MARK: - Service

@MainActor
final class WeeklyReflectionService {

    static let shared = WeeklyReflectionService()
    private init() {}

    // MARK: - Constants

    private let reportCacheKey    = "ially.weeklyReport"
    private let notificationID    = "weekly-reflection"
    private let lastGeneratedKey  = "ially.weeklyReport.lastGeneratedWeek"
    /// P3-D: Stores the first observation from last week to prevent exact repetition.
    private let lastObsKey        = "ially.weeklyReport.lastHonestObs"

    // MARK: - Public API

    /// Schedule the recurring Sunday 8pm weekly reflection notification.
    /// Safe to call at every app launch — skips if already scheduled.
    func scheduleWeeklyReflection() async {
        guard NotificationManager.shared.isAuthorized else { return }

        // Skip if already scheduled (avoids duplicate entries in notification center)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if pending.contains(where: { $0.identifier == notificationID }) { return }

        var components = DateComponents()
        components.weekday = 1   // Sunday (Gregorian: 1=Sun)
        components.hour    = 20  // 8pm
        components.minute  = 0

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body  = "Lumina has your weekly summary ready — see what you accomplished."
        content.sound = .default
        content.categoryIdentifier = NotificationManager.NotificationType.luminaNudge.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Generate the weekly report from SwiftData and cache it.
    /// Returns `nil` when there are no tasks this week (prevents empty notification).
    @discardableResult
    func generateWeeklyReport(context: ModelContext) -> WeeklyReport? {
        let cal  = Calendar.current
        let now  = Date()

        // Dedup: regenerate at most once per calendar week
        let thisWeekKey = "\(cal.component(.year, from: now))_\(cal.component(.weekOfYear, from: now))"
        if UserDefaults.standard.string(forKey: lastGeneratedKey) == thisWeekKey,
           let cached = lastReport { return cached }

        let weekStart = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now))!

        // Fetch all tasks
        let allTasks = (try? context.fetch(FetchDescriptor<TaskWork>())) ?? []

        // Tasks created or due this week
        let thisWeekTasks = allTasks.filter { t in
            let date = t.dueDate ?? t.createdAt
            return date >= weekStart && date <= now
        }
        guard !thisWeekTasks.isEmpty else { return nil }

        let completedTasks = thisWeekTasks.filter { $0.completedAt != nil }

        // Per-domain breakdown
        var domainPlanned:   [String: Int] = [:]
        var domainCompleted: [String: Int] = [:]
        for task in thisWeekTasks {
            let domain = task.plan?.lifeDomain.rawValue ?? task.lifeDomain?.rawValue ?? "Personal"
            domainPlanned[domain, default: 0]   += 1
            if task.completedAt != nil {
                domainCompleted[domain, default: 0] += 1
            }
        }
        let domains: [WeeklyReportDomain] = domainPlanned.keys.sorted().map { d in
            WeeklyReportDomain(
                domain: d,
                planned: domainPlanned[d]!,
                completed: domainCompleted[d, default: 0]
            )
        }

        // Best routine streak
        let routines = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        let bestRoutine = routines.max(by: { $0.currentStreak < $1.currentStreak })

        // P3-D: Build up to 3 honest observations (max 3, no repeat of last week's first obs)
        let honestObservations = buildHonestObservations(
            domains: domains,
            completedTasks: completedTasks,
            allTasks: allTasks,
            context: context,
            weekStart: weekStart,
            now: now,
            cal: cal
        )

        let report = WeeklyReport(
            weekEnding: now,
            totalPlanned: thisWeekTasks.count,
            totalCompleted: completedTasks.count,
            domains: domains,
            bestStreakRoutine: (bestRoutine?.currentStreak ?? 0) >= 3 ? bestRoutine?.title : nil,
            bestStreak: bestRoutine?.currentStreak ?? 0,
            honestObservations: honestObservations
        )

        // Persist report + dedup key
        if let data = try? JSONEncoder().encode(report) {
            UserDefaults.standard.set(data, forKey: reportCacheKey)
        }
        UserDefaults.standard.set(thisWeekKey, forKey: lastGeneratedKey)
        // Store first observation so next week can avoid repeating it
        UserDefaults.standard.set(honestObservations.first, forKey: lastObsKey)

        // Update the scheduled notification body with real data
        Task { await updateNotificationBody(report) }

        return report
    }

    /// The most recently generated weekly report (loaded from UserDefaults cache).
    var lastReport: WeeklyReport? {
        guard let data = UserDefaults.standard.data(forKey: reportCacheKey),
              let report = try? JSONDecoder().decode(WeeklyReport.self, from: data)
        else { return nil }
        return report
    }

    // MARK: - P3-D: Honest Observation Engine

    /// Generate up to 3 honest observations from this week's data.
    /// Rules: each type requires a meaningful threshold; max 3; no repeat of last week's first obs.
    private func buildHonestObservations(
        domains: [WeeklyReportDomain],
        completedTasks: [TaskWork],
        allTasks: [TaskWork],
        context: ModelContext,
        weekStart: Date,
        now: Date,
        cal: Calendar
    ) -> [String] {
        var observations: [String] = []
        let lastObs = UserDefaults.standard.string(forKey: lastObsKey)

        // --- Type 1: Zero-completion domain (≥ 2 planned tasks, zero completed) ---
        let worstDomain = domains.filter { $0.planned > 0 }
            .min(by: { $0.completionRate < $1.completionRate })
        if let worst = worstDomain {
            var obs: String? = nil
            if worst.completed == 0 && worst.planned >= 2 {
                obs = "\(worst.domain) had \(worst.planned) planned task\(worst.planned == 1 ? "" : "s") but zero completions this week."
            } else if worst.completionRate < 0.30 && worst.planned >= 3 {
                obs = "\(worst.domain) completed only \(worst.completed)/\(worst.planned) tasks (\(worst.completionPercent)%) this week."
            }
            if let obs, obs != lastObs {
                observations.append(obs)
            }
        }

        guard observations.count < 3 else { return Array(observations.prefix(3)) }

        // --- Type 2: Stale journey (active, no milestone or task activity in ≥ 14 days) ---
        let threeWeeksAgo = cal.date(byAdding: .day, value: -21, to: now)!
        let journeys = (try? context.fetch(FetchDescriptor<Journey>())) ?? []
        for journey in journeys where journey.status != .completed && journey.status != .paused {
            let lastTaskActivity = (journey.tasks ?? []).compactMap { $0.completedAt }.max()
            let lastMilestoneActivity = (journey.milestones ?? []).compactMap { $0.completedAt }.max()
            let lastActivity = [lastTaskActivity, lastMilestoneActivity].compactMap { $0 }.max()
                ?? journey.startDate

            if lastActivity <= threeWeeksAgo {
                let weeksInactive = max(1, Int(now.timeIntervalSince(lastActivity) / (7 * 86400)))
                let obs = "'\(journey.title)' has had no activity for \(weeksInactive)+ week\(weeksInactive == 1 ? "" : "s"). Still relevant?"
                if obs != lastObs {
                    observations.append(obs)
                    break  // One stale-journey obs per week
                }
            }
        }

        guard observations.count < 3 else { return Array(observations.prefix(3)) }

        // --- Type 3: Dominant domain (one domain > 70% of completed tasks, ≥ 3 completed) ---
        if completedTasks.count >= 3 {
            let domainCounts = Dictionary(grouping: completedTasks) { (t: TaskWork) -> String in
                t.plan?.lifeDomain.rawValue ?? t.lifeDomain?.rawValue ?? "Personal"
            }.mapValues { $0.count }

            if let top = domainCounts.max(by: { $0.value < $1.value }) {
                let pct = Int(Double(top.value) / Double(completedTasks.count) * 100)
                if pct >= 70 {
                    let obs = "\(top.key) consumed \(pct)% of your completed tasks this week."
                    if obs != lastObs {
                        observations.append(obs)
                    }
                }
            }
        }

        return Array(observations.prefix(3))
    }

    // MARK: - Private

    /// Refresh the scheduled Sunday notification body with real completion data.
    private func updateNotificationBody(_ report: WeeklyReport) async {
        guard NotificationManager.shared.isAuthorized else { return }

        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID])

        var components = DateComponents()
        components.weekday = 1
        components.hour    = 20
        components.minute  = 0

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review"
        content.body  = report.notificationSummary
        content.sound = .default
        content.categoryIdentifier = NotificationManager.NotificationType.luminaNudge.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
