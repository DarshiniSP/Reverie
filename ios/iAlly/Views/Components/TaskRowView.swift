//
//  TaskRowView.swift
//  iAlly
//
//  Extracted from InboxView for reusability
//  Used across all list views (Inbox, Today, Upcoming, Plans, Journeys, Routines, etc.)
//

import SwiftUI
import SwiftData

struct TaskRowView: View {
    let task: TaskWork
    var showOverdueIndicator: Bool = false
    @Environment(\.modelContext) private var modelContext
    @State private var showReflectionPrompt = false
    @State private var showOverdueRecoveryPrompt = false
    @State private var reflectionText = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left border (category color)
            Rectangle()
                .fill(Color(hex: task.displayColorHex))
                .opacity(task.displayOpacity)
                .frame(width: 4)
            
            // Main Card Content
            Card {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        toggleComplete()
                    } label: {
                        ZStack {
                            // Icon background (category color, subtle)
                            Circle()
                                .fill(Color(hex: task.displayColorHex))
                                .opacity(task.displayOpacity * 0.2)
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(DSFonts.headline())
                                .foregroundColor(task.isCompleted ? DSColors.success : Color(hex: task.displayColorHex).opacity(task.displayOpacity))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("completeTaskButton")
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(task.title)
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                                .strikethrough(task.isCompleted)
                            
                            if task.wasOverdueWhenCompleted {
                                Label("Recovered", systemImage: "arrow.uturn.forward.circle.fill")
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.success)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(DSColors.success.opacity(0.1))
                                    .cornerRadius(4)
                            } else if showOverdueIndicator || task.isOverdue {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(DSColors.error)
                                    .font(DSFonts.caption())
                            }
                        }
                        
                        if let detail = task.detail, !detail.isEmpty {
                            Text(detail)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 8) {
                            if let energy = task.energy {
                                Label(energy.rawValue, systemImage: energy.icon)
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            
                            Label(task.size.rawValue, systemImage: task.size.icon)
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                            
                            if let due = task.dueDate {
                                Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                    .font(DSFonts.caption())
                                    .foregroundColor(task.isOverdue ? DSColors.error : DSColors.textSecondary)
                            }
                            
                            // Subtask progress indicator
                            if task.hasSubtasks {
                                SubtaskProgressView(
                                    completed: task.completedSubtaskCount,
                                    total: task.totalSubtaskCount
                                )
                            }

                            // Checklist progress indicator
                            if task.hasChecklist {
                                HStack(spacing: 4) {
                                    Image(systemName: "checklist")
                                        .font(.system(size: 10))
                                        .foregroundColor(DSColors.accentPrimary)
                                    ChecklistProgressView(
                                        completed: task.completedChecklistCount,
                                        total: task.totalChecklistCount
                                    )
                                }
                            }
                        }
                        
                        // Tags
                        if let tags = task.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags) { tag in
                                        HStack(spacing: 3) {
                                            Image(systemName: tag.icon)
                                                .font(.system(size: TagConstants.badgeIconSize))
                                            Text(tag.name)
                                                .font(.system(size: TagConstants.badgeTextSize, weight: .medium))
                                        }
                                        .padding(.horizontal, TagConstants.badgePaddingHorizontal)
                                        .padding(.vertical, TagConstants.badgePaddingVertical)
                                        .background(Color(hex: tag.colorHex).opacity(TagConstants.badgeOpacity))
                                        .foregroundColor(Color(hex: tag.colorHex))
                                        .cornerRadius(TagConstants.badgeCornerRadius)
                                    }
                                }
                            }
                        }
                        
                        // Show time until due/overdue
                        if let due = task.dueDate {
                            Text(relativeDateString(for: due))
                                .font(DSFonts.caption())
                                .foregroundColor(task.isOverdue ? DSColors.error : DSColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
            } // End Card
        } // End HStack
        .accessibilityIdentifier("taskCell_\(task.title)")
        // Background tint (category color, very subtle)
        .background(
            Color(hex: task.displayColorHex)
                .opacity(task.displayOpacity * 0.1)
        )
        .sheet(isPresented: $showReflectionPrompt) {
            ReflectionInputSheet(
                taskTitle: task.title,
                reflectionText: $reflectionText,
                onSave: {
                    completeTask()
                },
                onSkip: {
                    completeTask()
                },
                task: task
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showOverdueRecoveryPrompt) {
            OverdueRecoveryPrompt(task: task)
        }
    }
    
    private func toggleComplete() {
        withAnimation {
            if task.isCompleted {
                // Uncomplete
                task.completedAt = nil
                task.completionReflection = nil
                // Light haptic for uncomplete
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } else {
                // Check if task is overdue - show recovery prompt
                if task.isOverdue {
                    showOverdueRecoveryPrompt = true
                } else {
                    // Show reflection prompt before completing
                    reflectionText = ""
                    showReflectionPrompt = true
                }
            }
            try? modelContext.save()
        }
    }
    
    private func completeTask() {
        withAnimation {
            task.completedAt = Date()
            if !reflectionText.isEmpty {
                task.completionReflection = reflectionText
            }

            // Success haptic for task completion
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Track energy pattern learning if task belongs to a plan
            if let plan = task.plan {
                let service = GrowthMindsetService(modelContext: modelContext)
                service.updatePlanLearningData(plan, task: task)
            }

            // Cancel any pending due-date / overdue notifications for this task.
            NotificationManager.shared.cancelTaskNotifications(taskId: task.id.uuidString)

            // Record completion to PAI episodic memory.
            PAIMemoryBridge.shared.recordTaskCompleted(task)

            // Update routine streak and record check-in to PAI if this task was
            // generated by a routine. updateStreakForRoutine handles both the
            // streak counters and the PAIMemoryBridge.recordRoutineCheckin() call.
            if let routine = task.routine {
                RoutineManager.shared.updateStreakForRoutine(
                    routine,
                    completionDate: Date(),
                    context: modelContext
                )
            }

            // Refresh widgets so task counts update immediately.
            WidgetHelper.shared.reloadAllWidgets()

            try? modelContext.save()
        }
    }
    
    private func relativeDateString(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if task.isOverdue {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days == 0 {
                return "Overdue today"
            } else if days == 1 {
                return "Overdue by 1 day"
            } else {
                return "Overdue by \(days) days"
            }
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            if days == 0 {
                return "Due today"
            } else if days == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(days) days"
            }
        }
    }
}

// MARK: - Reflection Input Sheet
// Shown when a task is completed — lets the user optionally record a quick note.

struct ReflectionInputSheet: View {
    let taskTitle: String
    @Binding var reflectionText: String
    var onSave: () -> Void
    var onSkip: () -> Void
    let task: TaskWork

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DSColors.success.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DSColors.success)
                    }
                    Text("Task complete!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(DSColors.textPrimary)
                    Text(taskTitle)
                        .font(DSFonts.body(15))
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 8)

                // Optional reflection field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Any quick thoughts? (optional)")
                        .font(DSFonts.label(14))
                        .foregroundColor(DSColors.textSecondary)
                    TextField("What did you learn or notice?", text: $reflectionText, axis: .vertical)
                        .font(DSFonts.body(15))
                        .lineLimit(3...5)
                        .padding(12)
                        .background(DSColors.canvasSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColors.divider, lineWidth: 1))
                        .focused($focused)
                }

                Spacer()

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        dismiss()
                        onSave()
                    } label: {
                        Text(reflectionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Done" : "Save & Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        reflectionText = ""
                        dismiss()
                        onSkip()
                    } label: {
                        Text("Skip")
                            .font(DSFonts.body(15))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }
            .padding(24)
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear { focused = true }
    }
}
