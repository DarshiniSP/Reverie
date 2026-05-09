//
//  TaskPickerView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct TaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TaskWork> { task in
        task.completedAt == nil
    }, sort: [SortDescriptor(\TaskWork.createdAt, order: .reverse)])
    private var incompleteTasks: [TaskWork]
    
    @Binding var selectedTask: TaskWork?
    var filterToday: Bool = false
    var todayTasks: [TaskWork] = []
    var excludeSubtasks: Bool = false
    var allTasks: [TaskWork]? = nil
    
    private var displayedTasks: [TaskWork] {
        let baseTasks = allTasks ?? (filterToday ? todayTasks : incompleteTasks)
        
        // Filter out subtasks if requested (for parent task selection)
        if excludeSubtasks {
            return baseTasks.filter { !$0.isSubtask }
        }
        
        return baseTasks
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filterToday && !todayTasks.isEmpty {
                    Section {
                        Text("Showing only today's tasks for better focus")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                ForEach(displayedTasks) { task in
                    Button {
                        selectedTask = task
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(DSFonts.body())
                                    .foregroundColor(DSColors.textPrimary)
                                
                                HStack(spacing: 8) {
                                    if let energy = task.energy {
                                        Label(energy.rawValue, systemImage: energy.icon)
                                            .font(DSFonts.caption())
                                            .foregroundColor(DSColors.textSecondary)
                                    }
                                    
                                    Label(task.size.rawValue, systemImage: task.size.icon)
                                        .font(DSFonts.caption())
                                        .foregroundColor(DSColors.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedTask?.id == task.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
