//
//  CompletedTasksListView.swift
//  Reverie
//
//  Shows all completed tasks, grouped by completion date.
//

import SwiftUI
import SwiftData

struct CompletedTasksListView: View {
    @Query(
        filter: #Predicate<TaskWork> { $0.completedAt != nil },
        sort: \TaskWork.completedAt,
        order: .reverse
    )
    private var completedTasks: [TaskWork]

    private var nonSubtaskCompleted: [TaskWork] {
        completedTasks.filter { !$0.isSubtask }
    }

    var body: some View {
        ZStack {
            DSColors.canvasPrimary.ignoresSafeArea()

            if nonSubtaskCompleted.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(DSColors.success.opacity(0.5))
                    Text("No completed tasks yet")
                        .font(DSFonts.body(16))
                        .foregroundColor(DSColors.textSecondary)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(nonSubtaskCompleted) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRowView(task: task)
                                    .opacity(0.6)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Completed Tasks")
        .navigationBarTitleDisplayMode(.inline)
    }
}
