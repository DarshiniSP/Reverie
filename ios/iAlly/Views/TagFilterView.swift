//
//  TagFilterView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct TagFilterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @State private var searchText = ""
    @State private var selectedTag: Tag?
    
    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return allTags.filter { $0.taskCount > 0 }
        }
        return allTags.filter { tag in
            tag.taskCount > 0 && tag.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DSColors.textSecondary)
                    
                    TextField("Search tags", text: $searchText)
                        .font(DSFonts.body())
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                .padding(12)
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.medium)
                .padding()
                
                // Tags list
                if filteredTags.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tag")
                            .font(.system(size: 48))
                            .foregroundColor(DSColors.textSecondary)
                        
                        Text(searchText.isEmpty ? "No tags with tasks yet" : "No matching tags")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    Spacer()
                } else {
                    List(filteredTags) { tag in
                        Button {
                            selectedTag = tag
                        } label: {
                            HStack(spacing: 12) {
                                // Icon with colored background
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: tag.colorHex).opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: tag.icon)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: tag.colorHex))
                                }
                                
                                // Tag name and task count
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tag.name)
                                        .font(DSFonts.body(15))
                                        .foregroundColor(DSColors.textPrimary)
                                    
                                    HStack(spacing: 4) {
                                        Text("\(tag.activeTaskCount) active")
                                            .font(DSFonts.caption(12))
                                            .foregroundColor(DSColors.textSecondary)
                                        
                                        if tag.taskCount > tag.activeTaskCount {
                                            Text("•")
                                                .font(DSFonts.caption(12))
                                                .foregroundColor(DSColors.textSecondary)
                                            
                                            Text("\(tag.taskCount - tag.activeTaskCount) completed")
                                                .font(DSFonts.caption(12))
                                                .foregroundColor(DSColors.textSecondary)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("Filter by Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $selectedTag) { tag in
                FilteredTasksView(tag: tag)
            }
        }
    }
}

// MARK: - Filtered Tasks View
struct FilteredTasksView: View {
    let tag: Tag
    @Environment(\.modelContext) private var modelContext
    
    @Query private var allTasks: [TaskWork]
    
    private var filteredTasks: [TaskWork] {
        allTasks.filter { task in
            guard let tags = task.tags else { return false }
            return tags.contains(where: { $0.id == tag.id })
        }
    }
    
    private var activeTasks: [TaskWork] {
        filteredTasks.filter { !$0.isCompleted }
    }
    
    private var completedTasks: [TaskWork] {
        filteredTasks.filter { $0.isCompleted }
    }
    
    var body: some View {
        List {
            if !activeTasks.isEmpty {
                Section {
                    ForEach(activeTasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                    }
                } header: {
                    Text("Active (\(activeTasks.count))")
                }
            }
            
            if !completedTasks.isEmpty {
                Section {
                    ForEach(completedTasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                    }
                } header: {
                    Text("Completed (\(completedTasks.count))")
                }
            }
            
            if filteredTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text("No tasks with this tag")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Image(systemName: tag.icon)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: tag.colorHex))
                    
                    Text(tag.name)
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                }
            }
        }
    }
}

#Preview {
    TagFilterView()
        .modelContainer(for: [Tag.self, TaskWork.self], inMemory: true)
}
