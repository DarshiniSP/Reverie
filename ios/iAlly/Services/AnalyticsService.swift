//
//  AnalyticsService.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import Foundation
import SwiftData

/// Analytics and statistics service
class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Statistics
    
    /// Get completion statistics for a time period
    func getCompletionStats(for period: TimePeriod, context: ModelContext) -> CompletionStats {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else {
            return CompletionStats(totalTasks: 0, completedTasks: 0, completionRate: 0, averageCompletionTime: 0, streakDays: 0)
        }
        
        
        let (startDate, endDate) = period.dateRange()
        
        let periodTasks = allTasks.filter { task in
            task.createdAt >= startDate && task.createdAt <= endDate
        }
        
        
        let completedTasks = periodTasks.filter { $0.completedAt != nil && !$0.isSubtask }
        
        let totalTasks = periodTasks.filter { !$0.isSubtask }.count
        let completionRate = totalTasks > 0 ? Double(completedTasks.count) / Double(totalTasks) : 0
        
        // Calculate average completion time
        var totalCompletionTime: TimeInterval = 0
        for task in completedTasks {
            if let completed = task.completedAt {
                totalCompletionTime += completed.timeIntervalSince(task.createdAt)
            }
        }
        let averageCompletionTime = completedTasks.isEmpty ? 0 : totalCompletionTime / Double(completedTasks.count)
        
        // Calculate streak
        let streakDays = calculateStreak(from: allTasks)
        
        return CompletionStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks.count,
            completionRate: completionRate,
            averageCompletionTime: averageCompletionTime,
            streakDays: streakDays
        )
    }
    
    /// Get productivity score for a period
    func getProductivityScore(for period: TimePeriod, context: ModelContext) -> Double {
        let stats = getCompletionStats(for: period, context: context)
        
        // Adjust expectations based on period
        let (expectedTasks, expectedStreak) = period.expectedMetrics()
        
        // Weighted score based on multiple factors
        let completionScore = stats.completionRate * 0.4
        let volumeScore = min(Double(stats.completedTasks) / Double(expectedTasks), 1.0) * 0.3
        let streakScore = min(Double(stats.streakDays) / Double(expectedStreak), 1.0) * 0.3
        
        let finalScore = (completionScore + volumeScore + streakScore) * 100
        
        
        return finalScore
    }
    
    /// Get life balance score across domains
    func getLifeBalanceScore(context: ModelContext) -> LifeBalanceScore {
        let taskDescriptor = FetchDescriptor<TaskWork>()
        
        guard let tasks = try? context.fetch(taskDescriptor) else {
            return LifeBalanceScore(scores: [:], overallScore: 0, recommendations: [])
        }
        
        let recentTasks = tasks.filter { task in
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return task.createdAt >= thirtyDaysAgo
        }
        
        var domainScores: [LifeDomain: Double] = [:]
        
        for domain in LifeDomain.allCases {
            let domainTasks = recentTasks.filter { $0.plan?.lifeDomain == domain }
            let completedDomainTasks = domainTasks.filter { $0.completedAt != nil }
            
            let score = domainTasks.isEmpty ? 0 : Double(completedDomainTasks.count) / Double(domainTasks.count)
            domainScores[domain] = score
        }
        
        let overallScore = domainScores.values.reduce(0, +) / Double(LifeDomain.allCases.count)
        
        // Generate recommendations
        var recommendations: [String] = []
        for (domain, score) in domainScores {
            if score < 0.3 {
                recommendations.append("Focus more on \(domain.rawValue)")
            }
        }
        
        return LifeBalanceScore(
            scores: domainScores,
            overallScore: overallScore,
            recommendations: recommendations
        )
    }
    
    // MARK: - Trends
    
    /// Get completion trend over time
    func getCompletionTrend(for period: TimePeriod, context: ModelContext) -> [DataPoint] {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else { return [] }
        
        let (startDate, endDate) = period.dateRange()
        let calendar = Calendar.current
        var dataPoints: [DataPoint] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayTasks = allTasks.filter { task in
                guard let completed = task.completedAt else { return false }
                return calendar.isDate(completed, inSameDayAs: currentDate)
            }
            
            dataPoints.append(DataPoint(date: currentDate, value: Double(dayTasks.count)))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    /// Get energy trend over time
    func getEnergyTrend(for period: TimePeriod, context: ModelContext) -> [DataPoint] {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else { return [] }
        
        let (startDate, endDate) = period.dateRange()
        let calendar = Calendar.current
        var dataPoints: [DataPoint] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayTasks = allTasks.filter { task in
                guard let completed = task.completedAt else { return false }
                return calendar.isDate(completed, inSameDayAs: currentDate)
            }
            
            // Convert energy to numeric: low=1, medium=2, high=3
            let energyValues = dayTasks.compactMap { task -> Double? in
                guard let energy = task.energy else { return nil }
                switch energy {
                case .low: return 1.0
                case .medium: return 2.0
                case .high: return 3.0
                }
            }
            let avgEnergy = energyValues.isEmpty ? 0 : energyValues.reduce(0, +) / Double(energyValues.count)
            
            dataPoints.append(DataPoint(date: currentDate, value: avgEnergy))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    /// Get task size distribution
    func getSizeDistribution(for period: TimePeriod, context: ModelContext) -> [SizeDataPoint] {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else { return [] }
        
        let (startDate, endDate) = period.dateRange()
        let periodTasks = allTasks.filter { $0.createdAt >= startDate && $0.createdAt <= endDate }
        
        var distribution: [TaskSize: Int] = [:]
        for task in periodTasks.filter({ $0.completedAt != nil && !$0.isSubtask }) {
            distribution[task.size, default: 0] += 1
        }
        
        return TaskSize.allCases.map { size in
            SizeDataPoint(size: size, count: distribution[size] ?? 0)
        }
    }
    
    // MARK: - Export
    
    /// Export analytics report
    func exportReport(for period: TimePeriod, context: ModelContext) -> ReportData {
        let stats = getCompletionStats(for: period, context: context)
        let productivityScore = getProductivityScore(for: period, context: context)
        let lifeBalance = getLifeBalanceScore(context: context)
        let completionTrend = getCompletionTrend(for: period, context: context)
        let sizeDistribution = getSizeDistribution(for: period, context: context)
        
        return ReportData(
            period: period,
            stats: stats,
            productivityScore: productivityScore,
            lifeBalance: lifeBalance,
            completionTrend: completionTrend,
            sizeDistribution: sizeDistribution,
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Helpers
    
    private func calculateStreak(from tasks: [TaskWork]) -> Int {
        let calendar = Calendar.current
        var streakDays = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        for _ in 0..<365 {
            let dayTasks = tasks.filter { task in
                guard let completed = task.completedAt else { return false }
                return calendar.isDate(completed, inSameDayAs: checkDate)
            }
            
            if dayTasks.isEmpty {
                break
            }
            
            streakDays += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return streakDays
    }
}

// MARK: - Models

enum TimePeriod: Hashable, Equatable {
    case today
    case week
    case month
    case year
    case custom(start: Date, end: Date)
    
    func dateRange() -> (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return (start, end)
            
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? now
            return (start, end)
            
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            return (start, end)
            
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? now
            return (start, end)
            
        case .custom(let start, let end):
            return (start, end)
        }
    }
    
    /// Expected metrics for productivity score calculation
    /// Returns (expectedCompletedTasks, expectedStreakDays)
    func expectedMetrics() -> (Int, Int) {
        switch self {
        case .today:
            return (3, 1)  // Expect 3 tasks completed today, 1 day streak
        case .week:
            return (15, 7)  // Expect 15 tasks in a week, 7 day streak
        case .month:
            return (50, 30)  // Expect 50 tasks in a month, 30 day streak
        case .year:
            return (500, 365)  // Expect 500 tasks in a year, 365 day streak
        case .custom(let start, let end):
            let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1
            return (days * 2, days)  // Expect 2 tasks per day for custom range
        }
    }
}

struct CompletionStats {
    let totalTasks: Int
    let completedTasks: Int
    let completionRate: Double
    let averageCompletionTime: TimeInterval
    let streakDays: Int
}

struct LifeBalanceScore {
    let scores: [LifeDomain: Double]
    let overallScore: Double
    let recommendations: [String]
}

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct SizeDataPoint: Identifiable {
    let id = UUID()
    let size: TaskSize
    let count: Int
}

struct ReportData {
    let period: TimePeriod
    let stats: CompletionStats
    let productivityScore: Double
    let lifeBalance: LifeBalanceScore
    let completionTrend: [DataPoint]
    let sizeDistribution: [SizeDataPoint]
    let generatedAt: Date
}
