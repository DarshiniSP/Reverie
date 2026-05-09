//
//  AnalyticsDashboardView.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import SwiftUI
import SwiftData
import Charts

struct AnalyticsDashboardView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPeriod: TimePeriod = .month
    @State private var completionStats: CompletionStats?
    @State private var productivityScore: Double = 0
    @State private var lifeBalance: LifeBalanceScore?
    @State private var completionTrend: [DataPoint] = []
    @State private var sizeDistribution: [SizeDataPoint] = []

    @State private var lifePulseNarrative = ""
    @State private var lifePulseLoading = false
    @State private var knowledgeCount = 0
    @State private var velocityReport: VelocityReport?
    @State private var bestTimeInsight: BestTimeInsight?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Resilience Index Card — the signature wellbeing metric
                ResilienceIndexCard()
                    .padding(.horizontal)

                // Lumina narrative summary
                LifePulseHeaderCard(
                    narrative: lifePulseNarrative,
                    isLoading: lifePulseLoading,
                    knowledgeCount: knowledgeCount,
                    onRefresh: { Task { await generateLifePulse() } }
                )
                .padding(.horizontal)

                if let velocity = velocityReport {
                    VelocityTrendCard(report: velocity)
                        .padding(.horizontal)
                }

                if let best = bestTimeInsight {
                    BestTimeCard(insight: best)
                        .padding(.horizontal)
                }

                // Activity grid (GitHub-style heatmap)
                ActivityGridCard()
                    .padding(.horizontal)

                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    Text("Today").tag(TimePeriod.today)
                    Text("Week").tag(TimePeriod.week)
                    Text("Month").tag(TimePeriod.month)
                    Text("Year").tag(TimePeriod.year)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedPeriod) { _, _ in
                    loadAnalytics()
                }

                // Check if we have any data
                if let stats = completionStats, stats.totalTasks == 0 && completionTrend.isEmpty {
                    // Empty State
                    VStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 64))
                            .foregroundColor(DSColors.textSecondary.opacity(0.5))
                        
                        Text("No Data Yet")
                            .font(DSFonts.title(20))
                            .foregroundColor(DSColors.textPrimary)
                        
                        Text("Complete some tasks to see your analytics")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    // Productivity Score
                    if let stats = completionStats {
                        ProductivityScoreCard(score: productivityScore, stats: stats)
                            .padding(.horizontal)
                    }
                    
                    // Completion Trend Chart
                    if !completionTrend.isEmpty {
                        CompletionTrendChart(data: completionTrend)
                            .padding(.horizontal)
                    }
                    
                    // Size Distribution
                    if !sizeDistribution.isEmpty {
                        SizeDistributionChart(data: sizeDistribution)
                            .padding(.horizontal)
                    }
                    
                    // Life Balance
                    if let balance = lifeBalance {
                        LifeBalanceCard(balance: balance)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Resilience Index")
        .onAppear {
            loadAnalytics()
            Task { await generateLifePulse() }
        }
    }

    // MARK: - Life Pulse Narrative (via LuminaInferenceRouter)

    private func generateLifePulse() async {
        let router = LuminaInferenceRouter.shared
        guard router.isConfigured(router.selectedProviderID) else {
            lifePulseNarrative = "Configure an AI provider in Settings → Lumina AI to see your Life Pulse."
            return
        }
        lifePulseLoading = true

        // Snapshot context
        let stats = completionStats ?? AnalyticsService.shared.getCompletionStats(for: .week, context: modelContext)
        let balance = lifeBalance ?? AnalyticsService.shared.getLifeBalanceScore(context: modelContext)
        let score = productivityScore > 0 ? productivityScore
            : AnalyticsService.shared.getProductivityScore(for: .week, context: modelContext)

        let knowledgeDesc = FetchDescriptor<Knowledge>()
        knowledgeCount = (try? modelContext.fetch(knowledgeDesc))?.count ?? 0

        let prompt = """
        You are Lumina, a supportive AI companion for student wellbeing. Write a 2-sentence resilience summary (warm, specific, honest) based on:
        - Completion score this week: \(Int(score))/100
        - Tasks completed: \(stats.completedTasks) of \(stats.totalTasks)
        - Domain balance score: \(Int(balance.overallScore * 100))/100
        - Top active domain: \(balance.scores.max(by: { $0.value < $1.value })?.key.rawValue ?? "mixed")
        Acknowledge both effort and areas of strain. Max 40 words. No generic affirmations.
        """

        do {
            var narrative = ""
            for try await token in router.stream(messages: [PAIChatMessage.user(prompt)]) {
                narrative += token
            }
            lifePulseNarrative = narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            lifePulseNarrative = "Your week shows consistent effort. Keep the momentum going."
        }

        lifePulseLoading = false
    }

    private func loadAnalytics() {

        completionStats = AnalyticsService.shared.getCompletionStats(for: selectedPeriod, context: modelContext)

        productivityScore = AnalyticsService.shared.getProductivityScore(for: selectedPeriod, context: modelContext)

        lifeBalance = AnalyticsService.shared.getLifeBalanceScore(context: modelContext)

        completionTrend = AnalyticsService.shared.getCompletionTrend(for: selectedPeriod, context: modelContext)

        sizeDistribution = AnalyticsService.shared.getSizeDistribution(for: selectedPeriod, context: modelContext)

        velocityReport = LifePatternAnalyzer.shared.generateVelocityReport(context: modelContext)
        bestTimeInsight = LifePatternAnalyzer.shared.bestHourOfDay(context: modelContext)
    }
}

