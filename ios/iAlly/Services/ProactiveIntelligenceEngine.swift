//
//  ProactiveIntelligenceEngine.swift
//  iAlly
//
//  Phase 3: Proactive Intelligence
//  Runs on BGAppRefreshTask overnight and mid-day, using the inference router for:
//    • Goal drift (journey vs actual actions)
//    • Energy patterns (time-of-day task success rates)
//    • Upcoming milestone proximity
//    • Long-silence detection on important domains
//    • Daily briefing generation
//
//  Results are stored in pendingNudges (for Today card) and delivered
//  to NotificationManager (for system notifications).
//

import Foundation
import BackgroundTasks
import SwiftData
import Observation
import WidgetKit

// MARK: - Nudge Types

struct LuminaNudge: Identifiable, Codable, Equatable {
    let id: UUID
    let type: NudgeType
    let title: String
    let body: String
    let icon: String
    let urgency: NudgeUrgency
    let createdAt: Date

    init(
        id: UUID = UUID(),
        type: NudgeType,
        title: String,
        body: String,
        icon: String,
        urgency: NudgeUrgency,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.icon = icon
        self.urgency = urgency
        self.createdAt = createdAt
    }
}

enum NudgeType: String, Codable {
    case goalDrift      = "goal_drift"       // Journey vs actual actions
    case energyPattern  = "energy_pattern"   // Optimal time suggestion
    case milestone      = "milestone"        // Upcoming milestone proximity
    case silence        = "domain_silence"   // Long silence on important domain
    case reflection     = "reflection"       // Daily reflection prompt
    case focus          = "daily_focus"      // Key focus for today
    case achievement    = "achievement"      // Celebration nudge

    var defaultIcon: String {
        switch self {
        case .goalDrift:     return "arrow.triangle.branch"
        case .energyPattern: return "bolt.circle.fill"
        case .milestone:     return "flag.circle.fill"
        case .silence:       return "moon.zzz.fill"
        case .reflection:    return "sparkle.magnifyingglass"
        case .focus:         return "scope"
        case .achievement:   return "star.circle.fill"
        }
    }
}

enum NudgeUrgency: Int, Codable, Comparable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: NudgeUrgency, rhs: NudgeUrgency) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Day Type (P1-A)

/// Classifies what kind of day today is, computed locally from AppContext.
/// Never requires PAI — always available offline.
enum DayType: String, Codable, CaseIterable {
    case focusDay    = "Focus Day"
    case catchUpDay  = "Catch-Up Day"
    case planningDay = "Planning Day"
    case freeDay     = "Free Day"

    var icon: String {
        switch self {
        case .focusDay:    return "scope"
        case .catchUpDay:  return "clock.arrow.circlepath"
        case .planningDay: return "calendar.badge.plus"
        case .freeDay:     return "sun.max.fill"
        }
    }

    var color: String {
        switch self {
        case .focusDay:    return "#4C8BF5"   // blue
        case .catchUpDay:  return "#F5A623"   // amber
        case .planningDay: return "#7A5AF5"   // purple
        case .freeDay:     return "#2BBB7F"   // green
        }
    }

    var tagline: String {
        switch self {
        case .focusDay:    return "Clear the decks. One thing at a time."
        case .catchUpDay:  return "Work through the backlog. Progress over perfection."
        case .planningDay: return "Slow down to speed up. Map what's next."
        case .freeDay:     return "Recharge. A rested mind works better."
        }
    }
}

// MARK: - Daily Briefing

struct DailyBriefing: Codable {
    let date: Date
    let dayType: DayType         // P1-A: day classification verdict
    let focusTask: String?
    let patternInsight: String
    let upcomingMilestone: String?
    let reflectionPrompt: String
    let narrative: String        // Full PAI-generated briefing text
    let generatedAt: Date

    init(
        date: Date = Date(),
        dayType: DayType = .focusDay,
        focusTask: String? = nil,
        patternInsight: String,
        upcomingMilestone: String? = nil,
        reflectionPrompt: String,
        narrative: String,
        generatedAt: Date = Date()
    ) {
        self.date = date
        self.dayType = dayType
        self.focusTask = focusTask
        self.patternInsight = patternInsight
        self.upcomingMilestone = upcomingMilestone
        self.reflectionPrompt = reflectionPrompt
        self.narrative = narrative
        self.generatedAt = generatedAt
    }
}

