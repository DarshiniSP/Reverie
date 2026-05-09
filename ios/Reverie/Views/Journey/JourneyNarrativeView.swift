//
//  JourneyNarrativeView.swift
//  iAlly
//
//  Phase 3: Proactive Intelligence
//  Long-form journey arc view powered by PAI.
//  Shows: PAI narrative of the journey story, lessons learned,
//         resilience score, milestone timeline, and next suggested action.
//
//  Access from JourneyDetailView via "Ask Lumina" toolbar button.
//

import SwiftUI
import SwiftData

struct JourneyNarrativeView: View {
    let journey: Journey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var narrative = ""
    @State private var nextAction = ""
    @State private var lessonsLearned: [String] = []
    @State private var resilienceScore: Double = 0
    @State private var isLoading = true
    @State private var isStreamingNarrative = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Journey Identity Header
                    journeyHeader

                    if isLoading {
                        loadingSection
                    } else if let error = errorMessage {
                        errorSection(error)
                    } else {
                        // PAI Narrative
                        narrativeSection

                        // Resilience Score
                        resilienceSection

                        // Lessons Learned
                        if !lessonsLearned.isEmpty {
                            lessonsSection
                        }

                        // Milestone Timeline
                        milestoneTimeline

                        // Next Suggested Action
                        if !nextAction.isEmpty {
                            nextActionSection
                        }
                    }
                }
                .padding()
            }
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("Journey Narrative")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Dismiss journey narrative")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await generateNarrative() }
                    } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isLoading)
                    .accessibilityLabel("Regenerate journey narrative")
                }
            }
            .task {
                await generateNarrative()
            }
        }
    }

    // MARK: - Journey Header

    private var journeyHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: journey.colorHex).opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: journey.icon)
                    .font(.system(size: 26))
                    .foregroundColor(Color(hex: journey.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(journey.title)
                    .font(DSFonts.title(18))
                    .foregroundColor(DSColors.textPrimary)

                if let vision = journey.vision, !vision.isEmpty {
                    Text(vision)
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    ProgressView(value: journey.progress)
                        .tint(Color(hex: journey.colorHex))
                        .frame(maxWidth: 120)

                    Text("\(Int(journey.progress * 100))%")
                        .font(DSFonts.caption().bold())
                        .foregroundColor(Color(hex: journey.colorHex))
                }
            }

            Spacer()
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(14)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(DSColors.accentPrimary)
                    .font(DSFonts.headline())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lumina is reading your journey…")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                    Text("Analysing milestones, tasks, and patterns")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                Spacer()
                ProgressView()
            }
            .padding()
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)

            // Skeleton rows
            ForEach(0..<3) { _ in
                NarrativeSkeletonRow()
            }
        }
    }

    @ViewBuilder
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundColor(DSColors.textSecondary)
            Text("Couldn't generate narrative")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            Text(message)
                .font(DSFonts.body(14))
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await generateNarrative() }
            }
            .buttonStyle(.bordered)
            .tint(DSColors.accentPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Narrative

    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Journey Story", systemImage: "text.quote")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)

            Text(narrative)
                .font(DSFonts.body(15))
                .foregroundColor(DSColors.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }

    // MARK: - Resilience Score

    private var resilienceSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(DSColors.accentPrimary.opacity(0.15), lineWidth: 8)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: resilienceScore)
                    .stroke(resilienceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(.easeOut(duration: 1.0), value: resilienceScore)

                VStack(spacing: 0) {
                    Text("\(Int(resilienceScore * 100))")
                        .font(DSFonts.title(18))
                        .foregroundColor(DSColors.textPrimary)
                    Text("%")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Resilience Score")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                Text(resilienceLabel)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Resilience score: \(Int(resilienceScore * 100)) percent. \(resilienceLabel)")
    }

    private var resilienceColor: Color {
        if resilienceScore > 0.7 { return DSColors.success }
        if resilienceScore > 0.4 { return DSColors.warning }
        return DSColors.error
    }

    private var resilienceLabel: String {
        if resilienceScore > 0.8 { return "Excellent momentum. You're adapting and progressing despite setbacks." }
        if resilienceScore > 0.6 { return "Good progress. Keep iterating and you'll reach the finish line." }
        if resilienceScore > 0.4 { return "Moderate momentum. Consider revisiting your approach to unblock progress." }
        return "This journey needs renewed attention. A small step today can restart the momentum."
    }

    // MARK: - Lessons Learned

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lessons Learned", systemImage: "lightbulb.fill")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)

            ForEach(Array(lessonsLearned.enumerated()), id: \.offset) { index, lesson in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(DSFonts.caption().bold())
                        .foregroundColor(DSColors.onAccent)
                        .frame(width: 22, height: 22)
                        .background(DSColors.accentPrimary)
                        .clipShape(Circle())
                    Text(lesson)
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }

    // MARK: - Milestone Timeline

    private var milestoneTimeline: some View {
        let milestones = journey.milestones?.sorted { $0.order < $1.order } ?? []
        return VStack(alignment: .leading, spacing: 12) {
            Label("Milestone Arc", systemImage: "timeline.selection.backward.and.forward")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)

            if milestones.isEmpty {
                Text("No milestones added yet.")
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
            } else {
                ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                    MilestoneTimelineRow(
                        milestone: milestone,
                        index: index,
                        isLast: index == milestones.count - 1,
                        journeyColor: journey.colorHex
                    )
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }

    // MARK: - Next Action

    private var nextActionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lumina's Suggested Next Action", systemImage: "arrow.right.circle.fill")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)

            Text(nextAction)
                .font(DSFonts.body(15))
                .foregroundColor(DSColors.textSecondary)
                .padding()
                .background(DSColors.accentPrimary.opacity(0.08))
                .cornerRadius(UIConstants.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                        .stroke(DSColors.accentPrimary.opacity(0.3), lineWidth: 1)
                )
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }

    // MARK: - Generation

    private func generateNarrative() async {
        isLoading = true
        errorMessage = nil

        let milestones = journey.milestones?.sorted { $0.order < $1.order } ?? []
        let tasks = journey.tasks ?? []
        let completedMilestones = milestones.filter { $0.isCompleted }.count
        let completedTasks = tasks.filter { $0.completedAt != nil }.count
        let overdueTasks = tasks.filter { t in
            guard let d = t.dueDate, t.completedAt == nil else { return false }
            return d < Date()
        }.count

        // Build resilience score locally (can be enhanced with PAI memory)
        let completionRate = milestones.isEmpty ? 0.0 : Double(completedMilestones) / Double(milestones.count)
        let taskProgress = tasks.isEmpty ? 0.5 : Double(completedTasks) / Double(tasks.count)
        let overdueImpact = max(0, 1.0 - Double(overdueTasks) * 0.1)
        resilienceScore = (completionRate * 0.5 + taskProgress * 0.3 + overdueImpact * 0.2)

        guard LuminaInferenceRouter.shared.isActiveProviderConfigured else {
            // No AI provider configured — use offline fallback
            narrative = generateOfflineNarrative()
            lessonsLearned = generateOfflineLessons()
            nextAction = generateOfflineNextAction(milestones: milestones)
            isLoading = false
            return
        }

        let prompt = buildNarrativePrompt(milestones: milestones, tasks: tasks,
                                          completedMilestones: completedMilestones,
                                          completedTasks: completedTasks)
        do {
            let content = try await LuminaInferenceRouter.shared.generate(
                messages: [PAIChatMessage.user(prompt)]
            )
            parseNarrativeResponse(content)
        } catch {
            if narrative.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func buildNarrativePrompt(milestones: [Milestone], tasks: [TaskWork],
                                      completedMilestones: Int, completedTasks: Int) -> String {
        var lines: [String] = []
        lines.append("Journey: \(journey.title)")
        if let v = journey.vision { lines.append("Vision: \(v)") }
        lines.append("Progress: \(Int(journey.progress * 100))% (\(completedMilestones)/\(milestones.count) milestones)")
        lines.append("Tasks: \(completedTasks)/\(tasks.count) completed")
        if let days = journey.daysRemaining { lines.append("Days remaining: \(days)") }
        if journey.isOverdue { lines.append("Status: OVERDUE") }

        let milestoneList = milestones.prefix(5).map {
            "  - \($0.title) [\($0.isCompleted ? "✓" : "○")]"
        }.joined(separator: "\n")
        if !milestoneList.isEmpty { lines.append("Milestones:\n\(milestoneList)") }

        let contextString = lines.joined(separator: "\n")

        return """
        You are Lumina, a personal second brain AI. Analyse this journey and respond with JSON:
        {
          "narrative": "A 3–4 sentence story of this journey: where it started, what's happened, current state, emotional arc. Write as a supportive coach, not a report.",
          "lessons": ["lesson 1 (10 words max)", "lesson 2 (10 words max)", "lesson 3 (10 words max)"],
          "nextAction": "One concrete, specific next action sentence (max 25 words)."
        }

        Journey context:
        \(contextString)

        Respond with JSON only, no markdown fences.
        """
    }

    private func parseNarrativeResponse(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            narrative = text // fallback: display raw text
            return
        }
        narrative = json["narrative"] as? String ?? generateOfflineNarrative()
        lessonsLearned = json["lessons"] as? [String] ?? []
        nextAction = json["nextAction"] as? String ?? ""
    }

    // MARK: - Offline Fallbacks

    private func generateOfflineNarrative() -> String {
        let pct = Int(journey.progress * 100)
        if pct == 0 {
            return "'\(journey.title)' is ready and waiting. Every great journey begins with a single step — the vision is set, now it's time to build momentum."
        } else if pct < 50 {
            return "You're \(pct)% through '\(journey.title)'. The foundations are being laid. Each completed milestone brings the vision closer to reality."
        } else if pct < 100 {
            return "Impressive progress — \(pct)% through '\(journey.title)'. The finish line is visible. Stay the course and follow through on the remaining milestones."
        } else {
            return "'\(journey.title)' is complete! This achievement is the result of consistent effort, adaptability, and commitment to the vision."
        }
    }

    private func generateOfflineLessons() -> [String] {
        guard journey.progress > 0 else { return [] }
        return ["Consistent small steps compound over time.", "Tracking progress keeps you accountable."]
    }

    private func generateOfflineNextAction(milestones: [Milestone]) -> String {
        if let next = milestones.first(where: { !$0.isCompleted }) {
            return "Focus on completing '\(next.title)' to maintain your journey momentum."
        }
        return "Review your journey progress and plan the next milestone."
    }
}

