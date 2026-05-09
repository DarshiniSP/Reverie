//
//  OverdueRecoveryPrompt.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct OverdueRecoveryPrompt: View {
    @Bindable var task: TaskWork
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDatePicker = false
    @State private var newDueDate = Date()
    @State private var showReflectionPrompt = false
    @State private var reflectionText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon and Title
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(DSColors.warning)
                    
                    Text("It happens.")
                        .font(DSFonts.title())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("What would you like to do with\n\"\(task.title)\"?")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Complete Today
                    Button {
                        // Show reflection prompt before completing
                        reflectionText = ""
                        showReflectionPrompt = true
                    } label: {
                        Label("Complete It Now", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Reschedule
                    Button {
                        showDatePicker = true
                    } label: {
                        Label("Reschedule", systemImage: "calendar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Keep as-is (dismiss)
                    Button {
                        dismiss()
                    } label: {
                        Text("Keep As-Is")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(TertiaryButtonStyle())
                }
                .padding(.bottom, 20)
            }
            .padding()
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("Overdue Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("When can you do this?")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.textPrimary)
                            .padding(.top)
                        
                        DatePicker(
                            "Due Date",
                            selection: $newDueDate,
                            in: Date()...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .padding()
                        
                        Spacer()
                        
                        Button {
                            rescheduleTaskWork()
                        } label: {
                            Text("Reschedule")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding()
                    }
                    .background(DSColors.canvasPrimary.ignoresSafeArea())
                    .navigationTitle("Choose New Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showReflectionPrompt) {
                ReflectionInputSheet(
                    taskTitle: task.title,
                    reflectionText: $reflectionText,
                    onSave: {
                        completeTaskWithReflection()
                    },
                    onSkip: {
                        completeTaskWithReflection()
                    },
                    task: task
                )
                .presentationDetents([.large])
            }
        }
        .presentationDetents([.large])
    }
    
    private func completeTaskWithReflection() {
        task.completedAt = Date()
        task.wasOverdueWhenCompleted = true
        task.recoveryCount += 1

        // Save reflection if provided
        if !reflectionText.isEmpty {
            task.completionReflection = reflectionText
        }

        // Record mindset event
        let event = MindsetEvent(
            eventType: .recovered,
            contextNotes: "Completed overdue task",
            emotionalState: .accomplished,
            task: task
        )
        modelContext.insert(event)

        // Cancel pending notifications
        let taskId = task.id.uuidString
        _Concurrency.Task {
            await NotificationManager.shared.cancelTaskNotifications(taskId: taskId)
        }

        // Record to PAI memory
        PAIMemoryBridge.shared.recordTaskCompleted(task)

        // Update routine streak if this is a routine task
        if let routine = task.routine {
            RoutineManager.shared.updateStreakForRoutine(routine, completionDate: Date(), context: modelContext)
        }

        // Refresh widgets
        WidgetHelper.shared.reloadAllWidgets()

        try? modelContext.save()
        dismiss()
    }
    
    private func rescheduleTaskWork() {
        let oldDate = task.dueDate
        task.dueDate = newDueDate
        task.rescheduleCount += 1
        
        // Record mindset event
        let contextNote: String
        if let old = oldDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            contextNote = "Rescheduled from \(formatter.string(from: old)) to \(formatter.string(from: newDueDate))"
        } else {
            contextNote = "Rescheduled to new date"
        }
        
        let event = MindsetEvent(
            eventType: .rescheduled,
            contextNotes: contextNote,
            emotionalState: nil,
            task: task
        )
        modelContext.insert(event)
        
        try? modelContext.save()
        showDatePicker = false
        dismiss()
    }
}

struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFonts.label(16))
            .fontWeight(.medium)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundColor(DSColors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                    .fill(DSColors.canvasSecondary)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskWork.self, configurations: config)
    
    let task = TaskWork(
        title: "Write documentation",
        dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())
    )
    container.mainContext.insert(task)
    
    return OverdueRecoveryPrompt(task: task)
        .modelContainer(container)
}
