//
//  AIInsightsView.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import SwiftUI
import SwiftData

struct AIInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskWork]

    @State private var recommendations: [Recommendation] = []
    @State private var energyPattern: EnergyPattern?
    @State private var productivityTrend: ProductivityTrend?
    @State private var isLoading = true

    // Phase 3: Living PAI Insights
    @State private var livingInsights: [PAIInsight] = []
    @State private var isLoadingPAI = false

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Analyzing your patterns...")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 100)
            } else {
                VStack(spacing: 20) {
                    // Phase 3: Living PAI Insights (top section)
                    LivingInsightsSection(
                        insights: livingInsights,
                        isLoading: isLoadingPAI
                    )
                    .padding(.horizontal)

                    // Header - Personalized
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DSColors.accentPrimary.opacity(0.1))
                                .frame(width: 80, height: 80)

                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40))
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityHidden(true)

                        Text("AI Insights")
                            .font(DSFonts.title())
                            .foregroundColor(DSColors.textPrimary)

                        Text(insightsSummary)
                            .font(DSFonts.body(15))
                            .foregroundColor(DSColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    
                    // Productivity Trend - Enhanced with Gauge
                    if let trend = productivityTrend {
                        ProductivityGaugeCard(trend: trend)
                            .padding(.horizontal)
                    }
                    
                    // Energy Pattern - Interactive Timeline
                    if let pattern = energyPattern {
                        EnergyTimelineCard(pattern: pattern)
                            .padding(.horizontal)
                    }
                    
                    // Recommendations
                    if !recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommendations")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.textPrimary)
                                .padding(.horizontal)
                            
                            ForEach(recommendations) { recommendation in
                                RecommendationCard(recommendation: recommendation)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Schedule Suggestions
                    ScheduleSuggestionsSection(tasks: tasks, modelContext: modelContext)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("AI Insights")
        .onAppear {
            loadInsights()
            Task { await loadLivingInsights() }
        }
    }

    // MARK: - Lumina AI observation synthesised from local analytics

    private func loadLivingInsights() async {
        let router = LuminaInferenceRouter.shared
        guard router.isConfigured(router.selectedProviderID) else { return }

        // Wait for local insights to finish loading so prompt has real data
        var waited = 0
        while isLoading && waited < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        isLoadingPAI = true

        let trendDesc: String
        if let trend = productivityTrend {
            trendDesc = "Completion rate: \(Int(trend.completionRate * 100))%, daily avg: \(String(format: "%.1f", trend.dailyAverage)) tasks, streak: \(trend.streakDays) days"
        } else {
            trendDesc = "Insufficient data yet"
        }

        let energyDesc: String
        if let pattern = energyPattern, !pattern.peakHours.isEmpty {
            let peaks = pattern.peakHours.map { "\($0)h" }.joined(separator: ", ")
            energyDesc = "Peak hours: \(peaks)"
        } else {
            energyDesc = "No energy pattern data"
        }

        let topRec = recommendations.first?.title ?? "none"

        let prompt = """
        You are Lumina. Based on this user's productivity data, write ONE concise observation (max 25 words). Be specific, encouraging, and actionable.
        Data: \(trendDesc). \(energyDesc). Top recommendation area: \(topRec).
        """

        var result = ""
        do {
            for try await token in router.stream(messages: [PAIChatMessage.user(prompt)]) {
                result += token
            }
        } catch {}

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            livingInsights = [PAIInsight(
                id: UUID().uuidString,
                category: "productivity",
                content: trimmed,
                confidence: 0.85,
                utilityScore: 0.8
            )]
        }

        isLoadingPAI = false
    }
    
    private var insightsSummary: String {
        if let trend = productivityTrend {
            if trend.completionRate >= 0.8 {
                return "You're crushing it! \(Int(trend.completionRate * 100))% completion rate with a \(trend.streakDays)-day streak 🔥"
            } else if trend.completionRate >= 0.6 {
                return "Solid productivity! You're completing \(String(format: "%.1f", trend.dailyAverage)) tasks daily on average."
            } else {
                return "Let's boost your productivity together. Here are insights tailored for you."
            }
        }
        return "Analyzing your productivity patterns to help you work smarter."
    }
    
    private func loadInsights() {
        isLoading = true
        
        // Simulate brief loading for smoother UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recommendations = AIInsightsService.shared.generateRecommendations(context: modelContext)
            energyPattern = AIInsightsService.shared.analyzeEnergyPatterns(context: modelContext)
            productivityTrend = AIInsightsService.shared.analyzeProductivityTrends(context: modelContext)
            
            withAnimation {
                isLoading = false
            }
        }
    }
}

