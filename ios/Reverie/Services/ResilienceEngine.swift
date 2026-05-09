//
//  ResilienceEngine.swift
//  Reverie
//
//  Computes two key wellbeing metrics from on-device behavioural data.
//
//  ─────────────────────────────────────────────────────────────────
//  DESIGN PHILOSOPHY
//  ─────────────────────────────────────────────────────────────────
//  Unlike Sanchana (which requires the user to log their state),
//  Reverie infers resilience from what the user *does* — or stops
//  doing. A student heading toward burnout is precisely the person
//  least likely to fill in a mood survey. The score therefore runs
//  on passive behavioural signals as its primary engine:
//
//    • Routine adherence   — are daily anchors still holding?
//    • Load balance        — is overdue pressure accumulating?
//    • Consistency         — have there been active days this week?
//    • Engagement trend    — is this week better or worse than last?
//
//  The daily check-in (mood + energy) is an *optional* 20% modifier
//  that sharpens the score when available. When absent, the four
//  behavioural signals carry the full 100% weight. The index is
//  always meaningful, regardless of whether the user opened the app
//  to report how they feel.
//
//  ─────────────────────────────────────────────────────────────────
//  1. RESILIENCE INDEX (0–100)
//  ─────────────────────────────────────────────────────────────────
//  With check-in:
//    R = 0.20×mood + 0.25×anchors + 0.25×load + 0.20×consistency + 0.10×trend
//
//  Without check-in (weights renormalised to sum to 1.0):
//    R = 0.3125×anchors + 0.3125×load + 0.25×consistency + 0.125×trend
//
//  Conceptual basis: Maslach Burnout Inventory (Maslach & Jackson, 1981)
//  — exhaustion ↔ loadBalance, disengagement ↔ engagementTrend,
//    reduced efficacy ↔ consistency + routineAdherence.
//
//  ─────────────────────────────────────────────────────────────────
//  2. COGNITIVE LOAD INDEX
//  ─────────────────────────────────────────────────────────────────
//  raw = complexity + contextSwitchPenalty + overdueCount × 1.5
//  Based on Sweller's Cognitive Load Theory (1988).
//

import Foundation
import SwiftData

// MARK: - Resilience types

enum ResilienceLevel: String {
    case thriving = "Thriving"
    case steady   = "Steady"
    case strained = "Strained"
    case critical = "Critical"

    var colorHex: String {
        switch self {
        case .thriving: return "5C8A6E"
        case .steady:   return "7A8A5C"
        case .strained: return "F59E0B"
        case .critical: return "EF4444"
        }
    }

    var icon: String {
        switch self {
        case .thriving: return "heart.fill"
        case .steady:   return "heart"
        case .strained: return "heart.slash"
        case .critical: return "exclamationmark.heart.fill"
        }
    }

    var message: String {
        switch self {
        case .thriving: return "You're in a strong rhythm. Keep it going."
        case .steady:   return "Solid foundation. Small wins add up."
        case .strained: return "Signs of strain detected. Consider a lighter day."
        case .critical: return "Signals suggest you may be stretched thin. It's okay to reach out."
        }
    }

    var shortMessage: String {
        switch self {
        case .thriving: return "Strong rhythm — keep it going"
        case .steady:   return "Solid foundation"
        case .strained: return "Signs of strain — consider a lighter day"
        case .critical: return "Stretched thin — it's okay to reach out"
        }
    }
}

struct ResilienceComponents {
    /// Wellbeing proxy from check-in (mood + energy). nil when no check-in today.
    let wellbeing: Double?
    /// Routine tasks completed vs. scheduled this week (0–1). Passive signal.
    let routineAdherence: Double
    /// Inverse of overdue accumulation pressure (0–1). Passive signal.
    let loadBalance: Double
    /// Proportion of last 7 days with any completed task (0–1). Passive signal.
    let consistency: Double
    /// Week-over-week completion trend: this week vs. last week (0–1). Passive signal.
    let engagementTrend: Double
}

struct ResilienceScore {
    let value: Double                    // 0–100
    let level: ResilienceLevel
    let components: ResilienceComponents
    /// True when today's check-in data contributed to the score.
    let checkInContributing: Bool
    let computedAt: Date
}

// MARK: - Cognitive Load types