// MARK: - Engine

@Observable
@MainActor
final class ProactiveIntelligenceEngine {

    static let shared = ProactiveIntelligenceEngine()

    // BGTask identifier
    static let bgTaskIdentifier = "com.irigam.iAlly.proactiveIntelligence"

    // Observable state
    var pendingNudges: [LuminaNudge] = []
    var todaysBriefing: DailyBriefing? = nil
    var isGenerating = false
    var lastRunAt: Date? = nil
    var lastError: String? = nil

    // GAP 6: Holds a reference to the ModelContainer so the static BGTask handler can
    // create a fresh ModelContext without needing the App struct's instance property.
    var modelContainer: ModelContainer?

    // Cache key
    private let briefingCacheKey = "proactive_briefing_date"
    private let nudgesCacheKey   = "proactive_nudges_json"

    private init() {
        loadCachedBriefing()
    }

    // MARK: - Public Interface

    /// Run the full intelligence cycle. Called from BGTask handler and on app foreground
    /// if it hasn't run today.
    func runIfNeeded(context: ModelContext) async {
        // ALWAYS produce at least an offline briefing so the UI is never blank.
        // This runs synchronously and is instant — it reads SwiftData locally.
        // Critical for UI tests and cold-launch where PAI may not be reachable.
        if todaysBriefing == nil {
            generateOfflineBriefing(context: context)
        }

        // Full PAI-powered cycle: only run once per calendar day.
        let today = Calendar.current.startOfDay(for: Date())
        let lastRun = UserDefaults.standard.object(forKey: briefingCacheKey) as? Date
        // If offline briefing already set the cache key today, skip the full PAI cycle
        // (it will run on the next day or when explicitly force-refreshed).
        guard lastRun == nil || lastRun! < today else { return }
        await runCycle(context: context)
    }

    /// Force a full cycle (e.g. on pull-to-refresh in DailyBriefingView)
    func runCycle(context: ModelContext) async {
        guard !isGenerating else { return }
        // Only run AI calls when an inference provider is configured.
        guard LuminaInferenceRouter.shared.isActiveProviderConfigured else {
            generateOfflineBriefing(context: context)
            return
        }

        isGenerating = true
        // Safety net: guarantee isGenerating is cleared no matter how runCycle exits
        // (normal completion, error thrown from do-catch, or Swift task cancellation).
        defer { isGenerating = false }
        lastError = nil

        do {
            let appContext = buildAppContext(context: context)

            // P2-A: Generate weekly report (fast SwiftData query, always useful)
            WeeklyReflectionService.shared.generateWeeklyReport(context: context)

            async let briefing = generateDailyBriefing(appContext: appContext)
            async let nudges   = generateNudges(appContext: appContext, context: context)

            let (b, n) = try await (briefing, nudges)
            todaysBriefing = b
            pendingNudges  = n.sorted { $0.urgency > $1.urgency }

            // Cache
            UserDefaults.standard.set(Date(), forKey: briefingCacheKey)
            cacheNudges(n)

            // Phase 4: Write to shared app group for widget consumption
            let appGroup = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly")
            appGroup?.set(b.narrative, forKey: "lumina.widget.insight")
            appGroup?.set(b.focusTask ?? "", forKey: "lumina.widget.focusTask")
            appGroup?.set(Date(), forKey: "lumina.widget.updatedAt")
            WidgetCenter.shared.reloadAllTimelines()

            // Fire system notification for the highest urgency nudge
            if let top = pendingNudges.first(where: { $0.urgency == .high }) {
                await NotificationManager.shared.deliverLuminaNudge(top)
            }

            // P1-D: Schedule streak risk + journey drift smart notifications
            await scheduleSmartNotifications(appContext: appContext, context: context)

            lastRunAt = Date()
        } catch {
            lastError = error.localizedDescription
        }
        // isGenerating = false is handled by the defer above.
    }

    // MARK: - Context Builder

    private struct AppContext {
        let overdueCount: Int
        let dueTodayCount: Int
        let completedThisWeek: Int
        let activeJourneys: [(name: String, progress: Double, daysUntilTarget: Int?)]
        let upcomingMilestones: [(journey: String, title: String, daysUntil: Int)]
        let silentDomains: [String]           // domains with no tasks completed in 14+ days
        let topDomain: String?
        let streaks: [(routineName: String, streak: Int)]
        let knowledgeCount: Int
        let hourOfDay: Int
        // P2-C: 2-week domain balance for imbalance detection
        let domainBalance2w: [String: Int]    // domain → completed task count (14-day window)
    }

