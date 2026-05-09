//
//  DailyBriefingView.swift
//  iAlly
//
//  Phase 3: Proactive Intelligence
//  The morning intelligence card shown at the top of TodayView.
//  PAI-generated each morning with:
//    • Full narrative briefing (expandable)
//    • Key focus task
//    • Pattern insight
//    • Upcoming milestone
//    • Reflection prompt
//

import SwiftUI
import SwiftData

// MARK: - Daily Briefing Card (compact, used in TodayContentView)

struct DailyBriefingCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var showFullBriefing = false

    private let engine = ProactiveIntelligenceEngine.shared

    var body: some View {
        Card {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DSColors.accentPrimary.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 20))
                            .foregroundColor(DSColors.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Lumina Briefing")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.textPrimary)
                            if engine.isGenerating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        // P1-A: Day Type verdict chip
                        if let briefing = engine.todaysBriefing {
                            DayTypeChip(dayType: briefing.dayType)
                        }
                        Text(briefingSubtitle)
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .accessibilityLabel(isExpanded ? "Collapse briefing" : "Expand briefing")
                }

                if let briefing = engine.todaysBriefing {
                    // Narrative preview (always shown)
                    Text(briefing.narrative)
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                        .padding(.top, 12)
                        .animation(.easeInOut, value: isExpanded)

                    // Expanded detail pills
                    if isExpanded {
                        briefingDetailRows(briefing)
                            .transition(.opacity.combined(with: .move(edge: .top)))

                        Button {
                            showFullBriefing = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Open Full Briefing")
                                    .font(DSFonts.body(13))
                                Image(systemName: "arrow.up.right.square")
                                    .font(DSFonts.caption())
                            }
                            .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityLabel("Open full Lumina daily briefing")
                        .padding(.top, 10)
                    }
                } else if engine.isGenerating {
                    BriefingSkeletonView()
                        .padding(.top, 12)
                } else {
                    Text("Tap refresh to generate your morning briefing.")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .padding(.top, 8)

                    Button {
                        Task { await engine.runCycle(context: modelContext) }
                    } label: {
                        Label("Generate Briefing", systemImage: "sparkles")
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    .padding(.top, 6)
                }

                // Top nudge (if any and not generating)
                if !engine.pendingNudges.isEmpty && !engine.isGenerating {
                    Divider().padding(.top, 12)
                    topNudgeRow
                }
            }
        }
        .sheet(isPresented: $showFullBriefing) {
            FullDailyBriefingView()
        }
        .task {
            await engine.runIfNeeded(context: modelContext)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func briefingDetailRows(_ briefing: DailyBriefing) -> some View {
        VStack(spacing: 8) {
            if let focus = briefing.focusTask {
                BriefingPill(icon: "scope", label: "Focus", value: focus, color: DSColors.accentPrimary)
            }
            if let milestone = briefing.upcomingMilestone {
                BriefingPill(icon: "flag.circle.fill", label: "Upcoming", value: milestone, color: DSColors.warning)
            }
            BriefingPill(icon: "lightbulb.fill", label: "Insight", value: briefing.patternInsight, color: DSColors.accentSecondary)
            BriefingPill(icon: "questionmark.bubble.fill", label: "Reflect", value: briefing.reflectionPrompt, color: .teal)
        }
        .padding(.top, 10)
    }

    private var topNudgeRow: some View {
        let nudge = engine.pendingNudges[0]
        return HStack(spacing: 10) {
            Image(systemName: nudge.icon)
                .font(.system(size: 14))
                .foregroundColor(DSColors.warning)
                .frame(width: 28, height: 28)
                .background(DSColors.warning.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(nudge.title)
                    .font(DSFonts.body(13).bold())
                    .foregroundColor(DSColors.textPrimary)
                Text(nudge.body)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    private var briefingSubtitle: String {
        guard !engine.isGenerating else { return "Generating… (may take up to 60s)" }
        guard engine.todaysBriefing != nil else { return "Tap to generate" }
        return Date().formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Full Briefing Sheet

struct FullDailyBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let engine = ProactiveIntelligenceEngine.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Narrative header
                    if let briefing = engine.todaysBriefing {
                        narrativeSection(briefing)
                        nudgesSection
                    } else {
                        ContentUnavailableView(
                            "No Briefing Yet",
                            systemImage: "brain.head.profile",
                            description: Text("Lumina will generate your briefing shortly.")
                        )
                    }
                    // P3-C: Velocity trend (shown after nudges)
                    velocitySection
                    // P2-A + P3-D: Weekly report with honest observations
                    weeklyReportSection
                }
                .padding()
            }
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("Morning Briefing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await engine.runCycle(context: modelContext) }
                    } label: {
                        if engine.isGenerating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(engine.isGenerating)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func narrativeSection(_ briefing: DailyBriefing) -> some View {
        // Main narrative
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(DSColors.accentPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lumina's Take on Today")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    // P1-A: Day type verdict in full briefing view
                    DayTypeChip(dayType: briefing.dayType)
                }
                Spacer()
            }
            Text(briefing.narrative)
                .font(DSFonts.body(15))
                .foregroundColor(DSColors.textSecondary)
                .lineSpacing(4)
            // Day type tagline
            Text(briefing.dayType.tagline)
                .font(DSFonts.caption().italic())
                .foregroundColor(DSColors.textSecondary.opacity(0.75))
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)

        // Detail pills
        VStack(spacing: 10) {
            if let focus = briefing.focusTask {
                BriefingDetailRow(icon: "scope", label: "Key Focus", value: focus, color: DSColors.accentPrimary)
            }
            if let milestone = briefing.upcomingMilestone {
                BriefingDetailRow(icon: "flag.circle.fill", label: "Milestone", value: milestone, color: DSColors.warning)
            }
            BriefingDetailRow(icon: "lightbulb.fill", label: "Pattern Insight", value: briefing.patternInsight, color: DSColors.accentSecondary)
            BriefingDetailRow(icon: "questionmark.bubble.fill", label: "Daily Reflection", value: briefing.reflectionPrompt, color: .teal)
        }
    }

    private var nudgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Nudges")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)

            ForEach(engine.pendingNudges) { nudge in
                NudgeCard(nudge: nudge)
            }
        }
    }

    // MARK: - P3-C: Velocity Trend Section

    @ViewBuilder
    private var velocitySection: some View {
        let report = LifePatternAnalyzer.shared.generateVelocityReport(context: modelContext)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: report.hasEnoughData ? report.trendDirection.icon : "chart.line.uptrend.xyaxis")
                    .foregroundColor(report.hasEnoughData ? trendColour(report.trendDirection) : DSColors.textSecondary)
                Text("Completion Velocity")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                    .accessibilityIdentifier("velocitySectionHeader")
                Spacer()
                if report.hasEnoughData {
                    Text(report.trendDirection.rawValue)
                        .font(DSFonts.caption().bold())
                        .foregroundColor(trendColour(report.trendDirection))
                        .accessibilityIdentifier("velocityTrendLabel")
                }
            }

            if report.hasEnoughData {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.avgPerDayLabel)
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                    if let bestDay = report.bestDayOfWeek {
                        Text("Best day: \(bestDay)")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            } else {
                Text("Keep building your history — velocity trends appear after 7+ completions.")
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
                    .accessibilityIdentifier("velocityInsufficientData")
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }

    private func trendColour(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return DSColors.success
        case .stable:    return DSColors.warning
        case .declining: return DSColors.error
        }
    }

    // MARK: - P2-A: Weekly Report Section

    @ViewBuilder
    private var weeklyReportSection: some View {
        if let report = WeeklyReflectionService.shared.lastReport {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundColor(DSColors.accentSecondary)
                    Text("Last 7 Days")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    Spacer()
                    Text("\(report.completionPercent)% done")
                        .font(DSFonts.caption().bold())
                        .foregroundColor(report.completionPercent >= 70 ? .green : .orange)
                }

                // Domain breakdown
                VStack(spacing: 6) {
                    ForEach(report.domains) { domain in
                        WeeklyDomainRow(domain: domain)
                    }
                }

                // Best streak
                if let routineName = report.bestStreakRoutine, report.bestStreak >= 3 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundColor(DSColors.warning)
                        Text("\(routineName): \(report.bestStreak)-day streak")
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.textPrimary)
                    }
                    .padding(10)
                    .background(DSColors.warning.opacity(0.08))
                    .cornerRadius(UIConstants.CornerRadius.standard)
                }

                // P3-D: Honest observations (up to 3 uncomfortable truths)
                if !report.honestObservations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Honest This Week", systemImage: "exclamationmark.triangle.fill")
                            .font(DSFonts.body(13).bold())
                            .foregroundColor(DSColors.error.opacity(0.85))
                        ForEach(Array(report.honestObservations.enumerated()), id: \.offset) { _, obs in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundColor(DSColors.error.opacity(0.8))
                                    .font(DSFonts.body(13).bold())
                                Text(obs)
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(10)
                    .background(DSColors.error.opacity(0.07))
                    .cornerRadius(UIConstants.CornerRadius.standard)
                    .accessibilityIdentifier("weeklyHonestObservation")
                }
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
}