enum CognitiveLoadLevel: String {
    case light      = "Light"
    case moderate   = "Moderate"
    case heavy      = "Heavy"
    case overloaded = "Overloaded"

    var colorHex: String {
        switch self {
        case .light:      return "5C8A6E"
        case .moderate:   return "7A8A5C"
        case .heavy:      return "F59E0B"
        case .overloaded: return "EF4444"
        }
    }

    var icon: String {
        switch self {
        case .light:      return "brain"
        case .moderate:   return "brain"
        case .heavy:      return "brain.head.profile"
        case .overloaded: return "exclamationmark.triangle.fill"
        }
    }

    var advice: String {
        switch self {
        case .light:      return "Your mind has room today. Use it well."
        case .moderate:   return "Manageable — prioritise and pace yourself."
        case .heavy:      return "Consider deferring non-urgent tasks."
        case .overloaded: return "Too much in scope. Protect your focus — it's okay to say no."
        }
    }
}

struct CognitiveLoad {
    let rawScore: Double
    let level: CognitiveLoadLevel
    let taskCount: Int
    let activeDomains: Int
    let overdueCount: Int
}

// MARK: - Engine

final class ResilienceEngine {

    static let shared = ResilienceEngine()
    private init() {}

    // MARK: - Resilience Index

    /// Compute the current Resilience Index.
    ///
    /// Always returns a meaningful score even when no check-in has been recorded
    /// today. The four passive behavioural signals carry 100% of the weight in
    /// that case; the check-in shifts them to 80% and contributes 20%.
    func compute(context: ModelContext) -> ResilienceScore {
        let calendar = Calendar.current
        let today      = calendar.startOfDay(for: Date())
        let sevenAgo   = calendar.date(byAdding: .day, value: -7,  to: today)!
        let fourteenAgo = calendar.date(byAdding: .day, value: -14, to: today)!

        let allTasks: [TaskWork] = (try? context.fetch(FetchDescriptor<TaskWork>())) ?? []

        // ── 1. Routine Adherence (passive) ────────────────────────────────────
        // Tasks generated from a routine, scheduled in the last 7 days.
        let weekRoutines = allTasks.filter { task in
            guard task.routine != nil, let due = task.dueDate else { return false }
            return due >= sevenAgo && due <= Date()
        }
        let routineAdherence: Double = weekRoutines.isEmpty
            ? 0.65   // no routines set up → neutral, not penalised
            : Double(weekRoutines.filter { $0.isCompleted }.count) / Double(weekRoutines.count)

        // ── 2. Load Balance (passive) ─────────────────────────────────────────
        // Inverse of the proportion of active tasks that are overdue.
        let activeTasks = allTasks.filter { !$0.isCompleted && !$0.isSubtask }
        let overdueCount = activeTasks.filter { t in
            guard let due = t.dueDate else { return false }
            return due < Date()
        }.count
        let overdueRatio = activeTasks.isEmpty
            ? 0.0
            : min(1.0, Double(overdueCount) / max(1.0, Double(activeTasks.count)))
        let loadBalance = 1.0 - overdueRatio

        // ── 3. Consistency (passive) ──────────────────────────────────────────
        // Proportion of the last 7 days on which the user completed at least one task.
        let recentDone = allTasks.filter { t in
            guard let done = t.completedAt else { return false }
            return done >= sevenAgo
        }
        let activeDays = Set(recentDone.compactMap {
            calendar.startOfDay(for: $0.completedAt!)
        }).count
        let consistency = min(1.0, Double(activeDays) / 7.0)

        // ── 4. Engagement Trend (passive) ─────────────────────────────────────
        // Week-over-week comparison: is the user more or less productive than last week?
        // Declining completion rate is an early disengagement signal per Maslach (1981).
        let thisWeekCount = allTasks.filter { t in
            guard let done = t.completedAt else { return false }
            return done >= sevenAgo
        }.count
        let lastWeekCount = allTasks.filter { t in
            guard let done = t.completedAt else { return false }
            return done >= fourteenAgo && done < sevenAgo
        }.count

        let engagementTrend: Double = {
            if thisWeekCount == 0 && lastWeekCount == 0 { return 0.5 }  // no history — neutral
            if lastWeekCount == 0 { return 1.0 }                         // active for first time
            // ratio: 1.0 = same as last week, 2.0 = double, 0.5 = half
            return min(1.0, Double(thisWeekCount) / Double(lastWeekCount))
        }()

        // ── 5. Wellbeing (optional check-in modifier) ─────────────────────────
        // Only used when today's check-in has been recorded.
        let stress  = StressCheckInStore.load()
        let energy  = EnergyCheckInStore.load()
        let hasCheckIn = stress != nil || energy != nil
        let wellbeing: Double? = hasCheckIn
            ? computeWellbeing(stress: stress, energy: energy)
            : nil

        // ── Composite formula ──────────────────────────────────────────────────
        let raw: Double
        if let wb = wellbeing {
            // Check-in available: 5-signal formula
            raw = (0.20 * wb)
                + (0.25 * routineAdherence)
                + (0.25 * loadBalance)
                + (0.20 * consistency)
                + (0.10 * engagementTrend)
        } else {
            // Behavioural signals only — renormalised weights (÷ 0.80)
            // anchors: 0.25/0.80 = 0.3125
            // load:    0.25/0.80 = 0.3125
            // consist: 0.20/0.80 = 0.2500
            // trend:   0.10/0.80 = 0.1250
            raw = (0.3125 * routineAdherence)
                + (0.3125 * loadBalance)
                + (0.2500 * consistency)
                + (0.1250 * engagementTrend)
        }

        let value = (raw * 100.0).rounded()

        let level: ResilienceLevel
        switch value {
        case 75...:    level = .thriving
        case 50..<75:  level = .steady
        case 30..<50:  level = .strained
        default:       level = .critical
        }

        return ResilienceScore(
            value: value,
            level: level,
            components: ResilienceComponents(
                wellbeing:        wellbeing,
                routineAdherence: routineAdherence,
                loadBalance:      loadBalance,
                consistency:      consistency,
                engagementTrend:  engagementTrend
            ),
            checkInContributing: hasCheckIn,
            computedAt: Date()
        )
    }

