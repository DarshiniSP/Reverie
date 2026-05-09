//
//  WeeklyReviewView.swift
//  iAlly
//
//  Phase 2: Conversational Lumina Weekly Review
//  PAI generates personalised questions based on actual week activity.
//  Stats and progress cards remain as context below the conversation.
//

import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var plans: [Plan]
    @Query private var journeys: [Journey]
    @Query(filter: #Predicate<TaskWork> { $0.completedAt != nil }) private var completedTasks: [TaskWork]
    @Query private var allTasks: [TaskWork]

    // Conversation state
    @State private var reviewMessages: [LuminaMessage] = []
    @State private var isTyping = false
    @State private var userReply = ""
    @State private var reviewStarted = false
    @State private var reviewSaved = false
    @FocusState private var replyFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        statsStrip
                        conversationSection(proxy: proxy)
                        Divider().padding(.horizontal)
                        plansSection
                        journeysSection
                        reflectionsSection
                    }
                    .padding(.vertical)
                }
            }
            .background(DSColors.canvasPrimary)
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                }
            }
            .task {
                if !reviewStarted {
                    reviewStarted = true
                    await startConversationalReview()
                }
            }
        }
    }

    // MARK: - Stats strip (compact)

    private var statsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CompactStatPill(icon: "checkmark.circle.fill", value: "\(completedTasksThisWeek)", label: "Completed", color: DSColors.success)
                CompactStatPill(icon: "arrow.up.arrow.down", value: weekTrendLabel, label: "vs last week", color: weekComparison >= 0 ? .green : .orange)
                CompactStatPill(icon: "target", value: "\(activePlans)", label: "Plans", color: DSColors.accentPrimary)
                CompactStatPill(icon: "flag.fill", value: "\(activeJourneys)", label: "Journeys", color: DSColors.accentSecondary)
                CompactStatPill(icon: "flame.fill", value: "\(currentStreak)d", label: "Streak", color: DSColors.warning)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Conversational section

    private func conversationSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(DSColors.accentPrimary)
                Text("Lumina Review")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
            }
            .padding(.horizontal)

            // Message bubbles
            VStack(spacing: 10) {
                ForEach(reviewMessages) { msg in
                    reviewBubble(msg)
                        .id(msg.id)
                }
                if isTyping {
                    HStack {
                        TypingDotsView()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(DSColors.canvasSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .id("typing")
                }
            }
            .onChange(of: reviewMessages.count) { _, _ in
                scrollToLatest(proxy: proxy)
            }
            .onChange(of: isTyping) { _, _ in
                scrollToLatest(proxy: proxy)
            }

            // Reply input
            if reviewStarted && !reviewMessages.isEmpty {
                HStack(spacing: 8) {
                    TextField("Your reflection…", text: $userReply, axis: .vertical)
                        .font(DSFonts.body())
                        .lineLimit(1...4)
                        .focused($replyFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DSColors.canvasSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        sendReply()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(
                                userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? DSColors.textSecondary : DSColors.accentPrimary
                            )
                    }
                    .disabled(userReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func reviewBubble(_ msg: LuminaMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if msg.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(DSColors.accentPrimary)
                    .frame(width: 28, height: 28)
                    .background(DSColors.accentPrimary.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 48)
            }

            Text(msg.content)
                .font(DSFonts.body())
                .foregroundColor(msg.role == .user ? DSColors.onAccent : DSColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    msg.role == .user ? DSColors.accentPrimary : DSColors.canvasSecondary
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if msg.role == .user {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DSColors.textSecondary)
            } else {
                Spacer(minLength: 48)
            }
        }
        .padding(.horizontal)
    }

    private func scrollToLatest(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = reviewMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Plans section

    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plans Progress")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal)
            ForEach(activePlansList) { plan in
                PlanProgressCard(plan: plan)
            }
        }
    }

    // MARK: - Journeys section

    private var journeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Journey Milestones")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal)
            ForEach(journeys.filter { !$0.isDeleted }) { journey in
                JourneyStatusCard(journey: journey)
            }
        }
    }

    // MARK: - Reflections section

    private var reflectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Reflections")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal)

            if completedTasksWithReflections.isEmpty {
                Card {
                    VStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.system(size: 36))
                            .foregroundColor(DSColors.textSecondary.opacity(0.5))
                        Text("No task reflections this week")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .padding()
                }
                .padding(.horizontal)
            } else {
                ForEach(completedTasksWithReflections) { task in
                    ReflectionCard(task: task)
                }
            }
        }
    }

    // MARK: - Conversational review logic

    private func startConversationalReview() async {
        let router = LuminaInferenceRouter.shared
        guard router.isConfigured(router.selectedProviderID) else {
            reviewMessages.append(LuminaMessage(role: .assistant, content:
                "To start your weekly review, configure an AI provider in Settings → Lumina AI → AI Provider."))
            return
        }

        let context = buildWeekContext()
        let systemPrompt = """
        You are Lumina, a compassionate personal second brain assistant conducting a weekly review.
        Below is a summary of the user's week. Start with a warm 2-sentence personalised observation
        about their week, then ask ONE thoughtful, open-ended reflection question to help them grow.
        Keep your opening under 80 words. Be encouraging, specific, and never generic.

        Week data:
        \(context)
        """
        let msgs = [PAIChatMessage(role: "user", content: systemPrompt)]

        isTyping = true
        var opening = LuminaMessage(role: .assistant, content: "")
        reviewMessages.append(opening)
        let idx = 0

        do {
            for try await token in router.stream(messages: msgs) {
                opening.content += token
                reviewMessages[idx] = opening
            }
        } catch {
            reviewMessages[idx] = LuminaMessage(
                role: .assistant,
                content: "Hi! Let's reflect on your week. What felt most meaningful to you this week?"
            )
        }

        isTyping = false
    }

    private func sendReply() {
        let text = userReply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        userReply = ""

        reviewMessages.append(LuminaMessage(role: .user, content: text))

        Task {
            isTyping = true
            // Build history for PAI continuation
            let history: [PAIChatMessage] = reviewMessages.map {
                PAIChatMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content)
            }

            var response = LuminaMessage(role: .assistant, content: "")
            reviewMessages.append(response)
            let idx = reviewMessages.count - 1

            do {
                for try await token in LuminaInferenceRouter.shared.stream(messages: history) {
                    response.content += token
                    reviewMessages[idx] = response
                }
            } catch {
                reviewMessages[idx] = LuminaMessage(
                    role: .assistant,
                    content: "Thank you for sharing that. What else stands out about this week?"
                )
            }
            isTyping = false
        }
    }

    private func saveAndDismiss() {
        // Record the full conversation as a weekly reflection in local memory
        if !reviewMessages.isEmpty {
            let userReplies = reviewMessages
                .filter { $0.role == .user }
                .map { $0.content }
                .joined(separator: " | ")
            if !userReplies.isEmpty {
                PAIMemoryBridge.shared.recordWeeklyReflection(summary: userReplies)
            }
        }
        dismiss()
    }

    // MARK: - Week context builder

    private func buildWeekContext() -> String {
        var parts: [String] = []
        parts.append("Tasks completed this week: \(completedTasksThisWeek)")
        parts.append("vs previous week: \(weekTrendLabel)")
        if activePlans > 0 { parts.append("Active plans: \(activePlans)") }
        if activeJourneys > 0 { parts.append("Active journeys: \(activeJourneys)") }
        parts.append("Current streak: \(currentStreak) days")

        let topTasks = completedTasks
            .compactMap { task -> (task: TaskWork, date: Date)? in
                guard let d = task.completedAt else { return nil }
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
                return d >= weekAgo ? (task, d) : nil
            }
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map { $0.task.title }
        if !topTasks.isEmpty {
            parts.append("Recent completions: \(topTasks.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Computed properties

    private var completedTasksThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completedTasks.filter { task in
            guard let d = task.completedAt else { return false }
            return d >= weekAgo && !task.isSubtask
        }.count
    }

    private var activePlans: Int {
        plans.filter { !$0.isDeleted && ($0.status == .active || $0.status == nil) }.count
    }

    private var activeJourneys: Int {
        journeys.filter { !$0.isDeleted && ($0.status == .inProgress || $0.status == .notStarted) }.count
    }

    private var activePlansList: [Plan] {
        plans.filter { !$0.isDeleted && ($0.status == .active || $0.status == nil) }
    }

    private var completedTasksWithReflections: [TaskWork] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        return completedTasks.filter { task in
            guard let d = task.completedAt else { return false }
            guard let r = task.completionReflection, !r.isEmpty else { return false }
            return d >= weekAgo
        }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }

    private var weekComparison: Int {
        let cal = Calendar.current
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: Date())!
        let weekAgo     = cal.date(byAdding: .day, value: -7,  to: Date())!
        let lastWeek    = completedTasks.filter {
            guard let d = $0.completedAt else { return false }
            return d >= twoWeeksAgo && d < weekAgo && !$0.isSubtask
        }.count
        return completedTasksThisWeek - lastWeek
    }

    private var weekTrendLabel: String {
        let diff = weekComparison
        if diff > 0 { return "+\(diff)" }
        if diff < 0 { return "\(diff)" }
        return "="
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var check = cal.startOfDay(for: Date())
        for _ in 0..<30 {
            let hasTasks = completedTasks.contains {
                guard let d = $0.completedAt else { return false }
                return cal.isDate(d, inSameDayAs: check) && !$0.isSubtask
            }
            guard hasTasks else { break }
            streak += 1
            check = cal.date(byAdding: .day, value: -1, to: check) ?? check
        }
        return streak
    }
}

