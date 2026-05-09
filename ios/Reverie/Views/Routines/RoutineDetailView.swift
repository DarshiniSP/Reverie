//
//  RoutineDetailView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

/// Displays detailed information and statistics for a specific routine.
/// Shows streaks, completion rate, schedule, resilience metrics, and upcoming tasks.
struct RoutineDetailView: View {
    /// Dismisses the current view when called.
    @Environment(\.dismiss) private var dismiss
    /// Provides access to the SwiftData model context.
    @Environment(\.modelContext) private var modelContext
    /// Controls the presentation of the edit sheet.
    @State private var showEditSheet = false
    /// Controls the presentation of the delete confirmation alert.
    @State private var showDeleteAlert = false
    /// Controls the presentation of the recurring instances view.
    @State private var showInstancesView = false
    /// The routine being displayed.
    let routine: Routine
    /// Query all tasks to filter for this routine
    @Query(sort: \TaskWork.dueDate) private var allTasks: [TaskWork]
    
    /// Computed property for upcoming tasks related to this routine
    private var upcomingTasks: [TaskWork] {
        allTasks.filter { task in
            task.routine?.id == routine.id && task.completedAt == nil
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header: Icon, title, and domain
                HStack(spacing: 16) {
                    Image(systemName: routine.icon)
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: routine.colorHex))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.title)
                            .font(DSFonts.title())
                            .foregroundColor(DSColors.textPrimary)
                        // Life domain label
                        Label(routine.lifeDomain.rawValue, systemImage: routine.lifeDomain.icon)
                            .font(DSFonts.body(14))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                // Consistency stats: streaks and completion
                Card {
                    VStack(spacing: 16) {
                        HStack(spacing: 0) {
                            // Current streak
                            VStack(spacing: 4) {
                                Text("\(routine.currentStreak)")
                                    .font(DSFonts.title(32))
                                    .foregroundColor(DSColors.warning)
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(DSFonts.caption())
                                    Text("Current")
                                        .font(DSFonts.caption())
                                }
                                .foregroundColor(DSColors.warning)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 60)

                            // Longest streak
                            VStack(spacing: 4) {
                                Text("\(routine.longestStreak)")
                                    .font(DSFonts.title(32))
                                    .foregroundColor(Color(hex: routine.colorHex))
                                HStack(spacing: 4) {
                                    Text("🏆")
                                        .font(DSFonts.caption())
                                    Text("Best")
                                        .font(DSFonts.caption())
                                }
                                .foregroundColor(DSColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 60)

                            // Completion rate
                            VStack(spacing: 4) {
                                Text("\(Int(routine.completionRate * 100))%")
                                    .font(DSFonts.title(32))
                                    .foregroundColor(DSColors.success)
                                Text("Consistency")
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Progress bar for completion rate
                        ProgressView(value: routine.completionRate)
                            .tint(Color(hex: routine.colorHex))
                            .frame(height: 6)
                    }
                    .padding(.vertical, 8)
                }

                // Frequency and schedule info
                Card(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Schedule", systemImage: "calendar")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        // Recurrence description
                        Text(RecurrenceRuleBuilder.shared.recurrenceDescription(for: routine))
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textPrimary)

                        // Time of day, if set
                        if let time = routine.timeOfDay {
                            HStack {
                                Image(systemName: "clock")
                                Text(time.formatted(date: .omitted, time: .shortened))
                            }
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                        }
                        
                        // View all instances button
                        Button(action: { showInstancesView = true }) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                Text("View All Instances")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.accentPrimary)
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Next 7 upcoming instances
                Card(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Next Occurrences", systemImage: "calendar.badge.plus")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        
                        ForEach(nextOccurrences, id: \.self) { date in
                            HStack {
                                Image(systemName: "circle")
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.accentPrimary)
                                Text(formatOccurrenceDate(date))
                                    .font(DSFonts.body())
                                Spacer()
                                
                                // Quick actions
                                Menu {
                                    Button {
                                        RecurrenceRuleBuilder.shared.skipInstance(date: date, routine: routine)
                                    } label: {
                                        Label("Skip", systemImage: "xmark.circle")
                                    }
                                    
                                    Button {
                                        // Reschedule would open a date picker sheet
                                        showInstancesView = true
                                    } label: {
                                        Label("Reschedule", systemImage: "calendar.badge.clock")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .foregroundColor(DSColors.textSecondary)
                                }
                            }
                        }
                    }
                }

