//
//  TaskDetailView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskWork
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query private var plans: [Plan]
    @Query private var journeys: [Journey]

    /// Pre-computed map of LifeDomain → Plan to avoid type-check timeout in view builder
    private var plansByDomain: [LifeDomain: Plan] {
        Dictionary(uniqueKeysWithValues:
            LifeDomain.allCases.compactMap { domain -> (LifeDomain, Plan)? in
                guard let plan = plans.first(where: { $0.lifeDomain == domain }) else { return nil }
                return (domain, plan)
            }
        )
    }
    
    @State private var showDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                TextField("Task title", text: $task.title)
                    .font(DSFonts.title())
                    .foregroundColor(DSColors.textPrimary)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("taskTitleField")
                
                // Detail
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    TextField("Add details", text: Binding(
                        get: { task.detail ?? "" },
                        set: { task.detail = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    .accessibilityIdentifier("taskDetailField")
                }
                
                // Why it matters
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why It Matters")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    TextField("Remind yourself why this matters", text: Binding(
                        get: { task.whyItMatters ?? "" },
                        set: { task.whyItMatters = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(2...4)
                }

                // Attributes
                VStack(alignment: .leading, spacing: 16) {
                    Text("Attributes")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    // Task Size - Radio Buttons
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task Size")
                            .font(DSFonts.body())
                        
                        HStack(spacing: 12) {
                            ForEach(TaskSize.allCases, id: \.self) { taskSize in
                                Button {
                                    task.size = taskSize
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: taskSize.icon)
                                            .font(.system(size: 16))
                                            .foregroundColor(task.size == taskSize ? DSColors.onAccent : DSColors.textPrimary)
                                        Text(taskSize.rawValue)
                                            .font(DSFonts.caption())
                                            .foregroundColor(task.size == taskSize ? DSColors.onAccent : DSColors.textPrimary)
                                        Text(taskSize.timeDescription)
                                            .font(.system(size: 10))
                                            .foregroundColor(task.size == taskSize ? DSColors.onAccent.opacity(0.8) : DSColors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(task.size == taskSize ? DSColors.accentPrimary : DSColors.canvasSecondary)
                                    .cornerRadius(UIConstants.CornerRadius.standard)
                                }
                            }
                        }
                    }
                    
                    // Due date
                    HStack {
                        Text("Due Date")
                            .font(DSFonts.body())
                        Spacer()
                        if let dueDate = task.dueDate {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { dueDate },
                                    set: { newDate in
                                        task.dueDate = newDate
                                        // Reschedule notification for the new due date
                                        let taskId = task.id.uuidString
                                        _Concurrency.Task {
                                            await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
                                            if newDate > Date() {
                                                await NotificationManager.shared.scheduleTaskDueNotification(
                                                    taskId: taskId,
                                                    taskTitle: task.title,
                                                    dueDate: newDate
                                                )
                                            }
                                        }
                                    }
                                ),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()

                            Button {
                                // Cancel notification when clearing due date
                                let taskId = task.id.uuidString
                                _Concurrency.Task {
                                    await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
                                }
                                task.dueDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        } else {
                            Button("Set due date") {
                                let newDate = Date()
                                task.dueDate = newDate
                                // Schedule notification for the new due date
                                let taskId = task.id.uuidString
                                _Concurrency.Task {
                                    await NotificationManager.shared.scheduleTaskDueNotification(
                                        taskId: taskId,
                                        taskTitle: task.title,
                                        dueDate: newDate
                                    )
                                }
                            }
                            .foregroundColor(DSColors.accentPrimary)
                        }
                    }
                }
                
                // Scheduled Time
                if let timeBlocks = task.timeBlocks, let firstBlock = timeBlocks.first {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scheduled Time")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(DSColors.accentPrimary)
                            
                            Text("\(firstBlock.startTime.formatted(date: .omitted, time: .shortened)) - \(firstBlock.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            
                            Spacer()
                            
                            Text(firstBlock.durationText)
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DSColors.canvasSecondary)
                                .cornerRadius(UIConstants.CornerRadius.standard)
                        }
                        .padding(12)
                        .background(DSColors.accentPrimary.opacity(0.1))
                        .cornerRadius(UIConstants.CornerRadius.large)
                    }
                }
                
                // Recurrence info (if task is from a routine)
                if task.isRecurring, let routine = task.routine {
                    Card(padding: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "repeat.circle.fill")
                                    .foregroundColor(DSColors.accentPrimary)
                                Text("Recurring Task")
                                    .font(DSFonts.label())
                                    .foregroundColor(DSColors.textPrimary)
                                Spacer()
                            }
                            
                            Text("Auto-generated from '\(routine.title)' routine")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                            
                            HStack {
                                Label(routine.frequency.rawValue, systemImage: routine.frequency.icon)
                                    .font(DSFonts.caption())
                                Spacer()
                                if routine.currentStreak > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                        Text("\(routine.currentStreak) streak")
                                    }
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.warning)
                                }
                            }
                        }
                    }
                }
                
                // Life Domain assignment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Life Domain")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Picker("Assign to life domain", selection: $task.plan) {
                        Text("None").tag(nil as Plan?)
                        ForEach(LifeDomain.allCases, id: \.self) { domain in
                            Text(domain.rawValue).tag(plansByDomain[domain] as Plan?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Goal assignment
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aspirational Goal")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Picker("Link to goal", selection: $task.journey) {
                        Text("None").tag(nil as Journey?)
                        ForEach(journeys) { journey in
                            HStack {
                                Image(systemName: journey.icon)
                                Text(journey.title)
                            }
                            .tag(journey as Journey?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Milestone assignment (only if journey is selected)
                if let journey = task.journey, let milestones = journey.milestones, !milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Milestone")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        
                        Picker("Assign to milestone", selection: $task.milestone) {
                            Text("None").tag(nil as Milestone?)
                            ForEach(milestones.sorted(by: { $0.order < $1.order })) { milestone in
                                Text(milestone.title).tag(milestone as Milestone?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                        
                    AttachmentsView(itemId: task.id, itemType: .task)
                }
            }
            .padding()
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
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
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    .accessibilityIdentifier("saveTaskButton")
                }
            }
        }
        .alert("Delete Task", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                try? AttachmentService.shared.deleteAllAttachments(for: task.id, context: modelContext)
                modelContext.delete(task)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }
    
}