struct ProductivityCard: View {
    let trend: ProductivityTrend
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(DSColors.accentPrimary)
                Text("Productivity Trend")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            HStack(spacing: 20) {
                MetricView(value: String(format: "%.1f", trend.dailyAverage), label: "Daily Avg")
                Divider()
                MetricView(value: "\(trend.streakDays)", label: "Streak Days")
                Divider()
                MetricView(value: "\(Int(trend.completionRate * 100))%", label: "Complete Rate")
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

// Enhanced Productivity Gauge Card
struct ProductivityGaugeCard: View {
    let trend: ProductivityTrend
    
    private var scorePercentage: Double {
        // Calculate overall productivity score
        let completionWeight = trend.completionRate * 0.4
        let streakWeight = min(Double(trend.streakDays) / 30.0, 1.0) * 0.3
        let volumeWeight = min(trend.dailyAverage / 10.0, 1.0) * 0.3
        return completionWeight + streakWeight + volumeWeight
    }
    
    private var scoreColor: Color {
        if scorePercentage >= 0.8 { return DSColors.success }
        if scorePercentage >= 0.6 { return DSColors.accentPrimary }
        if scorePercentage >= 0.4 { return DSColors.warning }
        return DSColors.error
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Productivity Score")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(DSColors.textSecondary.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: scorePercentage)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: scorePercentage)
                
                // Center content
                VStack(spacing: 8) {
                    Text("\(Int(scorePercentage * 100))")
                        .font(DSFonts.title(48))
                        .foregroundColor(scoreColor)
                    Text("Score")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            
            // Metrics Grid
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", trend.dailyAverage))
                        .font(DSFonts.title(20))
                        .foregroundColor(DSColors.textPrimary)
                    Text("Daily Tasks")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(trend.streakDays)")
                            .font(DSFonts.title(20))
                            .foregroundColor(DSColors.warning)
                        if trend.streakDays > 0 {
                            Image(systemName: "flame.fill")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.warning)
                        }
                    }
                    Text("Day Streak")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                
                Divider()
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Text("\(Int(trend.completionRate * 100))%")
                        .font(DSFonts.title(20))
                        .foregroundColor(DSColors.success)
                    Text("Completion")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.extraLarge)
    }
}

