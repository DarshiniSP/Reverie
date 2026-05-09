//
//  CustomViewTasksView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

struct CustomViewTasksView: View {
    @Environment(\.modelContext) private var modelContext
    
    let customView: CustomView
    
    @Query(sort: [SortDescriptor(\TaskWork.createdAt, order: .reverse)]) private var allTasks: [TaskWork]
    @State private var showEditSheet = false
    
    private var filteredTasks: [TaskWork] {
        CustomViewService.shared.applyView(customView, to: allTasks)
    }
    
    private var groupedTasks: [String: [TaskWork]] {
        CustomViewService.shared.groupTasks(filteredTasks, by: customView.groupBy)
    }
    
    var body: some View {
        ZStack {
            if filteredTasks.isEmpty {
                EmptyViewState(viewName: customView.name)
            } else if customView.layoutType == .list {
                ListLayoutView(
                    groupedTasks: groupedTasks,
                    showGrouping: customView.groupBy != nil && customView.groupBy != TaskGroupOption.none
                )
            } else if customView.layoutType == .grid {
                GridLayoutView(tasks: filteredTasks)
            } else {
                KanbanLayoutView(
                    groupedTasks: groupedTasks,
                    groupBy: customView.groupBy ?? TaskGroupOption.completed
                )
            }
        }
        .navigationTitle(customView.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditCustomViewView(view: customView)
        }
    }
}

// MARK: - Empty State

struct EmptyViewState: View {
    let viewName: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No tasks match this view")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            Text("Try adjusting the filters or create new tasks")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - List Layout

struct ListLayoutView: View {
    let groupedTasks: [String: [TaskWork]]
    let showGrouping: Bool
    
    private var sortedGroups: [String] {
        groupedTasks.keys.sorted()
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if showGrouping {
                    ForEach(sortedGroups, id: \.self) { group in
                        GroupSection(title: group, tasks: groupedTasks[group] ?? [])
                    }
                } else {
                    ForEach(groupedTasks["All"] ?? [], id: \.id) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct GroupSection: View {
    let title: String
    let tasks: [TaskWork]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textSecondary)
                
                Text("(\(tasks.count))")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding(.horizontal)
            
            ForEach(tasks, id: \.id) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Grid Layout

struct GridLayoutView: View {
    let tasks: [TaskWork]
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(tasks, id: \.id) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        TaskCardView(task: task)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct TaskCardView: View {
    let task: TaskWork
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .secondary)
                
                Spacer()
                
                if let energy = task.energy {
                    Text(energy.rawValue)
                        .font(DSFonts.caption())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DSColors.accentPrimary.opacity(0.1))
                        .foregroundColor(DSColors.accentPrimary)
                        .cornerRadius(4)
                }
            }
            
            Text(task.title)
                .font(DSFonts.body())
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            
            Spacer()
            
            HStack {
                Text(task.size.rawValue)
                    .font(DSFonts.caption())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
                
                Spacer()
                
                if let dueDate = task.dueDate {
                    Text(dueDate, style: .relative)
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding()
        .frame(height: 150)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

// MARK: - Kanban Layout

struct KanbanLayoutView: View {
    let groupedTasks: [String: [TaskWork]]
    let groupBy: TaskGroupOption
    
    private var sortedGroups: [String] {
        groupedTasks.keys.sorted()
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(sortedGroups, id: \.self) { group in
                    KanbanColumn(title: group, tasks: groupedTasks[group] ?? [])
                }
            }
            .padding()
        }
    }
}

struct KanbanColumn: View {
    let title: String
    let tasks: [TaskWork]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(DSFonts.headline())
                
                Text("\(tasks.count)")
                    .font(DSFonts.caption())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DSColors.accentPrimary.opacity(0.1))
                    .foregroundColor(DSColors.accentPrimary)
                    .cornerRadius(UIConstants.CornerRadius.standard)
            }
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks, id: \.id) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            KanbanTaskCard(task: task)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 280)
        .padding()
        .background(DSColors.canvasSecondary.opacity(0.5))
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct KanbanTaskCard: View {
    let task: TaskWork
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(DSFonts.body())
                .multilineTextAlignment(.leading)
            
            if let detail = task.detail, !detail.isEmpty {
                Text(detail)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(task.size.rawValue)
                    .font(DSFonts.caption())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
                
                Spacer()
                
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(DSFonts.caption())
                        Text(dueDate, style: .date)
                            .font(DSFonts.caption())
                    }
                    .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
}

#Preview {
    NavigationStack {
        CustomViewTasksView(
            customView: CustomView(
                name: "Quick Wins",
                icon: "bolt.fill",
                colorHex: "#34C759",
                filterBySize: [.small],
                sortBy: .dueDate
            )
        )
        .modelContainer(for: [TaskWork.self, CustomView.self], inMemory: true)
    }
}