// MARK: - Weekly Domain Row

struct WeeklyDomainRow: View {
    let domain: WeeklyReportDomain

    var body: some View {
        HStack(spacing: 8) {
            Text(domain.domain)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DSColors.canvasPrimary)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(domain.completionRate >= 0.7 ? DSColors.success : (domain.completionRate >= 0.3 ? DSColors.warning : DSColors.error.opacity(0.7)))
                        .frame(width: geo.size.width * domain.completionRate, height: 6)
                }
            }
            .frame(height: 6)
            Text("\(domain.completed)/\(domain.planned)")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

// MARK: - Nudge Card

struct NudgeCard: View {
    let nudge: LuminaNudge

    private var urgencyColor: Color {
        switch nudge.urgency {
        case .high:   return DSColors.error
        case .medium: return DSColors.warning
        case .low:    return DSColors.accentPrimary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: nudge.icon)
                .font(.system(size: 16))
                .foregroundColor(urgencyColor)
                .frame(width: 36, height: 36)
                .background(urgencyColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

            VStack(alignment: .leading, spacing: 4) {
                Text(nudge.title)
                    .font(DSFonts.body().bold())
                    .foregroundColor(DSColors.textPrimary)
                Text(nudge.body)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
        // Note: intentionally NOT using .accessibilityElement(children: .combine) so that
        // UI tests can query nudge title/body Text elements via app.staticTexts.
        // VoiceOver reads title then body in sequence, which is equally clear for users.
    }
}

// MARK: - Supporting Components

struct BriefingPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)
            Text(label + ":")
                .font(DSFonts.caption().bold())
                .foregroundColor(color)
            Text(value)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
                .lineLimit(2)
            Spacer()
        }
    }
}

struct BriefingDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DSFonts.caption().bold())
                    .foregroundColor(color)
                Text(value)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

// MARK: - Day Type Chip (P1-A)

struct DayTypeChip: View {
    let dayType: DayType

    private var chipColor: Color {
        Color(hex: dayType.color)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: dayType.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(dayType.rawValue)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(chipColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(chipColor.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day type: \(dayType.rawValue)")
        .accessibilityIdentifier("dayTypeChip_\(dayType.rawValue.replacingOccurrences(of: " ", with: "_"))")
    }
}

struct BriefingSkeletonView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(DSColors.textSecondary.opacity(shimmer ? 0.1 : 0.2))
                    .frame(height: 12)
                    .frame(maxWidth: i == 2 ? .infinity * 0.6 : .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

#Preview {
    DailyBriefingCard()
        .padding()
        .modelContainer(for: [TaskWork.self, Journey.self, Plan.self, Routine.self, Knowledge.self], inMemory: true)
}