// MARK: - P3-C: Velocity Trend Card

struct VelocityTrendCard: View {
    let report: VelocityReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: report.hasEnoughData ? report.trendDirection.icon : "chart.line.uptrend.xyaxis")
                    .foregroundColor(report.hasEnoughData ? trendColour : DSColors.textSecondary)
                Text("Completion Velocity")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                    .accessibilityIdentifier("velocityCardHeader")
                Spacer()
                if report.hasEnoughData {
                    Text(report.trendDirection.rawValue)
                        .font(DSFonts.caption().bold())
                        .foregroundColor(trendColour)
                }
            }

            if report.hasEnoughData {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.avgPerDayLabel)
                            .font(DSFonts.title(16).bold())
                            .foregroundColor(DSColors.textPrimary)
                        Text("4-week average")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    if let bestDay = report.bestDayOfWeek {
                        Divider().frame(height: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bestDay)
                                .font(DSFonts.title(16).bold())
                                .foregroundColor(DSColors.textPrimary)
                            Text("Best day")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                // Mini sparkline using weekly buckets
                if !report.weeklyCompletions.isEmpty {
                    HStack(alignment: .bottom, spacing: 6) {
                        ForEach(Array(report.weeklyCompletions.enumerated()), id: \.offset) { idx, count in
                            let maxVal = max(1, report.weeklyCompletions.max() ?? 1)
                            let height = max(4.0, Double(count) / Double(maxVal) * 40)
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(idx == report.weeklyCompletions.count - 1 ? trendColour : DSColors.accentPrimary.opacity(0.5))
                                    .frame(height: height)
                                Text(idx == 0 ? "4w" : idx == report.weeklyCompletions.count - 1 ? "now" : "")
                                    .font(.system(size: 9))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 56)
                    .padding(.top, 4)
                }
            } else {
                Text("Keep building your history — velocity trends appear after 7+ completed tasks.")
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
                    .accessibilityIdentifier("velocityInsufficientData")
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.extraLarge)
    }

    private var trendColour: Color {
        switch report.trendDirection {
        case .improving: return DSColors.success
        case .stable:    return DSColors.warning
        case .declining: return DSColors.error
        }
    }
}

struct ProductivityScoreCard: View {
    let score: Double
    let stats: CompletionStats

    var scoreColor: Color {
        if score >= 80 { return DSColors.success }
        if score >= 60 { return DSColors.warning }
        return DSColors.error
    }

    var scoreGradient: [Color] {
        if score >= 80 { return [DSColors.success, DSColors.accentPrimary] }
        if score >= 60 { return [DSColors.warning, DSColors.focus] }
        return [DSColors.error, DSColors.warning]
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 24) {
                // Gradient score ring
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.12), lineWidth: 14)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: score / 100)
                        .stroke(
                            LinearGradient(
                                colors: scoreGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(score))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(DSColors.textPrimary)
                        Text("Score")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                // Stat columns to the right
                VStack(alignment: .leading, spacing: 14) {
                    scoreStatRow(value: "\(stats.completedTasks)", label: "Completed", color: DSColors.success)
                    Divider()
                    scoreStatRow(value: "\(stats.totalTasks)", label: "Total tasks", color: DSColors.accentPrimary)
                    Divider()
                    scoreStatRow(value: "\(stats.streakDays)d", label: "Current streak", color: DSColors.warning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.extraLarge)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.extraLarge)
                .stroke(DSColors.divider, lineWidth: 0.5)
        )
        .shadow(color: DSColors.shadow, radius: 12, x: 0, y: 3)
    }

    private func scoreStatRow(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)
                Text(label)
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
    }
}

