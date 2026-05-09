//
//  InboxContentView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct InboxContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\TaskWork.createdAt, order: .reverse)])
    private var allTasks: [TaskWork]
    
    @Query(sort: \Plan.createdAt) private var allPlans: [Plan]
    @Query(sort: \Journey.startDate) private var allJourneys: [Journey]

    @State private var showDatePicker = false
    @State private var showPlanPicker = false
    @State private var showJourneyPicker = false
    @State private var selectedTask: TaskWork?
    @State private var selectedDate = Date()

    // Batch operations
    @State private var isSelectionMode = false
    @State private var selectedTasks: Set<UUID> = []
    @State private var showBatchActions = false

    // Inbox tasks: two sources for backward compatibility.
    //   New-style: task.isInbox == true (created via Inbox "+" button)
    //     → visible while no due date OR due date is still future.
    //     → on/after the due date it moves to Today only.
    //   Legacy: task.isInbox == false AND no plan, no journey, no due date
    //     → plain unorganized tasks that pre-date the isInbox flag.
    private var unorganizedTasks: [TaskWork] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allTasks.filter { task in
            guard task.completedAt == nil && !task.isSubtask else { return false }
            if task.isInbox {
                // New-style: show while due date is future or absent
                if let due = task.dueDate {
                    return Calendar.current.startOfDay(for: due) > todayStart
                }
                return true
            } else {
                // Legacy: no plan, no journey, no due date → unorganized
                return task.plan == nil && task.journey == nil && task.dueDate == nil
            }
        }
    }
    
    @State private var sortOrder: SortOrder = .dateCreated
    
    enum SortOrder: String, CaseIterable {
        case dateCreated = "Date Created"
        case dueDate = "Due Date"
        case size = "Size"
        
        var icon: String {
            switch self {
            case .dateCreated: return "clock"
            case .dueDate: return "calendar"
            case .size: return "square.stack"
            }
        }
    }
    
    private var sortedTasks: [TaskWork] {
        let tasks = unorganizedTasks
        switch sortOrder {
        case .dateCreated:
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case .dueDate:
            return tasks.sorted { task1, task2 in
                if let date1 = task1.dueDate, let date2 = task2.dueDate {
                    return date1 < date2
                } else if task1.dueDate != nil {
                    return true
                } else {
                    return false
                }
            }
        case .size:
            return tasks.sorted { task1, task2 in
                let order: [TaskSize] = [.large, .medium, .small]
                let index1 = order.firstIndex(of: task1.size) ?? 0
                let index2 = order.firstIndex(of: task2.size) ?? 0
                return index1 < index2
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if unorganizedTasks.isEmpty {
                emptyState
            } else {
                taskList
            }

            // Batch actions bar
            if isSelectionMode && !selectedTasks.isEmpty {
                batchActionsBar
            }
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isSelectionMode {
                    Button {
                        withAnimation {
                            isSelectionMode = false
                            selectedTasks.removeAll()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DSColors.textSecondary)
                    }
                } else {
                    Menu {
                        Section("Sort by") {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button {
                                    withAnimation { sortOrder = order }
                                } label: {
                                    Label(
                                        order.rawValue,
                                        systemImage: sortOrder == order ? "checkmark" : order.icon
                                    )
                                }
                            }
                        }
                        Divider()
                        Button {
                            withAnimation { isSelectionMode = true }
                        } label: {
                            Label("Select Tasks", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            if let task = selectedTask {
                ScheduleTaskView(task: task, selectedDate: $selectedDate)
            }
        }
        .sheet(isPresented: $showPlanPicker) {
            if let task = selectedTask {
                AssignToPlanView(task: task, plans: allPlans)
            }
        }
        .sheet(isPresented: $showJourneyPicker) {
            if let task = selectedTask {
                AssignToJourneyView(task: task, journeys: allJourneys)
            }
        }
        .sheet(isPresented: $showBatchActions) {
            BatchActionsSheet(
                selectedTasks: Array(sortedTasks.filter { selectedTasks.contains($0.id) }),
                modelContext: modelContext,
                onComplete: {
                    isSelectionMode = false
                    selectedTasks.removeAll()
                }
            )
        }
    }
    
    // MARK: - Sort Bar
    private var sortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        withAnimation {
                            sortOrder = order
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: order.icon)
                            Text(order.rawValue)
                        }
                        .font(DSFonts.caption())
                        .fontWeight(sortOrder == order ? .semibold : .regular)
                        .foregroundColor(sortOrder == order ? DSColors.onAccent : DSColors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(sortOrder == order ? DSColors.accentPrimary : DSColors.canvasPrimary)
                        .cornerRadius(UIConstants.CornerRadius.round)
                        .overlay(
                            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.round)
                                .stroke(DSColors.accentPrimary, lineWidth: sortOrder == order ? 0 : 1)
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(DSColors.canvasSecondary)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))
            
            Text("Inbox Zero")
                .font(DSFonts.title())
                .foregroundColor(DSColors.textPrimary)
            
            Text("All tasks are organized!")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Task List
    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    if isSelectionMode {
                        Button {
                            if selectedTasks.count == sortedTasks.count {
                                selectedTasks.removeAll()
                            } else {
                                selectedTasks = Set(sortedTasks.map { $0.id })
                            }
                        } label: {
                            Text(selectedTasks.count == sortedTasks.count ? "Deselect All" : "Select All")
                                .font(DSFonts.body(14))
                                .foregroundColor(DSColors.accentPrimary)
                        }
                    } else {
                        Text("\(unorganizedTasks.count) unprocessed tasks")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                ForEach(sortedTasks) { task in
                    if isSelectionMode {
                        Button {
                            if selectedTasks.contains(task.id) {
                                selectedTasks.remove(task.id)
                            } else {
                                selectedTasks.insert(task.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedTasks.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .font(DSFonts.headline())
                                    .foregroundColor(selectedTasks.contains(task.id) ? DSColors.accentPrimary : DSColors.textSecondary)
                                
                                TaskRowView(task: task)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                        .padding(.horizontal)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(task)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                selectedTask = task
                                showJourneyPicker = true
                            } label: {
                                Label("Goal", systemImage: "flag.fill")
                            }
                            .tint(DSColors.accentSecondary)

                            Button {
                                selectedTask = task
                                showPlanPicker = true
                            } label: {
                                Label("Plan", systemImage: "folder.fill")
                            }
                            .tint(DSColors.accentPrimary)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                selectedTask = task
                                selectedDate = task.dueDate ?? Date()
                                showDatePicker = true
                            } label: {
                                Label("Schedule", systemImage: "calendar")
                            }
                            .tint(DSColors.success)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Batch Actions Bar
    private var batchActionsBar: some View {
        HStack(spacing: 16) {
            Button {
                showBatchActions = true
            } label: {
                HStack {
                    Image(systemName: "ellipsis.circle.fill")
                    Text("Actions (\(selectedTasks.count))")
                        .font(DSFonts.body().weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DSColors.accentPrimary)
                .foregroundColor(DSColors.onAccent)
                .cornerRadius(UIConstants.CornerRadius.large)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
    }
}

#Preview {
    InboxContentView()
        .modelContainer(for: [TaskWork.self], inMemory: true)
}
