//
//  ScheduleTaskView.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import SwiftUI
import SwiftData

struct ScheduleTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let task: TaskWork
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Task Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedule Task")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text(task.title)
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.large)
                }
                .padding(.horizontal)
                
                // Date Picker
                DatePicker(
                    "Due Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .background(DSColors.canvasPrimary)
            .navigationTitle("Set Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .bold()
                }
            }
        }
    }
    
    private func saveSchedule() {
        task.dueDate = selectedDate
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Silently fail - error handling can be improved with user feedback
        }
    }
}