    // MARK: - Cognitive Load Index

    /// Today's cognitive load (Sweller 1988).
    func cognitiveLoad(context: ModelContext) -> CognitiveLoad {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        let allTasks: [TaskWork] = (try? context.fetch(FetchDescriptor<TaskWork>())) ?? []

        // Tasks in scope: overdue + due today, incomplete
        let inScope = allTasks.filter { task in
            guard !task.isCompleted, !task.isSubtask, let due = task.dueDate else { return false }
            return due < tomorrow
        }

        // Complexity: weighted by task size (Sweller's element interactivity)
        let complexity = inScope.reduce(0.0) { sum, task in
            switch task.size {
            case .small:  return sum + 1.0
            case .medium: return sum + 2.0
            case .large:  return sum + 3.5
            }
        }

        // Context-switch penalty: cost of switching between life domains
        let domains = Set(inScope.compactMap { $0.plan?.lifeDomain }).count
        let switchPenalty = Double(max(0, domains - 2)) * 2.0

        // Overdue pressure
        let overdueToday = inScope.filter { t in
            guard let due = t.dueDate else { return false }
            return due < today
        }.count

        let raw = complexity + switchPenalty + Double(overdueToday) * 1.5

        let level: CognitiveLoadLevel
        switch raw {
        case 0..<5:   level = .light
        case 5..<12:  level = .moderate
        case 12..<20: level = .heavy
        default:      level = .overloaded
        }

        return CognitiveLoad(
            rawScore: raw,
            level: level,
            taskCount: inScope.count,
            activeDomains: domains,
            overdueCount: overdueToday
        )
    }

    // MARK: - Helpers

    private func computeWellbeing(stress: DailyStressLevel?, energy: DailyEnergyLevel?) -> Double {
        let s: Double = switch stress {
            case .calm:     1.0
            case .moderate: 0.5
            case .high:     0.15
            case .none:     0.6   // only reached when stress is nil but energy was set
        }
        let e: Double = switch energy {
            case .high:   1.0
            case .medium: 0.65
            case .low:    0.3
            case .none:   0.6
        }
        // Stress weighted slightly higher than energy as burnout predictor
        return (s * 0.6) + (e * 0.4)
    }
}