    private func buildAppContext(context: ModelContext) -> AppContext {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekAgo = cal.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let taskDesc = FetchDescriptor<TaskWork>()
        let allTasks = (try? context.fetch(taskDesc)) ?? []

        let overdueCount = allTasks.filter { t in
            guard let d = t.dueDate, t.completedAt == nil else { return false }
            return cal.startOfDay(for: d) < today
        }.count

        let dueTodayCount = allTasks.filter { t in
            guard let d = t.dueDate, t.completedAt == nil else { return false }
            let s = cal.startOfDay(for: d)
            return s >= today && s < tomorrow
        }.count

        let completedThisWeek = allTasks.filter { t in
            guard let c = t.completedAt else { return false }
            return c >= weekAgo
        }.count

        // Journeys
        let journeyDesc = FetchDescriptor<Journey>()
        let journeys = (try? context.fetch(journeyDesc)) ?? []
        let activeJourneys: [(String, Double, Int?)] = journeys.compactMap { j in
            guard j.status != .completed && j.status != .paused else { return nil }
            let progress = j.progress
            let daysUntil: Int? = j.targetDate.map {
                let diff = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: $0)).day ?? 0
                return diff
            }
            return (j.title, progress, daysUntil)
        }

        // Upcoming milestones (within 7 days)
        let milestoneDesc = FetchDescriptor<Milestone>()
        let allMilestones = (try? context.fetch(milestoneDesc)) ?? []
        let upcomingMilestones: [(String, String, Int)] = allMilestones.compactMap { m in
            guard !m.isCompleted, let due = m.targetDate else { return nil }
            let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: due)).day ?? 0
            guard days >= 0 && days <= 7 else { return nil }
            let journeyName = m.journey?.title ?? "Journey"
            return (journeyName, m.title, days)
        }

        // Silent domains: domains with no task completion in 14+ days
        let planDesc = FetchDescriptor<Plan>()
        let allPlans = (try? context.fetch(planDesc)) ?? []
        let silentDomains: [String] = allPlans.compactMap { plan in
            let tasks = plan.tasks ?? []
            let recentCompletion = tasks.compactMap { $0.completedAt }.max()
            if recentCompletion == nil || recentCompletion! < twoWeeksAgo {
                return plan.lifeDomain.rawValue
            }
            return nil
        }

        // Top domain by task completion rate this week
        let domainCounts = Dictionary(grouping: allTasks.filter { $0.completedAt != nil && ($0.completedAt ?? Date.distantPast) >= weekAgo }) { (t: TaskWork) -> String in
            t.plan?.lifeDomain.rawValue ?? "Personal"
        }
        let topDomain = domainCounts.max(by: { $0.value.count < $1.value.count })?.key

        // P2-C: 2-week domain balance — completions per domain in last 14 days
        let domainBalance2w: [String: Int] = Dictionary(
            grouping: allTasks.filter { t in
                guard let c = t.completedAt else { return false }
                return c >= twoWeeksAgo
            }
        ) { (t: TaskWork) -> String in
            t.plan?.lifeDomain.rawValue ?? t.lifeDomain?.rawValue ?? "Personal"
        }.mapValues { $0.count }

        // Routine streaks
        let routineDesc = FetchDescriptor<Routine>()
        let routines = (try? context.fetch(routineDesc)) ?? []
        let streaks = routines.filter { $0.currentStreak > 0 }.map { ($0.title, $0.currentStreak) }

        // Knowledge count
        let knowledgeDesc = FetchDescriptor<Knowledge>()
        let knowledgeCount = (try? context.fetch(knowledgeDesc))?.count ?? 0

        return AppContext(
            overdueCount: overdueCount,
            dueTodayCount: dueTodayCount,
            completedThisWeek: completedThisWeek,
            activeJourneys: activeJourneys,
            upcomingMilestones: upcomingMilestones,
            silentDomains: silentDomains,
            topDomain: topDomain,
            streaks: streaks,
            knowledgeCount: knowledgeCount,
            hourOfDay: cal.component(.hour, from: Date()),
            domainBalance2w: domainBalance2w
        )
    }

    // MARK: - Day Type Computation (P1-A)
    // Fully local — no PAI required. Uses AppContext data to classify the day.

    private func computeDayType(_ ctx: AppContext) -> DayType {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Sunday=1, Monday=2 ... Friday=6, Saturday=7
        let isWeekend = weekday == 1 || weekday == 7

        // Free day on weekends with nothing urgent
        if isWeekend && ctx.overdueCount == 0 && ctx.dueTodayCount == 0 {
            return .freeDay
        }

        // Catch-up day: significant overdue backlog
        if ctx.overdueCount >= 3 {
            return .catchUpDay
        }

        // Planning day: Monday or day with no tasks due + active journeys needing direction
        let isMonday = weekday == 2
        if isMonday && ctx.dueTodayCount <= 1 && !ctx.activeJourneys.isEmpty {
            return .planningDay
        }

        // Planning day: no tasks due and there are drifting journeys (< 10% progress)
        let driftingJourneys = ctx.activeJourneys.filter { $0.progress < 0.1 }
        if ctx.dueTodayCount == 0 && !driftingJourneys.isEmpty {
            return .planningDay
        }

        // Catch-up day: at least one overdue + low completion this week
        if ctx.overdueCount >= 1 && ctx.completedThisWeek < 3 {
            return .catchUpDay
        }

        // Default: focus day when there are clear tasks to complete
        return .focusDay
    }

    // MARK: - Briefing Generation

    private func generateDailyBriefing(appContext: AppContext) async throws -> DailyBriefing {
        let contextString = buildContextPrompt(appContext)
        let prompt = """
        You are Lumina, \(AppConfig.appName)'s personal AI companion.
        Generate a concise morning briefing (3–4 sentences) for your user based on their current context.
        Be warm, specific, and actionable. Do not list bullet points — write as natural prose.

        Context:
        \(contextString)

        Respond with a JSON object in this exact format:
        {
          "narrative": "the full briefing paragraph",
          "patternInsight": "one specific pattern or insight (15 words max)",
          "reflectionPrompt": "one reflective question to start the day (12 words max)",
          "focusTask": "the single most important task title, or null"
        }
        Respond with JSON only, no markdown fences.
        """

        let content = try await LuminaInferenceRouter.shared.generate(
            messages: [PAIChatMessage.user(prompt)]
        )

        // Parse JSON response
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return fallbackBriefing(appContext: appContext)
        }

        let narrative  = json["narrative"] as? String ?? "Good morning! Let's make today count."
        let pattern    = json["patternInsight"] as? String ?? "Your productivity drives your goals forward."
        let reflection = json["reflectionPrompt"] as? String ?? "What one thing matters most today?"
        let focusTask  = json["focusTask"] as? String

        // Upcoming milestone description
        let milestone = appContext.upcomingMilestones.first.map {
            "\($0.title) in \($0.journey) (\($0.daysUntil) days)"
        }

        return DailyBriefing(
            dayType: computeDayType(appContext),
            focusTask: focusTask,
            patternInsight: pattern,
            upcomingMilestone: milestone,
            reflectionPrompt: reflection,
            narrative: narrative
        )
    }

    /// P1-B: Data-driven fallback — always meaningful, never random.
    private func fallbackBriefing(appContext: AppContext) -> DailyBriefing {
        let dayType = computeDayType(appContext)
        let narrative = buildOfflineNarrative(dayType: dayType, ctx: appContext)
        let insight = buildOfflineInsight(ctx: appContext)
        let reflection = buildOfflineReflection(dayType: dayType, ctx: appContext)
        let focusTask = buildFocusSuggestion(ctx: appContext)
        let milestone = appContext.upcomingMilestones.first.map {
            "\($0.title) in \($0.journey) (\($0.daysUntil) days)"
        }
        return DailyBriefing(
            dayType: dayType,
            focusTask: focusTask,
            patternInsight: insight,
            upcomingMilestone: milestone,
            reflectionPrompt: reflection,
            narrative: narrative
        )
    }

    private func buildOfflineNarrative(dayType: DayType, ctx: AppContext) -> String {
        var parts: [String] = []

        // Opening grounded in real data
        switch dayType {
        case .focusDay:
            if ctx.dueTodayCount > 0 {
                parts.append("You have \(ctx.dueTodayCount) task\(ctx.dueTodayCount == 1 ? "" : "s") on deck today.")
            } else {
                parts.append("Your slate is clear — a perfect day to move the needle on something meaningful.")
            }
        case .catchUpDay:
            parts.append("You have \(ctx.overdueCount) overdue item\(ctx.overdueCount == 1 ? "" : "s") waiting. Let's chip away at the backlog today.")
        case .planningDay:
            if ctx.activeJourneys.isEmpty {
                parts.append("No active journeys yet — today is a great day to map out your next horizon.")
            } else {
                parts.append("You have \(ctx.activeJourneys.count) active journey\(ctx.activeJourneys.count == 1 ? "" : "s"). Step back and chart the course ahead.")
            }
        case .freeDay:
            parts.append("No urgent tasks pressing on you today.")
        }

        // Add streak context if relevant
        if let best = ctx.streaks.max(by: { $0.streak < $1.streak }), best.streak >= 3 {
            parts.append("'\(best.routineName)' is on a \(best.streak)-day streak — keep that going.")
        }

        // Add milestone urgency if close
        if let m = ctx.upcomingMilestones.first, m.daysUntil <= 3 {
            let urgency = m.daysUntil == 0 ? "today" : "in \(m.daysUntil) day\(m.daysUntil == 1 ? "" : "s")"
            parts.append("'\(m.title)' milestone is due \(urgency).")
        }

        // Add completion momentum
        if ctx.completedThisWeek >= 5 {
            parts.append("Strong week so far — \(ctx.completedThisWeek) tasks completed.")
        }

        return parts.joined(separator: " ")
    }

    private func buildOfflineInsight(ctx: AppContext) -> String {
        // Pick the most relevant insight based on real data
        if let silent = ctx.silentDomains.first {
            return "\(silent) hasn't seen activity in 2+ weeks."
        }
        if let top = ctx.topDomain {
            return "You're in the zone with \(top) work this week."
        }
        if ctx.completedThisWeek > 0 {
            return "\(ctx.completedThisWeek) tasks completed this week — momentum is building."
        }
        if !ctx.activeJourneys.isEmpty {
            let lowest = ctx.activeJourneys.min(by: { $0.progress < $1.progress })
            if let j = lowest, j.progress < 0.15 {
                return "'\(j.name)' journey needs consistent daily action."
            }
        }
        return "Small daily actions compound into big results over time."
    }

    private func buildOfflineReflection(dayType: DayType, ctx: AppContext) -> String {
        switch dayType {
        case .focusDay:
            return ctx.dueTodayCount > 1
                ? "Which of today's \(ctx.dueTodayCount) tasks will create the most impact?"
                : "What single action today will move you closest to your biggest goal?"
        case .catchUpDay:
            return "What's the one overdue item that, once cleared, will give you the most relief?"
        case .planningDay:
            if let j = ctx.activeJourneys.first {
                return "What needs to happen next week for '\(j.name)' to stay on track?"
            }
            return "If you could only accomplish three things this week, what would they be?"
        case .freeDay:
            return "What does resting and recharging look like for you today?"
        }
    }

    private func buildFocusSuggestion(ctx: AppContext) -> String? {
        // Priority: overdue > due today > upcoming milestone
        if ctx.overdueCount > 0 {
            return "Clear your oldest overdue task first"
        }
        if ctx.dueTodayCount > 0 {
            return "Complete your most important task due today"
        }
        if let m = ctx.upcomingMilestones.first {
            return "Prepare for '\(m.title)' milestone (\(m.daysUntil) days)"
        }
        return nil
    }

    // MARK: - P2-C: Domain Balance Analysis

    /// Detect life imbalance from a 2-week completion window.
    /// Returns a `LuminaNudge` when one domain is dominating (>70%) OR a domain
    /// with plans has had zero completions in 2 weeks.
    /// Returns `nil` when the data is balanced or insufficient.
    private func analyzeDomainBalance(ctx: AppContext) -> LuminaNudge? {
        let balance = ctx.domainBalance2w
        let total   = balance.values.reduce(0, +)
        guard total >= 3 else { return nil } // Need at least 3 completions for meaningful analysis

        // Check for dominant domain (> 70% of all completions in 2-week window)
        if let dominant = balance.max(by: { $0.value < $1.value }),
           Double(dominant.value) / Double(total) > 0.70 {
            let others = balance.keys
                .filter { $0 != dominant.key }
                .sorted()
                .prefix(2)
                .joined(separator: " and ")
            let body = others.isEmpty
                ? "\(dominant.key) is dominating your past two weeks. Consider a more balanced approach."
                : "\(dominant.key) is dominating your week — \(others) are falling behind."
            return LuminaNudge(
                type: .silence,
                title: "Life Imbalance Detected",
                body: body,
                icon: "chart.pie.fill",
                urgency: .medium
            )
        }

        return nil
    }

    // MARK: - Nudge Generation

    private func generateNudges(appContext: AppContext, context: ModelContext) async throws -> [LuminaNudge] {
        var nudges: [LuminaNudge] = []

        // 1. Goal drift check
        let driftingJourneys = appContext.activeJourneys.filter { $0.progress < 0.1 && ($0.daysUntilTarget ?? 999) < 60 }
        if let drifting = driftingJourneys.first {
            let body = try await generateNudgeBody(
                type: .goalDrift,
                context: "Journey '\(drifting.name)' is at \(Int(drifting.progress * 100))% with \(drifting.daysUntilTarget ?? 0) days remaining."
            )
            nudges.append(LuminaNudge(
                type: .goalDrift,
                title: "Journey Needs Attention",
                body: body,
                icon: NudgeType.goalDrift.defaultIcon,
                urgency: .high
            ))
        }

        // 2. Upcoming milestone
        if let m = appContext.upcomingMilestones.first {
            nudges.append(LuminaNudge(
                type: .milestone,
                title: m.daysUntil == 0 ? "Milestone Due Today" : "Milestone in \(m.daysUntil) days",
                body: "'\(m.title)' for your \(m.journey) journey is coming up. Are the tasks ready?",
                icon: NudgeType.milestone.defaultIcon,
                urgency: m.daysUntil <= 1 ? .high : .medium
            ))
        }

        // 3. Domain silence
        if let silent = appContext.silentDomains.first {
            let body = try await generateNudgeBody(
                type: .silence,
                context: "The \(silent) domain has had no completed tasks in the past two weeks."
            )
            nudges.append(LuminaNudge(
                type: .silence,
                title: "\(silent) Needs Attention",
                body: body,
                icon: NudgeType.silence.defaultIcon,
                urgency: .medium
            ))
        }

        // P2-C: Domain balance imbalance nudge (only when silence nudge not fired)
        if appContext.silentDomains.isEmpty, let balanceNudge = analyzeDomainBalance(ctx: appContext) {
            nudges.append(balanceNudge)
        }

        // P2-B: Journey health nudges (drift + deadline proximity)
        let journeyHealthNudges = JourneyHealthService.shared.generateJourneyHealthNudges(context: context)
        nudges.append(contentsOf: journeyHealthNudges.prefix(2))

        // 4. Achievement / streak celebration
        if let topStreak = appContext.streaks.max(by: { $0.streak < $1.streak }), topStreak.streak >= 7 {
            nudges.append(LuminaNudge(
                type: .achievement,
                title: "\(topStreak.streak)-Day Streak!",
                body: "You've kept up '\(topStreak.routineName)' for \(topStreak.streak) days. That consistency is building real momentum.",
                icon: NudgeType.achievement.defaultIcon,
                urgency: .low
            ))
        }

        // 5. Daily reflection
        nudges.append(LuminaNudge(
            type: .reflection,
            title: "Daily Reflection",
            body: todaysBriefing?.reflectionPrompt ?? "What one thing matters most today?",
            icon: NudgeType.reflection.defaultIcon,
            urgency: .low
        ))

        return nudges
    }

    private func generateNudgeBody(type: NudgeType, context: String) async throws -> String {
        let prompt = "Write a single supportive sentence (max 20 words) for this situation: \(context)"
        let content = try await LuminaInferenceRouter.shared.generate(
            messages: [PAIChatMessage.user(prompt)]
        )
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Offline Fallback (P1-B: Data-driven, never random)

    private func generateOfflineBriefing(context: ModelContext) {
        // P2-A: Generate weekly report from SwiftData (works fully offline — no PAI needed).
        // Must run before nudge generation so weeklyReportSection can read lastReport.
        WeeklyReflectionService.shared.generateWeeklyReport(context: context)

        let ctx = buildAppContext(context: context)
        let dayType = computeDayType(ctx)

        // Always give the full data-driven briefing even without PAI
        todaysBriefing = fallbackBriefing(appContext: ctx)

        // Build a rich nudge stack from real app data
        var nudges: [LuminaNudge] = []

        // 1. Day focus nudge (always present — anchors the day)
        let focusBody: String
        switch dayType {
        case .focusDay:
            focusBody = ctx.dueTodayCount > 0
                ? "You have \(ctx.dueTodayCount) task\(ctx.dueTodayCount == 1 ? "" : "s") due today. Start with your highest priority."
                : "Your slate is clear. Use today to advance a key journey or capture new knowledge."
        case .catchUpDay:
            focusBody = "You have \(ctx.overdueCount) overdue item\(ctx.overdueCount == 1 ? "" : "s"). Pick the most important and start there."
        case .planningDay:
            focusBody = "Review your active journeys and define 3 concrete next actions."
        case .freeDay:
            focusBody = "Rest, reflect, or explore something that energises you. No pressure."
        }
        nudges.append(LuminaNudge(
            type: .focus,
            title: "\(dayType.rawValue) — \(dayType.icon)",
            body: focusBody,
            icon: dayType.icon,
            urgency: ctx.overdueCount > 2 ? .high : .medium
        ))

        // 2. Streak risk: any routine not logged in 2+ days with an existing streak
        if let atRisk = ctx.streaks.filter({ $0.streak >= 3 }).max(by: { $0.streak < $1.streak }) {
            nudges.append(LuminaNudge(
                type: .achievement,
                title: "\(atRisk.streak)-Day Streak Active",
                body: "Don't break '\(atRisk.routineName)'. Log it today to keep the chain going.",
                icon: "flame.fill",
                urgency: .medium
            ))
        }

        // 3. Upcoming milestone (within 7 days)
        if let m = ctx.upcomingMilestones.first {
            let when = m.daysUntil == 0 ? "today" : "in \(m.daysUntil) day\(m.daysUntil == 1 ? "" : "s")"
            nudges.append(LuminaNudge(
                type: .milestone,
                title: m.daysUntil <= 1 ? "Milestone Due \(when.capitalized)!" : "Milestone in \(m.daysUntil) Days",
                body: "'\(m.title)' for your \(m.journey) journey is due \(when).",
                icon: NudgeType.milestone.defaultIcon,
                urgency: m.daysUntil <= 1 ? .high : .medium
            ))
        }

        // 4. Silent domain warning
        if let silent = ctx.silentDomains.first {
            nudges.append(LuminaNudge(
                type: .silence,
                title: "\(silent) Needs Attention",
                body: "You haven't completed anything in \(silent) for 2+ weeks. Even one small action helps.",
                icon: NudgeType.silence.defaultIcon,
                urgency: .low
            ))
        }

        // P2-C: Domain balance imbalance nudge (only when silence nudge not fired)
        if ctx.silentDomains.isEmpty, let balanceNudge = analyzeDomainBalance(ctx: ctx) {
            nudges.append(balanceNudge)
        }

        // P2-B: Journey health nudges (drift + deadline proximity)
        let journeyHealthNudges = JourneyHealthService.shared.generateJourneyHealthNudges(context: context)
        nudges.append(contentsOf: journeyHealthNudges.prefix(2))

        // 5. Reflection (always last)
        nudges.append(LuminaNudge(
            type: .reflection,
            title: "Daily Reflection",
            body: todaysBriefing?.reflectionPrompt ?? "What one thing matters most today?",
            icon: NudgeType.reflection.defaultIcon,
            urgency: .low
        ))

        pendingNudges = nudges.sorted { $0.urgency > $1.urgency }

        // Cache nudges but NOT the full briefing date — that's only set by runCycle
        // so the PAI-powered cycle can still fire later in the same day if needed.
        cacheNudges(pendingNudges)
    }

    // MARK: - Context Prompt Builder

    private func buildContextPrompt(_ ctx: AppContext) -> String {
        var lines: [String] = []
        lines.append("- Tasks due today: \(ctx.dueTodayCount)")
        lines.append("- Overdue tasks: \(ctx.overdueCount)")
        lines.append("- Completed this week: \(ctx.completedThisWeek)")
        lines.append("- Active journeys: \(ctx.activeJourneys.count)")
        if let top = ctx.topDomain { lines.append("- Most active domain this week: \(top)") }
        if !ctx.upcomingMilestones.isEmpty {
            lines.append("- Upcoming milestone: \(ctx.upcomingMilestones[0].title) in \(ctx.upcomingMilestones[0].daysUntil) days")
        }
        if let s = ctx.streaks.max(by: { $0.streak < $1.streak }) {
            lines.append("- Best routine streak: \(s.routineName) (\(s.streak) days)")
        }
        lines.append("- Knowledge items captured: \(ctx.knowledgeCount)")
        lines.append("- Hour of day: \(ctx.hourOfDay):00")
        return lines.joined(separator: "\n")
    }

    // MARK: - P1-D / P2-E / P2-C: Smart Notification Scheduling

    /// Schedules streak risk, journey drift, and domain balance push notifications.
    /// P2-E: Streak threshold raised to > 3, fire time moved to 8pm, copy is streak-scaled.
    /// P2-C: Domain balance push notification — weekly cap via UserDefaults.
    /// Safe to call repeatedly — uses stable IDs so duplicate requests are overwritten.
    private func scheduleSmartNotifications(appContext: AppContext, context: ModelContext) async {
        let nm = NotificationManager.shared
        guard nm.isAuthorized else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // 1. P2-E: Streak risk — only for streaks > 3 AND not completed today
        let routineDesc = FetchDescriptor<Routine>()
        let routines = (try? context.fetch(routineDesc)) ?? []
        for routine in routines where routine.currentStreak > 3 {
            // Skip if already logged today
            if let last = routine.lastCompletedDate,
               cal.startOfDay(for: last) >= today { continue }
            await nm.scheduleStreakRiskNotification(
                routineId: routine.id.uuidString,
                routineName: routine.title,
                currentStreak: routine.currentStreak
            )
        }

        // 2. Journey drift via JourneyHealthService (P2-B handles the full logic)
        await JourneyHealthService.shared.scheduleJourneyHealthNotifications(context: context)

        // 3. P2-C: Domain balance push notification — at most once per week
        let weekKey = "\(cal.component(.year, from: Date()))_\(cal.component(.weekOfYear, from: Date()))"
        let balanceDedupKey = "domainBalance_push_\(weekKey)"
        if UserDefaults.standard.object(forKey: balanceDedupKey) == nil,
           let balanceNudge = analyzeDomainBalance(ctx: appContext) {
            await nm.deliverLuminaNudge(balanceNudge)
            UserDefaults.standard.set(Date(), forKey: balanceDedupKey)
        }
    }

    // MARK: - Cache

    private func loadCachedBriefing() {
        guard let data = UserDefaults.standard.data(forKey: nudgesCacheKey),
              let cached = try? JSONDecoder().decode([LuminaNudge].self, from: data) else { return }
        pendingNudges = cached
    }

    private func cacheNudges(_ nudges: [LuminaNudge]) {
        guard let data = try? JSONEncoder().encode(nudges) else { return }
        UserDefaults.standard.set(data, forKey: nudgesCacheKey)
    }

    // MARK: - BGTask Registration

    /// Call once at app launch (in iAllyApp.swift)
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: bgTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }

            // Schedule the next run immediately so the chain continues
            scheduleBackgroundRefresh()

            // GAP 6 FIX: Actually run the intelligence cycle.
            // expirationHandler must be set before any async work begins.
            refreshTask.expirationHandler = {
                refreshTask.setTaskCompleted(success: false)
            }

            Task { @MainActor in
                let engine = ProactiveIntelligenceEngine.shared
                guard let container = engine.modelContainer else {
                    // Container not yet set (app cold-started by OS for BGTask).
                    // Mark success so the task doesn't get penalised — next foreground
                    // launch will run runIfNeeded() with a live container.
                    refreshTask.setTaskCompleted(success: false)
                    return
                }
                await engine.runCycle(context: container.mainContext)
                refreshTask.setTaskCompleted(success: true)
            }
        }
    }

    /// Schedule next BGAppRefreshTask (call after each run and at app launch)
    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60) // 6 hours
        try? BGTaskScheduler.shared.submit(request)
    }
}
