//
//  UpcomingContentView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct UpcomingContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<TaskWork> { task in
        task.completedAt == nil && task.dueDate != nil
    }, sort: \TaskWork.dueDate)
    private var allUpcomingTasks: [TaskWork]
    
    private var upcomingTasks: [TaskWork] {
        allUpcomingTasks.filter { !$0.isSubtask }
    }
    
    // Helper to determine task source
    private func taskSource(_ task: TaskWork) -> (type: String, name: String, icon: String, color: String, destination: AnyView?) {
        if let plan = task.plan {
            return ("Plan", plan.name, plan.lifeDomain.icon, plan.colorHex, AnyView(PlanDetailView(plan: plan)))
        } else if let journey = task.journey {
            return ("Journey", journey.title, journey.icon, journey.colorHex, AnyView(JourneyDetailView(journey: journey)))
        } else if task.routine != nil {
            return ("Routine", "Recurring", "repeat.circle.fill", "#6C757D", nil)
        } else {
            return ("Inbox", "Unorganized", "tray.fill", "#6C757D", nil)
        }
    }
    
    private var groupedTasks: [(String, [TaskWork])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        // NOTE: Overdue and Today tasks are intentionally EXCLUDED here because
        // they already appear in the Today tab (TodayContentView).  Upcoming only
        // shows tasks due from tomorrow onwards.
        var grouped: [String: [TaskWork]] = [
            "Tomorrow": [],
            "This Week": [],
            "Later": []
        ]

        for task in upcomingTasks {
            guard let dueDate = task.dueDate else { continue }
            let taskDate = calendar.startOfDay(for: dueDate)

            // Skip overdue and today — those belong in TodayContentView.
            guard taskDate >= tomorrow else { continue }

            if taskDate == tomorrow {
                grouped["Tomorrow"]?.append(task)
            } else if taskDate < nextWeek {
                grouped["This Week"]?.append(task)
            } else {
                grouped["Later"]?.append(task)
            }
        }

        return [
            ("Tomorrow", grouped["Tomorrow"] ?? []),
            ("This Week", grouped["This Week"] ?? []),
            ("Later", grouped["Later"] ?? [])
        ].filter { tuple in
            !tuple.1.isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if groupedTasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))
            
            Text("Nothing scheduled")
                .font(DSFonts.title(20))
                .foregroundColor(DSColors.textPrimary)
            
            Text("Tasks with due dates will appear here")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    // MARK: - Task List
    private var taskListView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(groupedTasks, id: \.0) { section, tasks in
                    sectionView(title: section, tasks: tasks)
                }
            }
            .padding(.vertical)
        }
    }
    
    private func sectionView(title: String, tasks: [TaskWork]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text("\(tasks.count)")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding(.horizontal)
            
            ForEach(tasks) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DSFonts.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? DSColors.onAccent : DSColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? DSColors.accentPrimary : DSColors.canvasPrimary)
                .cornerRadius(UIConstants.CornerRadius.round)
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.CornerRadius.round)
                        .stroke(DSColors.accentPrimary, lineWidth: isSelected ? 0 : 1)
                )
        }
    }
}

#Preview {
    UpcomingContentView()
        .modelContainer(for: [TaskWork.self], inMemory: true)
}