                // Resilience metrics: streak breaks, recovery, abandonment
                if routine.streakBreakCount > 0 || routine.recoveryCount > 0 {
                    Card(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Resilience", systemImage: "arrow.uturn.forward.circle.fill")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.success)

                            VStack(spacing: 8) {
                                if routine.streakBreakCount > 0 {
                                    HStack {
                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                            .foregroundColor(DSColors.success)
                                        Text("Recovery Rate")
                                            .font(DSFonts.body())
                                        Spacer()
                                        Text("\(Int(routine.recoveryRate * 100))%")
                                            .font(DSFonts.body())
                                            .fontWeight(.semibold)
                                            .foregroundColor(DSColors.success)
                                    }
                                }

                                if routine.longestStreak > 0 {
                                    HStack {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(DSColors.warning)
                                        Text("Longest Streak")
                                            .font(DSFonts.body())
                                        Spacer()
                                        Text("\(routine.longestStreak) days")
                                            .font(DSFonts.body())
                                            .fontWeight(.semibold)
                                            .foregroundColor(DSColors.textPrimary)
                                    }
                                }

                                if routine.currentStreak > 0 {
                                    HStack {
                                        Image(systemName: "flame")
                                            .foregroundColor(DSColors.warning)
                                        Text("Current Streak")
                                            .font(DSFonts.body())
                                        Spacer()
                                        Text("\(routine.currentStreak) days")
                                            .font(DSFonts.body())
                                            .fontWeight(.semibold)
                                            .foregroundColor(DSColors.textPrimary)
                                    }
                                }

                                if routine.abandonmentRate > 0.3 {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(DSColors.warning)
                                        Text("Abandonment Rate")
                                            .font(DSFonts.body())
                                        Spacer()
                                        Text("\(Int(routine.abandonmentRate * 100))%")
                                            .font(DSFonts.body())
                                            .fontWeight(.semibold)
                                            .foregroundColor(DSColors.warning)
                                    }
                                }
                            }
                            .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }

                // Upcoming tasks (limit 5)
                if !upcomingTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming (\(upcomingTasks.count))")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        ForEach(upcomingTasks.prefix(5)) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRowView(task: task)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
        .navigationTitle("Routine Details")
        .navigationBarTitleDisplayMode(.inline)
        // Toolbar: edit and delete actions
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DSColors.error)
                    }

                    Button {
                        showEditSheet = true
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
            }
        }
        // Edit sheet for updating routine
        .sheet(isPresented: $showEditSheet) {
            AddRoutineView(routine: routine)
                .onAppear {
                    // The view will load routine data automatically
                }
        }
        // Delete confirmation alert
        .alert("Delete Routine", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(routine)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("This will delete the routine and all its generated tasks. This action cannot be undone.")
        }
        // Recurring instances full screen sheet
        .sheet(isPresented: $showInstancesView) {
            RecurringTaskInstanceView(routine: routine)
        }
    }
    
    /// Get the next 7 occurrences for the routine
    private var nextOccurrences: [Date] {
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
        let dates = RecurrenceRuleBuilder.shared.occurrences(from: Date(), to: endDate, routine: routine)
        return Array(dates.prefix(7))
    }
    
    /// Format an occurrence date for display
    private func formatOccurrenceDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    /// Formats an array of weekday indices (1=Mon, 7=Sun) into a comma-separated string of short day names.
    /// - Parameter days: Array of weekday indices.
    /// - Returns: Comma-separated string of day names (e.g., "Mon, Wed, Fri").
    private func formatActiveDays(_ days: [Int]) -> String {
        let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days.sorted().map { dayLabels[$0 - 1] }.joined(separator: ", ")
    }
}