// MARK: - Compact stat pill

struct CompactStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(DSFonts.headline(15))
                    .foregroundColor(color)
                Text(label)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Summary stat (legacy — kept for compatibility)
struct SummaryStatView: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(DSFonts.title(28)).foregroundColor(color)
            Text(label).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Plan Progress Card (unchanged)
struct PlanProgressCard: View {
    let plan: Plan
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: plan.icon).foregroundColor(Color(hex: plan.colorHex))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name).font(DSFonts.body()).foregroundColor(DSColors.textPrimary)
                        if let goal = plan.goal {
                            Text(goal).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary).lineLimit(1)
                        }
                    }
                    Spacer()
                    Text("\(Int(plan.completionRate * 100))%")
                        .font(DSFonts.headline(20))
                        .foregroundColor(Color(hex: plan.colorHex))
                }
                ProgressView(value: plan.completionRate).tint(Color(hex: plan.colorHex))
                HStack {
                    Text("\(plan.completedTaskCount) of \(plan.completedTaskCount + plan.activeTaskCount) tasks")
                        .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                    Spacer()
                    if let tm = plan.targetMetric {
                        Text(tm).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Journey Status Card (unchanged)
struct JourneyStatusCard: View {
    let journey: Journey
    private var completed: Int { journey.milestones?.filter { $0.isCompleted }.count ?? 0 }
    private var total: Int { journey.milestones?.count ?? 0 }
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: journey.icon).foregroundColor(Color(hex: journey.colorHex))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(journey.title).font(DSFonts.body()).foregroundColor(DSColors.textPrimary)
                        if let status = journey.status {
                            Text(status.rawValue).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                        }
                    }
                    Spacer()
                    if total > 0 {
                        Text("\(completed)/\(total)")
                            .font(DSFonts.headline(16))
                            .foregroundColor(Color(hex: journey.colorHex))
                    }
                }
                if total > 0 {
                    ProgressView(value: Double(completed) / Double(total)).tint(Color(hex: journey.colorHex))
                }
                if let targetDate = journey.targetDate {
                    HStack {
                        Image(systemName: "calendar").font(DSFonts.caption())
                        Text("Target: \(targetDate.formatted(date: .abbreviated, time: .omitted))").font(DSFonts.caption())
                        Spacer()
                        if let days = journey.daysRemaining {
                            Text("\(days) days left").font(DSFonts.caption())
                                .foregroundColor(days < 7 ? .orange : DSColors.textSecondary)
                        }
                    }
                    .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Reflection Card (unchanged)
struct ReflectionCard: View {
    let task: TaskWork
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(DSColors.success)
                    VStack(alignment: .leading, spacing: 4) {
                        if task.isSubtask, let parent = task.parentTask {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.turn.down.right").font(DSFonts.caption())
                                Text("Subtask of: \(parent.title)").font(DSFonts.caption())
                            }.foregroundColor(DSColors.textSecondary)
                        }
                        Text(task.title).font(DSFonts.body()).foregroundColor(DSColors.textPrimary).fontWeight(.medium)
                        if let d = task.completedAt {
                            Text(d.formatted(date: .abbreviated, time: .omitted)).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                        }
                    }
                    Spacer()
                }
                if let r = task.completionReflection {
                    Text(r).font(DSFonts.body(14)).foregroundColor(DSColors.textSecondary).padding(.leading, 28)
                }
                if let plan = task.plan {
                    HStack(spacing: 4) {
                        Image(systemName: plan.lifeDomain.icon).font(DSFonts.caption())
                        Text(plan.name).font(DSFonts.caption())
                    }.foregroundColor(Color(hex: plan.colorHex)).padding(.leading, 28)
                } else if let journey = task.journey {
                    HStack(spacing: 6) {
                        Image(systemName: journey.icon).font(DSFonts.caption())
                        Text(journey.title).font(DSFonts.caption())
                    }.foregroundColor(Color(hex: journey.colorHex)).padding(.leading, 28)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Enhanced Stat Card (unchanged)
struct EnhancedStatCard: View {
    let icon: String; let value: String; let label: String; let trend: Int?; let color: Color
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon).font(DSFonts.headline()).foregroundColor(color)
                    Spacer()
                    if let t = trend, t != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: t > 0 ? "arrow.up" : "arrow.down").font(DSFonts.caption())
                            Text("\(abs(t))").font(DSFonts.caption()).fontWeight(.semibold)
                        }.foregroundColor(t > 0 ? .green : .orange)
                    }
                }
                Text(value).font(DSFonts.title(32)).foregroundColor(color)
                Text(label).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
            }
            .padding()
        }
    }
}

#Preview {
    WeeklyReviewView()
        .modelContainer(for: [Plan.self, Journey.self, TaskWork.self], inMemory: true)
}