struct StatColumn: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DSFonts.title(20))
                .foregroundColor(DSColors.textPrimary)
            Text(label)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CompletionTrendChart: View {
    let data: [DataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion Trend")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Completed", point.value)
                )
                .foregroundStyle(DSColors.accentPrimary)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Completed", point.value)
                )
                .foregroundStyle(DSColors.accentPrimary.opacity(0.2))
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct SizeDistributionChart: View {
    let data: [SizeDataPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Size Distribution")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            Chart(data) { point in
                BarMark(
                    x: .value("Size", point.size.rawValue),
                    y: .value("Count", point.count)
                )
                .foregroundStyle(by: .value("Size", point.size.rawValue))
            }
            .frame(height: 200)
            .chartForegroundStyleScale([
                "Small": DSColors.success,
                "Medium": DSColors.warning,
                "Large": DSColors.error
            ])
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct LifeBalanceCard: View {
    let balance: LifeBalanceScore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Life Balance")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            // Overall Score
            HStack {
                Text("Overall Balance")
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text("\(Int(balance.overallScore * 100))%")
                    .font(DSFonts.body().weight(.semibold))
                    .foregroundColor(DSColors.accentPrimary)
            }
            
            Divider()
            
            // Domain Scores
            ForEach(LifeDomain.allCases, id: \.self) { domain in
                if let score = balance.scores[domain] {
                    DomainScoreRow(domain: domain, score: score)
                }
            }
            
            // Recommendations
            if !balance.recommendations.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(DSFonts.body().weight(.medium))
                        .foregroundColor(DSColors.textPrimary)
                    
                    ForEach(balance.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.warning)
                            Text(recommendation)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct DomainScoreRow: View {
    let domain: LifeDomain
    let score: Double
    
    var scoreColor: Color {
        if score >= 0.7 { return DSColors.success }
        if score >= 0.4 { return DSColors.warning }
        return DSColors.error
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: domain.icon)
                    .foregroundColor(scoreColor)
                Text(domain.rawValue)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Text("\(Int(score * 100))%")
                    .font(DSFonts.body(14).weight(.medium))
                    .foregroundColor(scoreColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(scoreColor.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(scoreColor)
                        .frame(width: geometry.size.width * score, height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Phase 3: Life Pulse Header Card

struct LifePulseHeaderCard: View {
    let narrative: String
    let isLoading: Bool
    let knowledgeCount: Int
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundColor(DSColors.accentSecondary)
                    .frame(width: 32, height: 32)
                    .background(DSColors.accentSecondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

                Text("Lumina Summary")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)

                Spacer()

                if isLoading {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button(action: onRefresh) {
                        Image(systemName: "sparkles")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.accentSecondary)
                    }
                }
            }

            if narrative.isEmpty && !isLoading {
                Text("Loading your life pulse…")
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
            } else if isLoading {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<2) { i in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DSColors.textSecondary.opacity(0.15))
                            .frame(height: 12)
                            .frame(maxWidth: i == 1 ? .infinity * 0.7 : .infinity)
                    }
                }
            } else {
                Text(narrative)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .lineSpacing(3)
            }

            if knowledgeCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(DSFonts.caption())
                        .foregroundColor(.yellow)
                    Text("\(knowledgeCount) knowledge items in your second brain")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding()
        .background(
            ZStack {
                LinearGradient(
                    colors: [DSColors.accentPrimary.opacity(0.08), DSColors.accentSecondary.opacity(0.05), DSColors.canvasSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [DSColors.accentPrimary.opacity(0.3), DSColors.accentSecondary.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: DSColors.accentPrimary.opacity(0.06), radius: 14, x: 0, y: 4)
    }
}

// MARK: - Best Time Card

struct BestTimeCard: View {
    let insight: BestTimeInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(DSColors.accentSecondary)
                    .frame(width: 32, height: 32)
                    .background(DSColors.accentSecondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your peak hours")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    Text("Based on last 28 days")
                        .font(DSFonts.caption(11))
                        .foregroundColor(DSColors.textSecondary)
                }
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(insight.rangeLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.accentSecondary)
                Text("· \(insight.percentage)% of completions")
                    .font(DSFonts.caption(13))
                    .foregroundColor(DSColors.textSecondary)
            }

            Text("Schedule your most demanding tasks in this window for maximum output.")
                .font(DSFonts.body(13))
                .foregroundColor(DSColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [DSColors.accentSecondary.opacity(0.07), DSColors.canvasSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DSColors.accentSecondary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: DSColors.shadow, radius: 10, x: 0, y: 3)
    }
}

#Preview {
    NavigationStack {
        AnalyticsDashboardView()
            .modelContainer(for: [TaskWork.self, Knowledge.self], inMemory: true)
    }
}
