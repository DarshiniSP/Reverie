//
//  AIInsightsService.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import Foundation
import SwiftData

/// AI-powered insights for productivity optimization
class AIInsightsService {
    static let shared = AIInsightsService()
    
    private init() {}
    
    // MARK: - Completion Predictions
    
    /// Predict likelihood of task completion based on historical data
    func predictCompletionLikelihood(for task: TaskWork, context: ModelContext) -> Double {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else { return 0.5 }
        
        let completedTasks = allTasks.filter { $0.completedAt != nil && !$0.isSubtask }
        guard !completedTasks.isEmpty else { return 0.5 }
        
        var score = 0.5
        var factors = 0
        
        // Factor 1: TaskWork size completion rate
        let sameSize = completedTasks.filter { $0.size == task.size }
        if !sameSize.isEmpty {
            score += Double(sameSize.count) / Double(allTasks.filter { $0.size == task.size }.count)
            factors += 1
        }
        
        // Factor 2: Has due date (tasks with due dates more likely completed)
        if task.dueDate != nil {
            let withDueDate = completedTasks.filter { $0.dueDate != nil }
            if !withDueDate.isEmpty {
                score += Double(withDueDate.count) / Double(allTasks.filter { $0.dueDate != nil }.count)
                factors += 1
            }
        }
        
        // Factor 3: Tag-based completion rate
        if let tags = task.tags, !tags.isEmpty {
            let taggedCompleted = completedTasks.filter { completedTask in
                completedTask.tags?.contains(where: { tag in tags.contains(tag) }) ?? false
            }
            if !taggedCompleted.isEmpty {
                score += Double(taggedCompleted.count) / Double(allTasks.filter { $0.tags?.isEmpty == false }.count)
                factors += 1
            }
        }
        
        return factors > 0 ? min(score / Double(factors + 1), 1.0) : 0.5
    }
    
    // MARK: - Scheduling Suggestions
    
