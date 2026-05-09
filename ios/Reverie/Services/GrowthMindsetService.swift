//
//  GrowthMindsetService.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import Foundation
import SwiftData

@MainActor
class GrowthMindsetService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Event Recording
    
    func recordTaskMissed(_ task: TaskWork, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        task.missCount += 1

        let event = MindsetEvent(
            eventType: .missed,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            task: task
        )

        modelContext.insert(event)
        try? modelContext.save()
        // Feed to PAI episodic memory
        let content = "Missed task: \"\(task.title)\" (miss count: \(task.missCount))."
            + (contextNotes.map { " Context: \($0)" } ?? "")
        PAIMemoryBridge.shared.recordQuickCapture(content)
    }
    
    func recordTaskRescheduled(_ task: TaskWork, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        task.rescheduleCount += 1
        
        let event = MindsetEvent(
            eventType: .rescheduled,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            task: task
        )
        
        modelContext.insert(event)
        try? modelContext.save()
    }
    
    func recordTaskRecovered(_ task: TaskWork, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        task.recoveryCount += 1
        task.wasOverdueWhenCompleted = true
        
        let event = MindsetEvent(
            eventType: .recovered,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            task: task
        )
        
        modelContext.insert(event)
        try? modelContext.save()
    }
    
    func recordTaskAbandoned(_ task: TaskWork, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        let event = MindsetEvent(
            eventType: .abandoned,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            task: task
        )
        
        modelContext.insert(event)
        try? modelContext.save()
    }
    
    func recordTaskCompleted(_ task: TaskWork, wasOverdue: Bool, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        if wasOverdue {
            recordTaskRecovered(task, contextNotes: contextNotes, emotionalState: emotionalState)
        } else {
            let event = MindsetEvent(
                eventType: .completed,
                contextNotes: contextNotes,
                emotionalState: emotionalState,
                task: task
            )
            modelContext.insert(event)
        }

        // Update Plan learning data
        if let plan = task.plan {
            updatePlanLearningData(plan, task: task)
        }

        try? modelContext.save()
        // Feed to PAI episodic memory (builds Lumina's model of the user's productivity)
        PAIMemoryBridge.shared.recordTaskCompleted(task)
    }
    
    func recordRoutineStreakBroken(_ routine: Routine, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        routine.streakBreakCount += 1

        let event = MindsetEvent(
            eventType: .streakBroken,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            routine: routine
        )

        modelContext.insert(event)
        try? modelContext.save()
        // Feed to PAI episodic memory
        PAIMemoryBridge.shared.recordRoutineStreakBroken(routine, streak: routine.streakBreakCount)
    }
    
    func recordRoutineStreakRecovered(_ routine: Routine, contextNotes: String? = nil, emotionalState: EmotionalState? = nil) {
        routine.recoveryCount += 1
        
        let event = MindsetEvent(
            eventType: .streakRecovered,
            contextNotes: contextNotes,
            emotionalState: emotionalState,
            routine: routine
        )
        
        modelContext.insert(event)
        try? modelContext.save()
    }
    
    // MARK: - Plan Learning
    
    func updatePlanLearningData(_ plan: Plan, task: TaskWork) {
        // Track energy distribution (if energy was set)
        if let energy = task.energy {
            let energyKey = energy.rawValue
            plan.energyDistribution[energyKey, default: 0] += 1
        }
        
        // Track size distribution
        let sizeKey = task.size.rawValue
        plan.sizeDistribution[sizeKey, default: 0] += 1
        
        // Update average completion time
        if let completedAt = task.completedAt {
            let daysToComplete = Calendar.current.dateComponents([.day], from: task.createdAt, to: completedAt).day ?? 0
            
            if let currentAvg = plan.averageCompletionTime {
                let totalCompletions = plan.completedTaskCount
                plan.averageCompletionTime = ((currentAvg * Double(totalCompletions - 1)) + Double(daysToComplete)) / Double(totalCompletions)
            } else {
                plan.averageCompletionTime = Double(daysToComplete)
            }
        }
    }
    
    // MARK: - Insight Generation
    
    func generateInsights() async -> [GrowthInsight] {
        var insights: [GrowthInsight] = []
        
        // Fetch all events from last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MindsetEvent>(
            predicate: #Predicate { event in event.timestamp >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        guard let events = try? modelContext.fetch(descriptor) else {
            return insights
        }
        
        // Time pattern analysis
        if let timeInsight = analyzeTimePatterns(events: events) {
            insights.append(timeInsight)
        }
        
        // Recovery pattern analysis
        if let recoveryInsight = analyzeRecoveryPatterns(events: events) {
            insights.append(recoveryInsight)
        }
        
        // Energy pattern analysis
        if let energyInsight = analyzeEnergyPatterns() {
            insights.append(energyInsight)
        }
        
        // Motivational insights
        if let motivationalInsight = generateMotivationalInsight(events: events) {
            insights.append(motivationalInsight)
        }
        
        // Warning insights
        if let warningInsight = generateWarningInsight(events: events) {
            insights.append(warningInsight)
        }
        
        return insights
    }
    
    // MARK: - Pattern Analysis
    
    private func analyzeTimePatterns(events: [MindsetEvent]) -> GrowthInsight? {
        let calendar = Calendar.current
        var dayOfWeekCompletions: [Int: Int] = [:]
        
        let completedEvents = events.filter { $0.eventType == .completed || $0.eventType == .recovered }
        
        for event in completedEvents {
            let weekday = calendar.component(.weekday, from: event.timestamp)
            dayOfWeekCompletions[weekday, default: 0] += 1
        }
        
        guard !dayOfWeekCompletions.isEmpty else { return nil }
        
        if let bestDay = dayOfWeekCompletions.max(by: { $0.value < $1.value }) {
            let symbolIndex = bestDay.key - 1
            guard symbolIndex >= 0, symbolIndex < calendar.weekdaySymbols.count else { return nil }
            let dayName = calendar.weekdaySymbols[symbolIndex]
            let percentage = Int(Double(bestDay.value) / Double(completedEvents.count) * 100)
            
            let insightText = "You complete \(percentage)% of tasks on \(dayName)s. Consider scheduling important tasks on this day."
            
            return GrowthInsight(
                insightText: insightText,
                confidenceScore: Double(bestDay.value) / Double(completedEvents.count),
                insightType: .timePattern
            )
        }
        
        return nil
    }
    
    private func analyzeRecoveryPatterns(events: [MindsetEvent]) -> GrowthInsight? {
        let recoveries = events.filter { $0.eventType == .recovered }
        let missed = events.filter { $0.eventType == .missed }
        
        guard recoveries.count > 0, missed.count > 0 else { return nil }
        
        let recoveryRate = Double(recoveries.count) / Double(missed.count)
        
        if recoveryRate > 0.7 {
            let insightText = "Great resilience! You recover from \(Int(recoveryRate * 100))% of missed tasks. Keep bouncing back!"
            
            return GrowthInsight(
                insightText: insightText,
                confidenceScore: recoveryRate,
                insightType: .recoveryPattern
            )
        } else if recoveryRate < 0.3 {
            let insightText = "Missed tasks often stay incomplete. Try rescheduling within 24 hours to improve recovery."
            
            return GrowthInsight(
                insightText: insightText,
                confidenceScore: 1.0 - recoveryRate,
                insightType: .warning
            )
        }
        
        return nil
    }
    
    private func analyzeEnergyPatterns() -> GrowthInsight? {
        // Fetch all mindset events and filter in Swift
        let descriptor = FetchDescriptor<MindsetEvent>()
        
        guard let allEvents = try? modelContext.fetch(descriptor) else { return nil }
        
        // Filter for completed events with actual energy data
        let events = allEvents.filter { 
            $0.eventType == .completed && $0.actualEnergy != nil && $0.task != nil
        }
        
        guard events.count >= 5 else { return nil }
        
        // Analyze actual energy reported vs task size
        var energyDistribution: [TaskEnergy: Int] = [:]
        var sizeToEnergyMap: [TaskSize: [TaskEnergy]] = [:]
        
        for event in events {
            guard let actualEnergy = event.actualEnergy,
                  let task = event.task else { continue }
            
            energyDistribution[actualEnergy, default: 0] += 1
            sizeToEnergyMap[task.size, default: []].append(actualEnergy)
        }
        
        // Find most common actual energy level
        guard let mostCommon = energyDistribution.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        let percentage = Int(Double(mostCommon.value) / Double(events.count) * 100)
        
        // Check if there's a size-energy mismatch pattern
        var mismatchInsight: String?
        for (size, energies) in sizeToEnergyMap where energies.count >= 3 {
            let highEnergyCount = energies.filter { $0 == .high }.count
            let mismatchRate = Double(highEnergyCount) / Double(energies.count)
            
            if size == .small && mismatchRate > 0.5 {
                mismatchInsight = " Your small tasks often require more energy than expected."
            } else if size == .large && mismatchRate < 0.3 {
                mismatchInsight = " Large tasks are getting easier for you!"
            }
        }
        
        let insightText = "\(mostCommon.key.rawValue) energy tasks make up \(percentage)% of your completions.\(mismatchInsight ?? " Match your energy levels to task demands.")"
        
        return GrowthInsight(
            insightText: insightText,
            confidenceScore: Double(mostCommon.value) / Double(events.count),
            insightType: .energyPattern
        )
    }
    
    private func generateMotivationalInsight(events: [MindsetEvent]) -> GrowthInsight? {
        let positiveEvents = events.filter { $0.eventType.isPositive }
        
        guard positiveEvents.count >= 3 else { return nil }
        
        let streak = calculateCurrentPositiveStreak(events: events)
        
        if streak >= 3 {
            let insightText = "You're on a \(streak)-day positive streak! Momentum is building. Keep it going!"
            
            return GrowthInsight(
                insightText: insightText,
                confidenceScore: 0.9,
                insightType: .motivational
            )
        }
        
        return nil
    }
    
    private func generateWarningInsight(events: [MindsetEvent]) -> GrowthInsight? {
        let recentEvents = events.prefix(7) // Last 7 events
        let negativeCount = recentEvents.filter { !$0.eventType.isPositive }.count
        
        if Double(negativeCount) / Double(recentEvents.count) > 0.6 {
            let insightText = "Notice a pattern of incomplete tasks. Consider simplifying your schedule or adjusting expectations."
            
            return GrowthInsight(
                insightText: insightText,
                confidenceScore: 0.75,
                insightType: .warning
            )
        }
        
        return nil
    }
    
    // MARK: - AI-Powered Insight Generation

    /// Generates a narrative insight string from recent mindset events using the inference router.
    /// Falls back to an empty string when no AI provider is configured.
    /// Use this in AIInsightsView as the primary insight source — call `generateInsights()` as fallback.
    func generateAIInsights(recentTasks: [TaskWork]) async -> String {
        guard LuminaInferenceRouter.shared.isActiveProviderConfigured else { return "" }

        // Build a compact context summary to send to Lumina
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<MindsetEvent>(
            predicate: #Predicate { event in event.timestamp >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let events = try? modelContext.fetch(descriptor), !events.isEmpty else { return "" }

        let completed = events.filter { $0.eventType == .completed || $0.eventType == .recovered }.count
        let missed = events.filter { $0.eventType == .missed }.count
        let streakBroken = events.filter { $0.eventType == .streakBroken }.count
        let overdueTasks = recentTasks.filter { $0.isOverdue }.count

        let context = """
        User productivity data (last 30 days):
        - Tasks completed: \(completed)
        - Tasks missed: \(missed)
        - Routine streaks broken: \(streakBroken)
        - Currently overdue tasks: \(overdueTasks)
        - Recent task titles: \(recentTasks.prefix(5).map { $0.title }.joined(separator: ", "))
        """

        let prompt = """
        Based on this user's recent productivity data, provide 2-3 brief, specific, empathetic insights about their patterns. \
        Be encouraging but honest. Focus on actionable observations. Keep it under 100 words total.
        """

        do {
            let content = try await LuminaInferenceRouter.shared.generate(messages: [
                .system("You are Lumina, a personal life management AI. Be warm, specific, and actionable."),
                .user(context + "\n\n" + prompt)
            ])
            return content
        } catch {
            return ""
        }
    }

    // MARK: - Helper Methods

    private func calculateCurrentPositiveStreak(events: [MindsetEvent]) -> Int {
        var streak = 0
        
        for event in events {
            if event.eventType.isPositive {
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
}
