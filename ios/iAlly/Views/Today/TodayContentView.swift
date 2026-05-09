//
//  TodayContentView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import Combine
import SwiftUI
import SwiftData

struct TodayContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var now = Date()
    @State private var todayEnergy: DailyEnergyLevel? = EnergyCheckInStore.load()
    @State private var todayStress: DailyStressLevel? = StressCheckInStore.load()
    // Query ALL tasks (including completed) so the Completed Tasks section can show
    // tasks that were ticked off today, and routine stats can track X/Y progress.
    @Query(sort: \TaskWork.dueDate)
    private var allTasks: [TaskWork]
    
    // Query all routines
    @Query(filter: #Predicate<Routine> { routine in
        routine.isActive
    })
    private var activeRoutines: [Routine]
    
    // Query unread insights
    @Query(filter: #Predicate<GrowthInsight> { insight in
        !insight.isRead
    }, sort: \GrowthInsight.generatedDate, order: .reverse)
    private var unreadInsights: [GrowthInsight]
    
    private var latestInsight: GrowthInsight? {
        unreadInsights.first
    }
    
    // MARK: - Computed task categories

    private var overdueTasks: [TaskWork] {
        // Overdue section shows any incomplete non-subtask with a due date in the past
        // (including tasks due earlier today whose specific time has already passed).
        return allTasks.filter { task in
            task.dueDate != nil && task.isOverdue && !task.isCompleted && !task.isSubtask && task.routine == nil
        }
    }

    private var todayTasks: [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let filtered = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            // Exclude tasks that are already overdue (their time has passed) — those go to Overdue.
            return taskDate >= today && taskDate < tomorrow && !task.isOverdue && task.routine == nil && !task.isSubtask && !task.isCompleted
        }
        return energySorted(filtered)
    }

    private func energySorted(_ tasks: [TaskWork]) -> [TaskWork] {
        switch todayEnergy {
        case .low:
            // Low energy: tackle easy small tasks first, save heavy work for later
            return tasks.sorted {
                let sizeOrder: (TaskSize) -> Int = { s in
                    switch s { case .small: return 0; case .medium: return 1; case .large: return 2 }
                }
                let s0 = sizeOrder($0.size), s1 = sizeOrder($1.size)
                if s0 != s1 { return s0 < s1 }
                return priorityOrder($0) > priorityOrder($1)
            }
        case .high:
            // High energy: tackle urgent & high-priority tasks first
            return tasks.sorted {
                let p0 = priorityOrder($0), p1 = priorityOrder($1)
                if p0 != p1 { return p0 > p1 }
                let sizeOrder: (TaskSize) -> Int = { s in
                    switch s { case .large: return 0; case .medium: return 1; case .small: return 2 }
                }
                return sizeOrder($0.size) < sizeOrder($1.size)
            }
        default:
            // Medium / no selection: standard priority then due date
            return tasks.sorted {
                let p0 = priorityOrder($0), p1 = priorityOrder($1)
                if p0 != p1 { return p0 > p1 }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        }
    }

    private func priorityOrder(_ task: TaskWork) -> Int {
        switch task.priority {
        case .urgent: return 4
        case .high:   return 3
        case .medium: return 2
        case .low, nil: return 1
        }
    }

    private var todayRoutineTasks: [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return allTasks.filter { task in
            guard let routine = task.routine,
                  let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return routine.isActive && taskDate >= today && taskDate < tomorrow && !task.isSubtask && !task.isCompleted
        }
    }

    // All today's routine tasks regardless of completion — used for the X/Y stats header.
    private var allTodayRoutineTasksForStats: [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return allTasks.filter { task in
            guard let routine = task.routine,
                  let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return routine.isActive && taskDate >= today && taskDate < tomorrow && !task.isSubtask
        }
    }

    // Tasks completed today (any section) shown in the dedicated Completed Tasks section.
    private var completedTodayTasks: [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        return allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            let completedDay = calendar.startOfDay(for: completedAt)
            return completedDay >= today && completedDay < tomorrow && !task.isSubtask
        }
        .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var quickWinTasks: [TaskWork] {
        // Quick wins: any small unscheduled tasks (no due date, no journey)
        return allTasks.filter { task in
            task.dueDate == nil &&
            task.size == .small &&
            task.journey == nil &&
            !task.isSubtask &&
            !task.isCompleted
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(3)
        .map { $0 }
    }

    // Upcoming tasks — due in the next 2–7 days (not today, not overdue)
    private var upcomingTasks: [TaskWork] {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let sevenDaysOut = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))!
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return taskDate >= tomorrow && taskDate < sevenDaysOut && !task.isCompleted && !task.isSubtask && task.routine == nil
        }
        .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    // Unscheduled tasks — no due date, medium/large, not small (small = quick wins)
    // These are tasks the user captured without a date — show them so nothing disappears
    private var unscheduledTasks: [TaskWork] {
        return allTasks.filter { task in
            task.dueDate == nil &&
            task.size != .small &&
            task.journey == nil &&
            task.plan == nil &&
            !task.isSubtask &&
            !task.isCompleted &&
            !task.isInbox
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(5)
        .map { $0 }
    }

    private var todayStats: (overdue: Int, dueToday: Int, routines: Int, routinesCompleted: Int) {
        let allRoutines = allTodayRoutineTasksForStats
        let routinesCompleted = allRoutines.filter { $0.isCompleted }.count
        return (overdueTasks.count, todayTasks.count, allRoutines.count, routinesCompleted)
    }

    private var resilienceScore: ResilienceScore {
        ResilienceEngine.shared.compute(context: modelContext)
    }

    private var cognitiveLoad: CognitiveLoad {
        ResilienceEngine.shared.cognitiveLoad(context: modelContext)
    }
    
    // MARK: - Greeting helpers

    private var greetingPhrase: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var greetingName: String {
        let name = UserProfile.current.name
        return name.isEmpty ? "" : ", \(name)"
    }

    private var greetingSubtitle: String {
        let stats = todayStats
        if stats.overdue > 0 {
            return "\(stats.overdue) overdue task\(stats.overdue == 1 ? "" : "s") need your attention."
        } else if stats.dueToday > 0 {
            return "You have \(stats.dueToday) task\(stats.dueToday == 1 ? "" : "s") lined up for today."
        } else {
            return "Nothing due today. Great time to get ahead."
        }
    }

    private var greetingAccentColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return Color(hex: "F59E0B") // amber morning
        case 12..<17: return DSColors.accentPrimary
        case 17..<21: return Color(hex: "F97316") // orange evening
        default:      return DSColors.accentSecondary
        }
    }

    // MARK: - Views

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greetingPhrase)\(greetingName)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)

                Text(greetingSubtitle)
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(greetingAccentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: greetingIcon)
                    .font(.system(size: 22))
                    .foregroundColor(greetingAccentColor)
            }
        }
        .padding(.horizontal, 4)
    }

    private var greetingIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "sun.and.horizon.fill"
        case 12..<17: return "sun.max.fill"
        default:      return "moon.stars.fill"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Personalised greeting
                greetingHeader

                // Calendar Events Section
                CalendarEventsSection(date: Date())

                // Cognitive Load Card (replaces generic stats)
                cognitiveLoadCard

                // Crisis banner — shown only when resilience is critical
                if resilienceScore.level == .critical {
                    CrisisSupportBanner()
                }

                // Overdue Section
                if !overdueTasks.isEmpty {
                    taskSection(
                        title: "Overdue",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: DSColors.error,
                        tasks: overdueTasks
                    )
                }
                
                // Due Today Section (always visible — shows placeholder when empty)
                dueTodaySection

                // Upcoming Section (next 2–7 days)
                if !upcomingTasks.isEmpty {
                    upcomingSection
                }

                // Today's Routines Section
                if !todayRoutineTasks.isEmpty {
                    routineTasksSection
                }

                // Quick Wins Section
                if !quickWinTasks.isEmpty {
                    quickWinsSection
                }

                // Unscheduled tasks (captured without a date — so they never disappear)
                if !unscheduledTasks.isEmpty {
                    unscheduledSection
                }

                // Resilience peek card — taps to Resilience tab
                resiliencePeekCard

                // View Completed button — always shown when there are completed tasks today
                if !completedTodayTasks.isEmpty {
                    viewCompletedCard
                }

                // Empty State (only when truly nothing at all)
                if overdueTasks.isEmpty && todayTasks.isEmpty && upcomingTasks.isEmpty && todayRoutineTasks.isEmpty && quickWinTasks.isEmpty && unscheduledTasks.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            // Re-evaluate computed properties so tasks whose due time just passed
            // move from "Due Today" into "Overdue" without any manual refresh.
            now = date
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
    }
    
    // MARK: - Cognitive Load Card
    // Based on Sweller's Cognitive Load Theory (1988):
    // complexity = sum of task weights (small=1, medium=2, large=3.5)
    // context switch penalty = (distinct domains - 2) × 2
    // overdue pressure = overdueCount × 1.5
    private var cognitiveLoadCard: some View {
        let load = cognitiveLoad
        let color = Color(hex: load.level.colorHex)
        return VStack(spacing: 0) {
            LinearGradient(
                colors: [color.opacity(0.6), color.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))

            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: load.level.icon)
                            .foregroundColor(color)
                            .font(.system(size: 14))
                        Text("Cognitive Load")
                            .font(DSFonts.label(13))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    Spacer()
                    Text(now.formatted(date: .abbreviated, time: .omitted))
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textTertiary)
                }

                HStack(alignment: .center, spacing: 0) {
                    // Load level badge
                    VStack(spacing: 4) {
                        Text(load.level.rawValue)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(color)
                        Text("today's load")
                            .font(.system(size: 10))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 40)

                    // Task count
                    VStack(spacing: 4) {
                        Text("\(load.taskCount)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(DSColors.textPrimary)
                        Text("in scope")
                            .font(.system(size: 10))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    if load.activeDomains > 0 {
                        Divider().frame(height: 40)
                        VStack(spacing: 4) {
                            Text("\(load.activeDomains)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(DSColors.textPrimary)
                            Text("domains")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if load.overdueCount > 0 {
                        Divider().frame(height: 40)
                        VStack(spacing: 4) {
                            Text("\(load.overdueCount)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(DSColors.error)
                            Text("overdue")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Advice line
                Text(load.level.advice)
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(16)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: DSColors.shadow, radius: 12, x: 0, y: 3)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DSColors.divider, lineWidth: 0.5))
    }

    // MARK: - Summary Card (kept for backward compat — replaced by cognitiveLoadCard above)
    private var summaryCard: some View {
        VStack(spacing: 0) {
            // Gradient accent strip
            LinearGradient(
                colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))

            VStack(spacing: 16) {
                HStack {
                    Label("Today's Overview", systemImage: "chart.bar.fill")
                        .font(DSFonts.label(13))
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                    Text(now.formatted(date: .abbreviated, time: .omitted))
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textTertiary)
                }

                HStack(spacing: 0) {
                    if todayStats.overdue > 0 {
                        StatItem(
                            value: "\(todayStats.overdue)",
                            label: "Overdue",
                            icon: "exclamationmark.circle.fill",
                            color: DSColors.error
                        )
                        Divider().frame(height: 40)
                    }

                    StatItem(
                        value: "\(todayStats.dueToday)",
                        label: "Due Today",
                        icon: "calendar.circle.fill",
                        color: DSColors.accentPrimary
                    )

                    if todayStats.routines > 0 {
                        Divider().frame(height: 40)
                        StatItem(
                            value: "\(todayStats.routinesCompleted)/\(todayStats.routines)",
                            label: "Routines",
                            icon: "repeat.circle.fill",
                            color: DSColors.success
                        )
                    }
                }
            }
            .padding(16)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: DSColors.shadow, radius: 12, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DSColors.divider, lineWidth: 0.5)
        )
    }
    
    private var energySortHint: String? {
        switch todayEnergy {
        case .low:    return "Easy tasks first"
        case .high:   return "Urgent first"
        case .medium: return "By priority"
        case .none:   return nil
        }
    }

    // MARK: - Task Section
    private func taskSection(title: String, icon: String, iconColor: Color, tasks: [TaskWork], energyHint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text("\(title) (\(tasks.count))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                if let hint = energyHint {
                    Label(hint, systemImage: "arrow.up.arrow.down")
                        .font(DSFonts.caption(11))
                        .foregroundColor(DSColors.accentPrimary.opacity(0.7))
                }
            }
            .padding(.horizontal, 4)

            ForEach(tasks.prefix(5)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task, showOverdueIndicator: title == "Overdue")
                }
            }

            if tasks.count > 5 {
                Text("+ \(tasks.count - 5) more")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Due Today Section (always visible)
    private var dueTodaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(Color(hex: "FF7034"))
                Text("Due Today (\(todayTasks.count))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                if let hint = energySortHint {
                    Label(hint, systemImage: "arrow.up.arrow.down")
                        .font(DSFonts.caption(11))
                        .foregroundColor(DSColors.accentPrimary.opacity(0.7))
                }
            }
            .padding(.horizontal, 4)

            if todayTasks.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(DSColors.success.opacity(0.6))
                    Text("Nothing due today — you're clear!")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DSColors.canvasSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(todayTasks.prefix(5)) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskRowView(task: task)
                    }
                }
                if todayTasks.count > 5 {
                    Text("+ \(todayTasks.count - 5) more")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Upcoming Section (next 2–7 days)
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(DSColors.accentPrimary)
                Text("Upcoming (\(upcomingTasks.count))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text("Next 7 days")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding(.horizontal, 4)

            ForEach(upcomingTasks.prefix(5)) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                }
            }
            if upcomingTasks.count > 5 {
                NavigationLink(destination: UpcomingContentView()) {
                    Text("View all \(upcomingTasks.count) upcoming →")
                        .font(DSFonts.caption(12))
                        .foregroundColor(DSColors.accentPrimary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    // MARK: - Routine Tasks Section
    private var routineTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .foregroundColor(DSColors.success)
                Text("Today's Routines (\(todayStats.routinesCompleted)/\(todayStats.routines))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                if todayStats.routines > 0 {
                    Text("\(Int(Double(todayStats.routinesCompleted) / Double(todayStats.routines) * 100))%")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.success)
                }
            }
            .padding(.horizontal, 4)
            
            ForEach(todayRoutineTasks) { task in
                VStack(spacing: 4) {
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskRowView(task: task)
                    }
                    if let streak = task.routine?.currentStreak, streak > 1 {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                Text("\(streak) day streak")
                                    .font(DSFonts.caption(11))
                            }
                            .foregroundColor(DSColors.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DSColors.warning.opacity(0.10))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - View Completed Card (prominent, full-width)
    private var viewCompletedCard: some View {
        NavigationLink(destination: CompletedTasksListView()) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(DSColors.success.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(DSColors.success)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("View Completed Tasks")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(DSColors.textPrimary)
                    Text("\(completedTodayTasks.count) task\(completedTodayTasks.count == 1 ? "" : "s") done today — great work!")
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DSColors.textTertiary)
            }
            .padding(16)
            .background(DSColors.success.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DSColors.success.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resilience Peek Card (taps to Resilience tab)
    private var resiliencePeekCard: some View {
        let score = resilienceScore
        let color = Color(hex: score.level.colorHex)
        return Button {
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToTab"),
                object: nil,
                userInfo: ["tabIndex": 3]
            )
        } label: {
            HStack(spacing: 14) {
                // Ring gauge (mini)
                ZStack {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 5)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: min(CGFloat(score.value) / 100.0, 1.0))
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(score.value))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Resilience Index")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(DSColors.textPrimary)
                        Text(score.level.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(score.level.shortMessage)
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DSColors.textTertiary)
            }
            .padding(14)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: DSColors.shadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Growth Insight Card
    private func insightCard(_ insight: GrowthInsight) -> some View {
        Card(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: insight.insightType.icon)
                    .font(DSFonts.headline())
                    .foregroundColor(Color(insight.insightType.color))
                    .frame(width: 40, height: 40)
                    .background(Color(insight.insightType.color).opacity(0.15))
                    .cornerRadius(UIConstants.CornerRadius.standard)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Growth Insight")
                            .font(DSFonts.label(12))
                            .foregroundColor(DSColors.textSecondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        // Confidence indicator
                        HStack(spacing: 3) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(index < Int(insight.confidenceScore * 3) ? Color(insight.insightType.color) : Color.gray.opacity(0.3))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                    
                    Text(insight.insightText)
                        .font(DSFonts.body(15))
                        .foregroundColor(DSColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Button {
                        markInsightAsRead(insight)
                    } label: {
                        Text("Got it")
                            .font(DSFonts.label(13))
                            .foregroundColor(Color(insight.insightType.color))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private func markInsightAsRead(_ insight: GrowthInsight) {
        withAnimation {
            insight.isRead = true
            try? modelContext.save()
        }
    }
    
    // MARK: - Quick Wins Section
    private var quickWinsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(DSColors.warning)
                Text("Quick Wins")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text("Easy tasks to start")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding(.horizontal, 4)
            
            ForEach(quickWinTasks) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                }
            }
        }
    }
    
    // MARK: - Unscheduled Section
    private var unscheduledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.and.arrow.down.fill")
                    .foregroundColor(DSColors.textSecondary)
                Text("No Date Set (\(unscheduledTasks.count))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text("Assign a date →")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.accentPrimary.opacity(0.7))
            }
            .padding(.horizontal, 4)

            ForEach(unscheduledTasks) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                        .opacity(0.85)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DSColors.success.opacity(0.10))
                    .frame(width: 110, height: 110)
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColors.success, DSColors.accentPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .allowsHitTesting(false)

            VStack(spacing: 8) {
                Text("All Caught Up")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)

                Text("Nothing due today. A great time to\nget ahead or rest intentionally.")
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, 60)
    }
}

#Preview {
    TodayContentView()
        .modelContainer(for: [TaskWork.self, Routine.self], inMemory: true)
}