struct MetricView: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DSFonts.title(24))
                .foregroundColor(DSColors.accentPrimary)
            Text(label)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct EnergyPatternCard: View {
    let pattern: EnergyPattern
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Your Energy Pattern")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                EnergyTimeRow(label: "Peak Hours", hours: pattern.peakHours, color: DSColors.success)
                EnergyTimeRow(label: "Low Energy", hours: pattern.lowEnergyHours, color: DSColors.warning)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

// Interactive 24-Hour Energy Timeline
struct EnergyTimelineCard: View {
    let pattern: EnergyPattern
    
    private let hours = Array(6...22) // 6 AM to 10 PM
    
    private func energyLevel(for hour: Int) -> EnergyLevel {
        if pattern.peakHours.contains(hour) { return .high }
        if pattern.lowEnergyHours.contains(hour) { return .low }
        return .medium
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Your Energy Timeline")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            // Timeline visualization
            VStack(spacing: 8) {
                // Hour labels
                HStack(spacing: 0) {
                    ForEach([6, 9, 12, 15, 18, 21], id: \.self) { hour in
                        Text(formatHour(hour))
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Energy bars
                HStack(spacing: 4) {
                    ForEach(hours, id: \.self) { hour in
                        let level = energyLevel(for: hour)
                        Rectangle()
                            .fill(level.color)
                            .frame(height: level.barHeight)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 60, alignment: .bottom)
            }
            .padding()
            .background(DSColors.canvasPrimary)
            .cornerRadius(UIConstants.CornerRadius.standard)
            
            // Legend
            HStack(spacing: 20) {
                LegendItem(color: DSColors.success, label: "Peak Energy", count: pattern.peakHours.count)
                LegendItem(color: Color.gray.opacity(0.5), label: "Moderate", count: hours.count - pattern.peakHours.count - pattern.lowEnergyHours.count)
                LegendItem(color: DSColors.warning, label: "Low Energy", count: pattern.lowEnergyHours.count)
            }
            .font(DSFonts.caption())
            
            // Insights
            VStack(alignment: .leading, spacing: 8) {
                if !pattern.peakHours.isEmpty, let peakStart = pattern.peakHours.first, let peakEnd = pattern.peakHours.last {
                    InsightRow(
                        icon: "lightbulb.fill",
                        text: "Schedule important work between \(formatHour(peakStart)) - \(formatHour(peakEnd))",
                        color: DSColors.success
                    )
                }
                
                if !pattern.lowEnergyHours.isEmpty, let lowStart = pattern.lowEnergyHours.first {
                    InsightRow(
                        icon: "moon.fill",
                        text: "Save small tasks for after \(formatHour(lowStart))",
                        color: DSColors.warning
                    )
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.extraLarge)
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

enum EnergyLevel {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high: return DSColors.success
        case .medium: return Color.gray.opacity(0.5)
        case .low: return DSColors.warning
        }
    }
    
    var barHeight: CGFloat {
        switch self {
        case .high: return 50
        case .medium: return 30
        case .low: return 15
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let count: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) (\(count)h)")
                .foregroundColor(DSColors.textSecondary)
        }
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DSFonts.caption())
                .foregroundColor(color)
            Text(text)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textPrimary)
        }
    }
}

struct EnergyTimeRow: View {
    let label: String
    let hours: [Int]
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(DSFonts.body(14))
                .foregroundColor(DSColors.textSecondary)
            Spacer()
            Text(hours.map { formatHour($0) }.joined(separator: ", "))
                .font(DSFonts.body(14).weight(.medium))
                .foregroundColor(color)
        }
    }
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    @Environment(\.dismiss) private var dismiss
    
    var priorityColor: Color {
        switch recommendation.priority {
        case .high: return DSColors.error
        case .medium: return DSColors.warning
        case .low: return DSColors.accentPrimary
        }
    }
    
    var priorityLabel: String {
        switch recommendation.priority {
        case .high: return "High Priority"
        case .medium: return "Medium Priority"
        case .low: return "Low Priority"
        }
    }
    
    var actionLabel: String {
        switch recommendation.action {
        case .showLargeTasks: return "View Tasks"
        case .showOverdue: return "Review Now"
        case .showLifeBalance: return "See Balance"
        case .showScheduleSuggestions: return "Get Suggestions"
        case .createRoutine: return "Create Routine"
        case .openWeeklyReview: return "Open Review"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(priorityColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(priorityColor)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(recommendation.title)
                            .font(DSFonts.body().weight(.semibold))
                            .foregroundColor(DSColors.textPrimary)
                        
                        Spacer()
                        
                        Text(priorityLabel)
                            .font(DSFonts.caption())
                            .foregroundColor(priorityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(priorityColor.opacity(0.15))
                            .cornerRadius(4)
                    }
                    
                    Text(recommendation.description)
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Action Button
            Button(action: {
                handleRecommendationAction()
            }) {
                HStack {
                    Text(actionLabel)
                        .font(DSFonts.body(14).weight(.medium))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(DSFonts.caption())
                }
                .foregroundColor(priorityColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(priorityColor.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                .strokeBorder(priorityColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func handleRecommendationAction() {
        
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss AI Insights view first
        dismiss()
        
        // Small delay to let dismiss animation complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Navigate based on action type
            switch recommendation.action {
            case .showOverdue, .showLargeTasks:
                // Navigate to Today tab (tab index 0)
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToTab"),
                    object: nil,
                    userInfo: ["tabIndex": 0]
                )
                
            case .showLifeBalance:
                // Navigate to Plans tab (tab index 1)
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToTab"),
                    object: nil,
                    userInfo: ["tabIndex": 1]
                )
                
            case .createRoutine:
                // Navigate to Routines tab (tab index 3)
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToTab"),
                    object: nil,
                    userInfo: ["tabIndex": 3]
                )
                
            case .showScheduleSuggestions:
                // Stay in AI Insights, just scroll down
                // (This would require ScrollViewReader, skip for now)
                break

            case .openWeeklyReview:
                // This would open WeeklyReviewView sheet
                break
            }
        }
    }
}

struct ScheduleSuggestionsSection: View {
    let tasks: [TaskWork]
    let modelContext: ModelContext
    
    @State private var suggestions: [ScheduleSuggestion] = []
    @State private var showAllSuggestions = false
    @State private var appliedTaskIds: Set<UUID> = []
    @State private var showSuccessMessage = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schedule Suggestions")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
                .padding(.horizontal)
            
            // Success message
            if showSuccessMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DSColors.success)
                    Text("Task scheduled successfully!")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.success)
                }
                .padding()
                .background(DSColors.success.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if activeSuggestions.isEmpty {
                Text(appliedTaskIds.isEmpty ? "No scheduling suggestions available" : "All suggestions applied! Tasks have been scheduled.")
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .padding()
            } else {
                ForEach(activeSuggestions.prefix(showAllSuggestions ? activeSuggestions.count : 3)) { suggestion in
                    ScheduleSuggestionCard(
                        suggestion: suggestion, 
                        modelContext: modelContext,
                        onApplied: {
                            handleSuggestionApplied(suggestion)
                        }
                    )
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                if activeSuggestions.count > 3 {
                    Button {
                        showAllSuggestions.toggle()
                    } label: {
                        Text(showAllSuggestions ? "Show Less" : "Show All (\(activeSuggestions.count))")
                            .font(DSFonts.body(14))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadSuggestions()
        }
    }
    
    private var activeSuggestions: [ScheduleSuggestion] {
        suggestions.filter { !appliedTaskIds.contains($0.task.id) }
    }
    
    private func loadSuggestions() {
        let unscheduled = tasks.filter { $0.dueDate == nil && $0.completedAt == nil }
        suggestions = AIInsightsService.shared.suggestOptimalSchedule(for: unscheduled, context: modelContext)
    }
    
    private func handleSuggestionApplied(_ suggestion: ScheduleSuggestion) {
        withAnimation {
            appliedTaskIds.insert(suggestion.task.id)
            showSuccessMessage = true
        }
        
        // Hide success message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSuccessMessage = false
            }
        }
        
    }
}

