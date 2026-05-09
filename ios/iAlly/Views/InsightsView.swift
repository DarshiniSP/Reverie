//
//  InsightsView.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allTasks: [TaskWork]
    @Query private var allRoutines: [Routine]
    @Query private var allJourneys: [Journey]
    
    @State private var selectedTimeframe: TimeFrame = .week
    
    enum TimeFrame: String, CaseIterable {
        case today = "Today"
        case week = "Week"
        case month = "Month"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Time filter
                    timeframePicker
                    
                    // Actionable Insights (NEW)
                    actionableInsightsSection
                    
                    // Task Statistics
                    taskStatsSection
                    
                    // Routine Performance
                    routineStatsSection
                    
                    // Goal Progress
                    goalStatsSection
                    
                    // Energy Analysis
                    energyAnalysisSection
                }
                .padding()
            }
            .background(DSColors.canvasPrimary)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Timeframe Picker
    
    private var timeframePicker: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(TimeFrame.allCases, id: \.self) { frame in
                Text(frame.rawValue).tag(frame)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    // MARK: - Actionable Insights
    
    private var actionableInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actionable Insights", systemImage: "lightbulb.fill")
                .font(DSFonts.headline())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            let insights = generateActionableInsights()
            
            if insights.isEmpty {
                ActionableInsightCard(
                    title: "Great Work!",
                    message: "You're doing well across all areas. Keep up the momentum!",
                    icon: "star.fill",
                    color: DSColors.success,
                    actionLabel: nil,
                    action: nil
                )
            } else {
                ForEach(insights.indices, id: \.self) { index in
                    insights[index]
                }
            }
        }
    }
    
    // MARK: - Task Statistics
    
    private var taskStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Statistics")
                .font(DSFonts.headline())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            let stats = calculateTaskStats()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Tasks")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.total)")
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.textPrimary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(stats.completed)")
                                .font(DSFonts.title(28))
                                .foregroundColor(DSColors.success)
                            Text(stats.total > 0 ? "\(Int(Double(stats.completed) / Double(stats.total) * 100))%" : "0%")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.success.opacity(0.8))
                        }
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overdue")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.overdue)")
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.error)
                    }
                }
                
                Divider()
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.thisWeek)")
                            .font(DSFonts.headline(24))
                            .foregroundColor(DSColors.warning)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inbox")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.inbox)")
                            .font(DSFonts.headline(24))
                            .foregroundColor(DSColors.accentSecondary)
                    }
                }
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
    
    // MARK: - Routine Statistics
    
    private var routineStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Routine Performance")
                .font(DSFonts.headline())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            let stats = calculateRoutineStats()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Routines")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.active)")
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg Streak")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text(stats.avgStreak)
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.warning)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completion")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text(stats.completionRate)
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.success)
                    }
                }
                
                if stats.longestStreak > 0 {
                    Divider()
                    
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(DSFonts.headline())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Longest Streak")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            Text("\(stats.longestStreak) days")
                                .font(DSFonts.headline(20))
                                .foregroundColor(DSColors.textPrimary)
                            if !stats.longestRoutineName.isEmpty {
                                Text(stats.longestRoutineName)
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
    
    // MARK: - Goal Statistics
    
    private var goalStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Journey Progress") // Changed from Goal
                .font(DSFonts.headline())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            let stats = calculateGoalStats()
            
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Journeys") // Changed from Active Goals
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.active)")
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    
                    Divider()
                        .frame(height: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Completed")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        Text("\(stats.completed)")
                            .font(DSFonts.title(28))
                            .foregroundColor(DSColors.success)
                    }
                }
                
                if stats.totalMilestones > 0 {
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Milestone Progress")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(stats.completedMilestones)/\(stats.totalMilestones)")
                                    .font(DSFonts.headline(24))
                                    .foregroundColor(DSColors.accentSecondary)
                                Text("\(Int(Double(stats.completedMilestones) / Double(stats.totalMilestones) * 100))% complete")
                                    .font(DSFonts.caption())
                                    .foregroundColor(.purple.opacity(0.8))
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
    
    // MARK: - Energy Analysis
    
    private var energyAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Analysis")
                .font(DSFonts.headline())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            let analysis = calculateEnergyAnalysis()
            
            VStack(spacing: 8) {
                EnergyBar(
                    label: "High Energy",
                    completed: analysis.high.completed,
                    total: analysis.high.total,
                    color: DSColors.error
                )
                
                EnergyBar(
                    label: "Medium Energy",
                    completed: analysis.medium.completed,
                    total: analysis.medium.total,
                    color: DSColors.warning
                )
                
                EnergyBar(
                    label: "Low Energy",
                    completed: analysis.low.completed,
                    total: analysis.low.total,
                    color: DSColors.success
                )
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
    
    // MARK: - Calculations
    
    private func calculateTaskStats() -> (total: Int, completed: Int, overdue: Int, thisWeek: Int, inbox: Int) {
        let filtered = filterTasksByTimeframe(allTasks)
        let completed = filtered.filter { $0.isCompleted }.count
        let overdue = filtered.filter { $0.isOverdue }.count
        
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        let thisWeek = filtered.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= weekStart && dueDate < weekEnd
        }.count
        
        let inbox = filtered.filter { $0.plan == nil && $0.journey == nil }.count
        
        return (filtered.count, completed, overdue, thisWeek, inbox)
    }
    
    private func calculateRoutineStats() -> (active: Int, avgStreak: String, completionRate: String, longestStreak: Int, longestRoutineName: String) {
        let active = allRoutines.filter { $0.isActive }.count
        
        guard !allRoutines.isEmpty else {
            return (0, "0", "0%", 0, "")
        }
        
        let totalStreak = allRoutines.reduce(0) { $0 + $1.currentStreak }
        let avgStreak = allRoutines.count > 0 ? totalStreak / allRoutines.count : 0
        
        // Calculate completion rate based on recent routine tasks
        let now = Date()
        let startDate = getStartDateForTimeframe()
        
        let routineTasks = allTasks.filter { task in
            guard task.isRecurring, let scheduledDate = task.scheduledDate else { return false }
            return scheduledDate >= startDate && scheduledDate <= now
        }
        
        let completedRoutineTasks = routineTasks.filter { $0.isCompleted }.count
        let completionRate = routineTasks.count > 0 ? Int(Double(completedRoutineTasks) / Double(routineTasks.count) * 100) : 0
        
        let longestStreak = allRoutines.map { $0.currentStreak }.max() ?? 0
        let longestRoutine = allRoutines.first(where: { $0.currentStreak == longestStreak })
        
        return (active, "\(avgStreak)", "\(completionRate)%", longestStreak, longestRoutine?.title ?? "")
    }
    
    private func calculateGoalStats() -> (active: Int, completed: Int, totalMilestones: Int, completedMilestones: Int) {
        let activeGoals = allJourneys.filter { journey in
            guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
            let completed = milestones.filter { $0.isCompleted }.count
            return completed > 0 && completed < milestones.count
        }.count
        
        let completedGoals = allJourneys.filter { journey in
            guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
            return milestones.allSatisfy { $0.isCompleted }
        }.count
        
        let allMilestones = allJourneys.flatMap { $0.milestones ?? [] }
        let totalMilestones = allMilestones.count
        let completedMilestones = allMilestones.filter { $0.isCompleted }.count
        
        return (activeGoals, completedGoals, totalMilestones, completedMilestones)
    }
    
    private func calculateEnergyAnalysis() -> (high: (completed: Int, total: Int), medium: (completed: Int, total: Int), low: (completed: Int, total: Int)) {
        let filtered = filterTasksByTimeframe(allTasks)
        
        let highTasks = filtered.filter { $0.energy == .high }
        let highCompleted = highTasks.filter { $0.isCompleted }.count
        
        let mediumTasks = filtered.filter { $0.energy == .medium }
        let mediumCompleted = mediumTasks.filter { $0.isCompleted }.count
        
        let lowTasks = filtered.filter { $0.energy == .low }
        let lowCompleted = lowTasks.filter { $0.isCompleted }.count
        
        return (
            high: (highCompleted, highTasks.count),
            medium: (mediumCompleted, mediumTasks.count),
            low: (lowCompleted, lowTasks.count)
        )
    }
    
    private func filterTasksByTimeframe(_ tasks: [TaskWork]) -> [TaskWork] {
        let startDate = getStartDateForTimeframe()
        let now = Date()
        
        return tasks.filter { task in
            // Include if created in timeframe OR has due date in timeframe
            let createdInRange = task.createdAt >= startDate && task.createdAt <= now
            let dueInRange = task.dueDate.map { $0 >= startDate && $0 <= now } ?? false
            return createdInRange || dueInRange
        }
    }
    
    private func getStartDateForTimeframe() -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return Date(timeIntervalSince1970: 0)
        }
    }
    
    private func generateActionableInsights() -> [ActionableInsightCard] {
        var insights: [ActionableInsightCard] = []
        
        let taskStats = calculateTaskStats()
        let routineStats = calculateRoutineStats()
        let goalStats = calculateGoalStats()
        
        // Check for overdue tasks
        if taskStats.overdue > 0 {
            insights.append(
                ActionableInsightCard(
                    title: "Overdue Tasks Need Attention",
                    message: "You have \(taskStats.overdue) overdue task\(taskStats.overdue == 1 ? "" : "s"). Consider rescheduling or breaking them into smaller steps.",
                    icon: "exclamationmark.triangle.fill",
                    color: DSColors.error,
                    actionLabel: "Review Tasks",
                    action: nil
                )
            )
        }
        
        // Check for inbox backlog
        if taskStats.inbox > 5 {
            insights.append(
                ActionableInsightCard(
                    title: "Organize Your Inbox",
                    message: "You have \(taskStats.inbox) unorganized tasks. Assign them to plans or goals to stay focused.",
                    icon: "tray.fill",
                    color: DSColors.warning,
                    actionLabel: "Organize Inbox",
                    action: nil
                )
            )
        }
        
        // Check routine consistency
        if let completionRate = Int(routineStats.completionRate.replacingOccurrences(of: "%", with: "")), completionRate < 70 {
            insights.append(
                ActionableInsightCard(
                    title: "Routine Consistency Low",
                    message: "Your routine completion is at \(completionRate)%. Try setting reminders or reducing the frequency temporarily.",
                    icon: "repeat.circle",
                    color: DSColors.warning,
                    actionLabel: "Adjust Routines",
                    action: nil
                )
            )
        }
        
        // Check for stagnant goals
        if goalStats.active > 0 && goalStats.totalMilestones > 0 {
            let progressPercent = Int(Double(goalStats.completedMilestones) / Double(goalStats.totalMilestones) * 100)
            if progressPercent < 20 {
                insights.append(
                    ActionableInsightCard(
                        title: "Journeys Need Progress", // Changed from Goals
                        message: "Your journeys are at \(progressPercent)% completion. Break down the next milestone into smaller tasks.", // Changed from goals
                        icon: "flag.fill",
                        color: DSColors.accentPrimary,
                        actionLabel: "Review Journeys", // Changed from Review Goals
                        action: nil
                    )
                )
            }
        }
        
        // Positive reinforcement for streaks
        if routineStats.longestStreak >= 7 {
            insights.append(
                ActionableInsightCard(
                    title: "Amazing Streak!",
                    message: "You've maintained a \(routineStats.longestStreak)-day streak with '\(routineStats.longestRoutineName)'. Keep it going!",
                    icon: "flame.fill",
                    color: DSColors.success,
                    actionLabel: nil,
                    action: nil
                )
            )
        }
        
        // Check task completion rate
        if taskStats.total > 0 {
            let completionPercent = Int(Double(taskStats.completed) / Double(taskStats.total) * 100)
            if completionPercent >= 80 {
                insights.append(
                    ActionableInsightCard(
                        title: "Excellent Productivity!",
                        message: "You've completed \(completionPercent)% of your tasks. You're crushing your journeys!", // Changed from goals
                        icon: "checkmark.seal.fill",
                        color: DSColors.success,
                        actionLabel: nil,
                        action: nil
                    )
                )
            }
        }
        
        return insights
    }
}

// MARK: - Supporting Views

struct InsightStatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(DSFonts.headline())
                Spacer()
            }
            
            Text(value)
                .font(DSFonts.title())
                .bold()
                .foregroundColor(DSColors.textPrimary)
            
            Text(title)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct EnergyBar: View {
    let label: String
    let completed: Int
    let total: Int
    let color: Color
    
    private var percentage: Double {
        total > 0 ? Double(completed) / Double(total) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                Text("(\(Int(percentage * 100))%)")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct ActionableInsightCard: View {
    let title: String
    let message: String
    let icon: String
    let color: Color
    let actionLabel: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(DSFonts.headline())
                    .foregroundColor(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.15))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text(message)
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            
            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(DSFonts.label())
                        .fontWeight(.medium)
                        .foregroundColor(DSColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(color)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: [TaskWork.self, Routine.self, Journey.self], inMemory: true)
}
