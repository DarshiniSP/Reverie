//
//  TaskAbandonmentPrompt.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct TaskAbandonmentPrompt: View {
    @Bindable var task: TaskWork
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private var daysOverdue: Int {
        guard let dueDate = task.dueDate else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
        return max(0, days)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon and Title
                VStack(spacing: 12) {
                    Image(systemName: "archivebox.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text("Still relevant?")
                        .font(DSFonts.title())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("**\(task.title)** has been overdue for \(daysOverdue) days.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Text("What would you like to do?")
                        .font(DSFonts.body(15))
                        .foregroundColor(DSColors.textSecondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Move to Someday
                    Button {
                        moveToSomeday()
                    } label: {
                        VStack(spacing: 4) {
                            Label("Move to Someday", systemImage: "tray.fill")
                            Text("Remove due date, keep in inbox")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Archive
                    Button {
                        archiveTask()
                    } label: {
                        VStack(spacing: 4) {
                            Label("Archive", systemImage: "archivebox")
                            Text("Remove from active lists")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    // Keep
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
            .navigationTitle("Long Overdue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func moveToSomeday() {
        // Remove due date to move to "someday" category
        task.dueDate = nil
        task.missCount += 1
        
        // Record mindset event
        let event = MindsetEvent(
            eventType: .missed,
            contextNotes: "Moved to someday after \(daysOverdue) days overdue",
            emotionalState: nil,
            task: task
        )
        modelContext.insert(event)
        
        try? modelContext.save()
        dismiss()
    }
    
    private func archiveTask() {
        // Mark as abandoned
        task.missCount += 1
        
        // Record mindset event
        let event = MindsetEvent(
            eventType: .abandoned,
            contextNotes: "Archived after \(daysOverdue) days overdue",
            emotionalState: nil,
            task: task
        )
        modelContext.insert(event)
        
        // Delete the task (archiving)
        modelContext.delete(task)
        
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TaskWork.self, configurations: config)
    
    let task = TaskWork(
        title: "Old task that's been neglected",
        dueDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())
    )
    container.mainContext.insert(task)
    
    return TaskAbandonmentPrompt(task: task)
        .modelContainer(container)
}