struct ScheduleSuggestionCard: View {
    let suggestion: ScheduleSuggestion
    let modelContext: ModelContext
    let onApplied: () -> Void
    
    @State private var isApplying = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.task.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Text(suggestion.reason)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(DSFonts.caption())
                    Text(suggestion.suggestedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(DSFonts.caption().weight(.medium))
                }
                .foregroundColor(DSColors.accentPrimary)
            }
            
            Spacer()
            
            Button {
                applySuggestion()
            } label: {
                HStack(spacing: 4) {
                    if isApplying {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(DSFonts.caption())
                        Text("Apply")
                    }
                }
                .font(DSFonts.body(13))
                .foregroundColor(DSColors.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isApplying ? Color.gray : DSColors.accentPrimary)
                .cornerRadius(UIConstants.CornerRadius.small)
            }
            .disabled(isApplying)
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
    
    private func applySuggestion() {
        isApplying = true
        
        
        // Set the due date
        suggestion.task.dueDate = suggestion.suggestedDate
        
        // Save to context
        do {
            try modelContext.save()
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Notify parent to remove this suggestion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onApplied()
                isApplying = false
            }
        } catch {
            isApplying = false
        }
    }
}

// MARK: - Phase 3: PAI Living Insights Types

struct PAIInsight: Identifiable {
    let id: String
    let category: String
    let content: String
    let confidence: Double  // PAI relevance score 0–1
    let utilityScore: Double

    var categoryIcon: String {
        switch category {
        case "productivity": return "chart.line.uptrend.xyaxis"
        case "habits":       return "repeat.circle.fill"
        case "knowledge":    return "lightbulb.fill"
        default:             return "sparkle"
        }
    }

    var categoryColor: Color {
        switch category {
        case "productivity": return DSColors.accentPrimary
        case "habits":       return DSColors.success
        case "knowledge":    return DSColors.accentSecondary
        default:             return DSColors.accentPrimary
        }
    }
}

// MARK: - Living Insights Section

struct LivingInsightsSection: View {
    let insights: [PAIInsight]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(DSColors.accentSecondary)
                Text("Lumina's Living Insights")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("AI observation")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }

            if isLoading {
                ForEach(0..<2) { _ in
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                        .fill(DSColors.canvasSecondary)
                        .frame(height: 60)
                }
            } else if insights.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "moon.zzz")
                        .foregroundColor(DSColors.textSecondary)
                    Text("Keep capturing — Lumina will surface patterns as your memory grows.")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                }
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.medium)
            } else {
                ForEach(insights) { insight in
                    PAIInsightRow(insight: insight)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [DSColors.accentSecondary.opacity(0.05), DSColors.canvasSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DSColors.accentSecondary.opacity(0.15), lineWidth: 1))
    }
}

struct PAIInsightRow: View {
    let insight: PAIInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.categoryIcon)
                .font(.system(size: 14))
                .foregroundColor(insight.categoryColor)
                .frame(width: 32, height: 32)
                .background(insight.categoryColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.content)
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(insight.category.capitalized)
                        .font(DSFonts.caption().bold())
                        .foregroundColor(insight.categoryColor)

                    Text("·")
                        .foregroundColor(DSColors.textSecondary)

                    Text(String(format: "%.0f%% confidence", insight.confidence * 100))
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(DSColors.canvasPrimary)
        .cornerRadius(UIConstants.CornerRadius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.category) insight: \(insight.content). Confidence \(Int(insight.confidence * 100)) percent.")
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .modelContainer(for: [TaskWork.self], inMemory: true)
    }
}