    /// Suggest optimal schedule for tasks based on energy patterns
    func suggestOptimalSchedule(for tasks: [TaskWork], context: ModelContext) -> [ScheduleSuggestion] {
        let energyPattern = analyzeEnergyPatterns(context: context)
        var suggestions: [ScheduleSuggestion] = []
        
        for task in tasks.filter({ $0.dueDate == nil && $0.completedAt == nil }) {
            if let suggestion = suggestTimeForTaskWork(task, energyPattern: energyPattern) {
                suggestions.append(suggestion)
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func suggestTimeForTaskWork(_ task: TaskWork, energyPattern: EnergyPattern) -> ScheduleSuggestion? {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Match task size to energy level
        var suggestedHour = 9 // Default to 9 AM
        var reason = "General productivity time"
        var confidence = 0.5
        
        switch task.size {
        case .large:
            if let peakHour = energyPattern.peakHours.first {
                suggestedHour = peakHour
                reason = "Your peak energy time for large tasks"
                confidence = 0.8
            }
        case .medium:
            suggestedHour = energyPattern.peakHours.last ?? 14
            reason = "Good focus time for medium tasks"
            confidence = 0.7
        case .small:
            if let lowHour = energyPattern.lowEnergyHours.first {
                suggestedHour = lowHour
                reason = "Light tasks for low energy periods"
                confidence = 0.6
            }
        }
        
        let components = DateComponents(hour: suggestedHour, minute: 0)
        guard let suggestedDate = calendar.date(byAdding: components, to: calendar.startOfDay(for: tomorrow)) else {
            return nil
        }
        
        return ScheduleSuggestion(
            task: task,
            suggestedDate: suggestedDate,
            confidence: confidence,
            reason: reason
        )
    }
    
    // MARK: - Pattern Analysis
    
    /// Analyze user's energy patterns from completed tasks
    func analyzeEnergyPatterns(context: ModelContext) -> EnergyPattern {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else {
            return EnergyPattern(peakHours: [9, 10, 14], lowEnergyHours: [13, 15])
        }
        
        let completedTasks = allTasks.filter { $0.completedAt != nil }
        
        var hourlyEnergy: [Int: [TaskEnergy]] = [:]
        
        for task in completedTasks {
            if let completedAt = task.completedAt, let energy = task.energy {
                let hour = Calendar.current.component(.hour, from: completedAt)
                hourlyEnergy[hour, default: []].append(energy)
            }
        }
        
        // Calculate average energy per hour
        var peakHours: [Int] = []
        var lowEnergyHours: [Int] = []
        
        for hour in 6...22 { // Working hours
            let energies = hourlyEnergy[hour] ?? []
            if !energies.isEmpty {
                // Convert TaskEnergy to numeric: low=1, medium=2, high=3
                let numericValues = energies.map { energy -> Int in
                    switch energy {
                    case .low: return 1
                    case .medium: return 2
                    case .high: return 3
                    }
                }
                let avgEnergy = numericValues.reduce(0, +) / energies.count
                if avgEnergy >= 3 {
                    peakHours.append(hour)
                } else if avgEnergy <= 1 {
                    lowEnergyHours.append(hour)
                }
            }
        }
        
        // Default patterns if no data
        if peakHours.isEmpty {
            peakHours = [9, 10, 14, 15]
        }
        if lowEnergyHours.isEmpty {
            lowEnergyHours = [13, 16, 17]
        }
        
        return EnergyPattern(peakHours: peakHours, lowEnergyHours: lowEnergyHours)
    }
    
    /// Analyze productivity trends over time
    func analyzeProductivityTrends(context: ModelContext) -> ProductivityTrend {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else {
            return ProductivityTrend(
                dailyAverage: 0,
                weeklyTrend: 0,
                completionRate: 0,
                streakDays: 0
            )
        }
        
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        let recentTasks = allTasks.filter { $0.createdAt >= thirtyDaysAgo && !$0.isSubtask }
        let completedRecent = recentTasks.filter { $0.completedAt != nil }
        
        let dailyAverage = Double(completedRecent.count) / 30.0
        let completionRate = recentTasks.isEmpty ? 0 : Double(completedRecent.count) / Double(recentTasks.count)
        
        // Calculate streak - optimized to stop after first gap
        var streakDays = 0
        var checkDate = calendar.startOfDay(for: now)
        
        // Limit to 30 days check for performance
        for _ in 0..<30 {
            let dayTasks = completedRecent.filter {
                guard let completed = $0.completedAt else { return false }
                return calendar.isDate(completed, inSameDayAs: checkDate) && !$0.isSubtask
            }
            
            if dayTasks.isEmpty {
                // Streak broken
                break
            }
            
            streakDays += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        
        return ProductivityTrend(
            dailyAverage: dailyAverage,
            weeklyTrend: dailyAverage * 7,
            completionRate: completionRate,
            streakDays: streakDays
        )
    }
    
    // MARK: - Recommendations
    
    /// Generate personalized recommendations
    func generateRecommendations(context: ModelContext) -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        let descriptor = FetchDescriptor<TaskWork>()
        guard let allTasks = try? context.fetch(descriptor) else { return [] }
        
        // Recommendation 1: Break down large tasks
        let largeTasks = allTasks.filter { $0.size == .large && $0.completedAt == nil && !$0.isSubtask }
        if largeTasks.count > 3 {
            recommendations.append(Recommendation(
                type: .breakDownTasks,
                title: "Too many large tasks",
                description: "You have \(largeTasks.count) large tasks. Consider breaking them into smaller, manageable pieces.",
                action: .showLargeTasks,
                priority: .high
            ))
        }
        
        // Recommendation 2: Overdue tasks
        let overdueTasks = allTasks.filter { $0.isOverdue && !$0.isSubtask }
        if overdueTasks.count > 5 {
            recommendations.append(Recommendation(
                type: .addressOverdue,
                title: "Many overdue tasks",
                description: "\(overdueTasks.count) tasks are overdue. Review and reschedule them.",
                action: .showOverdue,
                priority: .high
            ))
        }
        
        // Recommendation 3: Life balance
        let planDescriptor = FetchDescriptor<Plan>()
        if (try? context.fetch(planDescriptor)) != nil {
            let tasksPerDomain = Dictionary(grouping: allTasks.filter { $0.completedAt == nil && !$0.isSubtask }) { $0.plan?.lifeDomain }
            let domainCounts = tasksPerDomain.mapValues { $0.count }
            
            if let max = domainCounts.values.max(), let min = domainCounts.values.min(), max > min * 3 {
                recommendations.append(Recommendation(
                    type: .balanceLifeDomains,
                    title: "Life balance opportunity",
                    description: "Some life domains have significantly more tasks than others. Consider balancing your focus.",
                    action: .showLifeBalance,
                    priority: .medium
                ))
            }
        }
        
        // Recommendation 4: Energy alignment
        let _ = analyzeEnergyPatterns(context: context)
        let unscheduledTasks = allTasks.filter { $0.dueDate == nil && $0.completedAt == nil && !$0.isSubtask }
        if unscheduledTasks.count > 10 {
            recommendations.append(Recommendation(
                type: .scheduleOptimally,
                title: "Optimize your schedule",
                description: "You have \(unscheduledTasks.count) unscheduled tasks. Let AI suggest optimal times based on your energy patterns.",
                action: .showScheduleSuggestions,
                priority: .medium
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

// MARK: - Models

struct ScheduleSuggestion: Identifiable {
    let id = UUID()
    let task: TaskWork
    let suggestedDate: Date
    let confidence: Double
    let reason: String
}

struct EnergyPattern {
    let peakHours: [Int]
    let lowEnergyHours: [Int]
}

struct ProductivityTrend {
    let dailyAverage: Double
    let weeklyTrend: Double
    let completionRate: Double
    let streakDays: Int
}

struct Recommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let action: RecommendationAction
    let priority: RecommendationPriority
}

enum RecommendationType {
    case breakDownTasks
    case addressOverdue
    case balanceLifeDomains
    case scheduleOptimally
    case createRoutine
    case reviewProgress
}

enum RecommendationAction {
    case showLargeTasks
    case showOverdue
    case showLifeBalance
    case showScheduleSuggestions
    case createRoutine
    case openWeeklyReview
}

enum RecommendationPriority: Int {
    case low = 1
    case medium = 2
    case high = 3
}
