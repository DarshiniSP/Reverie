//
//  MilestoneDetailView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct MilestoneDetailView: View {
    @Bindable var milestone: Milestone
    let journey: Journey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showAddTask = false
    @State private var showDeleteAlert = false

    private var milestoneTasks: [TaskWork] {
        (milestone.tasks ?? []).sorted(by: {
            switch ($0.dueDate, $1.dueDate) {
            case let (a?, b?): return a < b
            case (_?, nil):    return true
            case (nil, _?):    return false
            default:           return $0.title < $1.title
            }
        })
    }

    var body: some View {
        ZStack {
            DSColors.canvasPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerCard
                    tasksSection
                    deleteSection
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Milestone")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddTask) {
            AddTaskView(preselectedJourney: journey, preselectedMilestone: milestone)
                .environment(\.modelContext, modelContext)
        }
        .alert("Delete Milestone", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(milestone)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Delete \"\(milestone.title)\"? All linked tasks will be unlinked from this milestone.")
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                // Completion toggle + editable title
                HStack(spacing: 12) {
                    Button { toggleComplete() } label: {
                        Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(DSFonts.headline())
                            .foregroundColor(milestone.isCompleted
                                ? Color(hex: journey.colorHex)
                                : DSColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    TextField("Milestone title", text: $milestone.title)
                        .font(DSFonts.title())
                        .foregroundColor(milestone.isCompleted
                            ? DSColors.textSecondary
                            : DSColors.textPrimary)
                        .strikethrough(milestone.isCompleted)
                        .textFieldStyle(.plain)
                }

                Divider()

                // Target date row
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .foregroundColor(milestone.isOverdue ? .red : DSColors.textSecondary)

                    if let targetDate = milestone.targetDate {
                        DatePicker(
                            "Target",
                            selection: Binding(
                                get: { targetDate },
                                set: { milestone.targetDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .foregroundColor(milestone.isOverdue ? .red : DSColors.textPrimary)

                        if milestone.isOverdue {
                            Text("Overdue")
                                .font(DSFonts.body(12))
                                .foregroundColor(DSColors.error)
                        }

                        Button {
                            milestone.targetDate = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DSColors.textSecondary)
                        }
                    } else {
                        Button("Set target date") {
                            milestone.targetDate = Date()
                        }
                        .font(DSFonts.body(15))
                        .foregroundColor(DSColors.accentPrimary)
                    }

                    Spacer()
                }

                // Journey breadcrumb
                HStack(spacing: 6) {
                    Image(systemName: journey.icon)
                        .font(DSFonts.caption())
                        .foregroundColor(Color(hex: journey.colorHex))
                    Text(journey.title)
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            .padding(4)
        }
        .padding(.horizontal)
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)

                if !milestoneTasks.isEmpty {
                    let completed = milestoneTasks.filter { $0.isCompleted }.count
                    Text("\(completed)/\(milestoneTasks.count) completed")
                        .font(DSFonts.body(12))
                        .foregroundColor(DSColors.textSecondary)
                }

                Spacer()

                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DSColors.accentPrimary)
                }
            }
            .padding(.horizontal)

            if milestoneTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(DSFonts.title(34))
                        .foregroundColor(DSColors.textSecondary.opacity(0.4))
                    Text("No tasks yet")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                    Text("Add tasks to track progress toward this milestone.")
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ForEach(milestoneTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskRowView(task: task)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                Label("Delete Milestone", systemImage: "trash")
                    .foregroundColor(DSColors.error)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func toggleComplete() {
        withAnimation {
            if milestone.isCompleted {
                milestone.completedAt = nil
            } else {
                guard milestone.canBeCompleted else { return }
                milestone.completedAt = Date()
                PAIMemoryBridge.shared.recordMilestoneCompleted(milestone: milestone, journey: journey)
                WidgetHelper.shared.reloadAllWidgets()
            }
            try? modelContext.save()
        }
    }
}