// MARK: - Milestone Timeline Row

private struct MilestoneTimelineRow: View {
    let milestone: Milestone
    let index: Int
    let isLast: Bool
    let journeyColor: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline dot + line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(milestone.isCompleted
                              ? Color(hex: journeyColor)
                              : DSColors.canvasPrimary)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(Color(hex: journeyColor), lineWidth: 2)
                        )
                    if milestone.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(DSColors.onAccent)
                    }
                }
                if !isLast {
                    Rectangle()
                        .fill(Color(hex: journeyColor).opacity(0.3))
                        .frame(width: 2, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(DSFonts.body(14).bold())
                    .foregroundColor(milestone.isCompleted ? DSColors.textSecondary : DSColors.textPrimary)
                    .strikethrough(milestone.isCompleted)

                if let due = milestone.targetDate {
                    Text(due.formatted(date: .abbreviated, time: .omitted))
                        .font(DSFonts.caption())
                        .foregroundColor(milestone.isOverdue ? .red : DSColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.bottom, isLast ? 0 : 4)
    }
}

// MARK: - Skeleton Row

private struct NarrativeSkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(DSColors.textSecondary.opacity(shimmer ? 0.1 : 0.2))
                    .frame(height: 12)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

#Preview {
    JourneyNarrativeView(
        journey: Journey(title: "Build iAlly", vision: "Ship a personal second brain app")
    )
    .modelContainer(for: [Journey.self, Milestone.self, TaskWork.self], inMemory: true)
}
