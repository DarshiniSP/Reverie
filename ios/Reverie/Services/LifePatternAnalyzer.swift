//
//  LifePatternAnalyzer.swift
//  iAlly
//
//  P3-C: Completion Velocity Tracking
//  Analyses historical task-completion data to surface velocity patterns,
//  best day-of-week, and trend direction. Requires no PAI connection.
//
//  Surfaces in:
//    • FullDailyBriefingView  — velocitySection (shows trend inline)
//    • AnalyticsDashboardView — VelocityTrendCard
//    • WeeklyReflectionService — included in Sunday report (future)
//

import Foundation
import SwiftData

// MARK: - Trend Direction

/// Whether the user is completing more, the same, or fewer tasks than before.
enum TrendDirection: String, Codable {
    case improving = "Improving"
    case stable    = "Stable"
    case declining = "Declining"

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable:    return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }

    /// Friendly colour name suitable for use with SwiftUI Color(named:) or DSColors.
    var colourKey: String {
        switch self {
        case .improving: return "green"
        case .stable:    return "orange"
        case .declining: return "red"
        }
    }
}

// MARK: - Velocity Report

/// Snapshot of completion velocity metrics for the past 4 weeks.
struct VelocityReport {
    /// Average tasks completed per calendar day over the 4-week window.
    let rollingAvgPerDay: Double
    /// Best day of week (e.g., "Tuesday"). Requires ≥ 20 completions in window.
    let bestDayOfWeek: String?
    /// Trend: comparing recent 2 weeks vs preceding 2 weeks.
    let trendDirection: TrendDirection
    /// True when there are ≥ 7 completed tasks across ≥ 2 weeks of history.
    let hasEnoughData: Bool
    /// Week-by-week completion counts, oldest first (up to 4 values).
    let weeklyCompletions: [Int]

    /// Human-readable rolling average, e.g., "1.4 tasks/day".
    var avgPerDayLabel: String {
        String(format: "%.1f tasks/day", rollingAvgPerDay)
    }
}

// MARK: - LifePatternAnalyzer

/// P3-C: Derives velocity and pattern metrics from completed task history.
/// Stateless — call `generateVelocityReport(context:)` on demand.
struct LifePatternAnalyzer {

    static let shared = LifePatternAnalyzer()
    private init() {}

    private static let daysOfWeek = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday"
    ]

    // MARK: - Public API

    /// Generate a VelocityReport from the last 28 days of task completions.
    /// Safe to call from any context; returns a graceful "no data" report if
    /// fewer than 7 tasks have been completed in the window.
    func generateVelocityReport(context: ModelContext) -> VelocityReport {
        let cal       = Calendar.current
        let today     = cal.startOfDay(for: Date())
        let fourWeeksAgo = cal.date(byAdding: .day, value: -28, to: today)!
        let twoWeeksAgo  = cal.date(byAdding: .day, value: -14, to: today)!

        // Collect completion dates within the 4-week window
        let allTasks = (try? context.fetch(FetchDescriptor<TaskWork>())) ?? []
        let completionDates: [Date] = allTasks.compactMap { task in
            guard let completed = task.completedAt, completed >= fourWeeksAgo else { return nil }
            return completed
        }

        guard completionDates.count >= 3 else {
            return VelocityReport(
                rollingAvgPerDay: 0,
                bestDayOfWeek: nil,
                trendDirection: .stable,
                hasEnoughData: false,
                weeklyCompletions: []
            )
        }

        // 4-week rolling average
        let rollingAvg = Double(completionDates.count) / 28.0

        // Bucket completions into 4 weekly buckets (oldest = index 0)
        var weekly = [0, 0, 0, 0]
        for date in completionDates {
            let daysAgo   = max(0, cal.dateComponents([.day], from: date, to: today).day ?? 0)
            let weekIndex = min(3, daysAgo / 7)   // 0 = most recent week
            weekly[3 - weekIndex] += 1             // oldest at index 0
        }

        // Enough data: ≥ 7 completions AND data exists before the most recent week
        let olderCompletions = completionDates.filter { $0 < twoWeeksAgo }
        let hasEnoughData    = completionDates.count >= 7 && !olderCompletions.isEmpty

        // Trend: recent 2 weeks vs preceding 2 weeks
        let recentTotal    = weekly[2] + weekly[3]
        let precedingTotal = weekly[0] + weekly[1]
        let trend: TrendDirection
        if precedingTotal == 0 {
            trend = .stable
        } else {
            let change = Double(recentTotal - precedingTotal) / Double(max(1, precedingTotal))
            if change >  0.15 { trend = .improving }
            else if change < -0.15 { trend = .declining }
            else { trend = .stable }
        }

        // Best day-of-week (only surfaces when ≥ 20 completions for reliability)
        var dayTotals = [Int: Int](uniqueKeysWithValues: (0...6).map { ($0, 0) })
        for date in completionDates {
            let weekday = cal.component(.weekday, from: date) - 1  // 0=Sun…6=Sat
            dayTotals[weekday, default: 0] += 1
        }
        let bestDayIndex = dayTotals.max(by: { $0.value < $1.value })?.key
        let bestDay: String? = (completionDates.count >= 20 && hasEnoughData)
            ? bestDayIndex.map { Self.daysOfWeek[$0] }
            : nil

        return VelocityReport(
            rollingAvgPerDay: rollingAvg,
            bestDayOfWeek: bestDay,
            trendDirection: trend,
            hasEnoughData: hasEnoughData,
            weeklyCompletions: weekly
        )
    }

    // MARK: - Best Time of Day

    /// Returns the hour-of-day (0–23) with the most task completions in the past 28 days.
    /// Returns nil if fewer than 10 completions exist (not enough signal).
    func bestHourOfDay(context: ModelContext) -> BestTimeInsight? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let windowStart = cal.date(byAdding: .day, value: -28, to: today)!

        let allTasks = (try? context.fetch(FetchDescriptor<TaskWork>())) ?? []
        let hours: [Int] = allTasks.compactMap { task in
            guard let completed = task.completedAt, completed >= windowStart else { return nil }
            return cal.component(.hour, from: completed)
        }

        guard hours.count >= 10 else { return nil }

        var buckets = [Int: Int]()
        for hour in hours { buckets[hour, default: 0] += 1 }

        // Find the peak 2-hour window
        var bestStart = 0
        var bestCount = 0
        for h in 0...22 {
            let count = (buckets[h] ?? 0) + (buckets[h + 1] ?? 0)
            if count > bestCount { bestCount = count; bestStart = h }
        }

        return BestTimeInsight(
            startHour: bestStart,
            endHour: bestStart + 2,
            completionCount: bestCount,
            totalCompletions: hours.count
        )
    }
}

struct BestTimeInsight {
    let startHour: Int
    let endHour: Int
    let completionCount: Int
    let totalCompletions: Int

    var rangeLabel: String {
        "\(hourLabel(startHour)) – \(hourLabel(endHour))"
    }

    var percentage: Int {
        guard totalCompletions > 0 else { return 0 }
        return Int(Double(completionCount) / Double(totalCompletions) * 100)
    }

    private func hourLabel(_ h: Int) -> String {
        let hour = h % 24
        if hour == 0 { return "12am" }
        if hour == 12 { return "12pm" }
        return hour < 12 ? "\(hour)am" : "\(hour - 12)pm"
    }
}
