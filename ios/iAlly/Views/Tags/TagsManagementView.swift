//
//  TagsManagementView.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import SwiftUI
import SwiftData

struct TagsManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    
    @State private var showAddTag = false
    @State private var searchText = ""
    
    var filteredTags: [Tag] {
        if searchText.isEmpty {
            return tags
        }
        return tags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List {
            if !filteredTags.isEmpty {
                ForEach(filteredTags) { tag in
                    NavigationLink {
                        TagDetailView(tag: tag)
                    } label: {
                        TagRowView(tag: tag)
                    }
                }
                .onDelete(perform: deleteTags)
            } else {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag.slash",
                    description: Text(searchText.isEmpty ? "Create your first tag to organize tasks" : "No tags match your search")
                )
            }
        }
        .navigationTitle("Tags")
        .searchable(text: $searchText, prompt: "Search tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddTag = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTag) {
            AddTagView()
        }
    }
    
    private func deleteTags(at offsets: IndexSet) {
        for index in offsets {
            let tag = filteredTags[index]
            TagManager.shared.deleteTag(tag, from: modelContext)
        }
    }
}

struct TagRowView: View {
    let tag: Tag
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tag.icon)
                .font(DSFonts.headline())
                .foregroundColor(Color(hex: tag.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(hex: tag.colorHex).opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Text("\(tag.activeTaskCount) active, \(tag.taskCount) total")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct AddTagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var name = ""
    @State private var selectedColor = Tag.predefinedColors.first ?? "#4C8BF5"
    @State private var selectedIcon = "tag.fill"
    
    let availableIcons = [
        "tag.fill", "star.fill", "heart.fill", "flag.fill",
        "bookmark.fill", "pin.fill", "paperclip", "link",
        "lightbulb.fill", "sparkles", "bolt.fill", "flame.fill"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Tag.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(DSFonts.headline())
                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : DSColors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.1) : Color.clear)
                                .cornerRadius(UIConstants.CornerRadius.standard)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: selectedIcon)
                            .foregroundColor(Color(hex: selectedColor))
                        Text(name.isEmpty ? "Tag Preview" : name)
                            .foregroundColor(DSColors.textPrimary)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTag()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createTag() {
        _ = TagManager.shared.createTag(
            name: name,
            colorHex: selectedColor,
            icon: selectedIcon,
            in: modelContext
        )
        dismiss()
    }
}

struct TagDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let tag: Tag
    
    @State private var isEditing = false
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: tag.icon)
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: tag.colorHex))
                    
                    Text(tag.name)
                        .font(DSFonts.title(24))
                        .foregroundColor(DSColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color(hex: tag.colorHex).opacity(0.1))
            
            Section("Statistics") {
                StatRow(label: "Total Tasks", value: "\(tag.taskCount)")
                StatRow(label: "Active Tasks", value: "\(tag.activeTaskCount)")
                StatRow(label: "Completed", value: "\(tag.taskCount - tag.activeTaskCount)")
            }
            
            if let tasks = tag.tasks, !tasks.isEmpty {
                Section("Tagged Tasks") {
                    ForEach(tasks.prefix(5)) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            TaskRowView(task: task)
                        }
                    }
                    
                    if tasks.count > 5 {
                        NavigationLink {
                            TaggedTasksListView(tag: tag)
                        } label: {
                            HStack {
                                Text("View All Tasks")
                                Spacer()
                                Text("\(tasks.count)")
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(tag.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditTagView(tag: tag)
        }
    }
}

struct EditTagView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let tag: Tag
    
    @State private var name: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    
    init(tag: Tag) {
        self.tag = tag
        _name = State(initialValue: tag.name)
        _selectedColor = State(initialValue: tag.colorHex)
        _selectedIcon = State(initialValue: tag.icon)
    }
    
    let availableIcons = [
        "tag.fill", "star.fill", "heart.fill", "flag.fill",
        "bookmark.fill", "pin.fill", "paperclip", "link",
        "lightbulb.fill", "sparkles", "bolt.fill", "flame.fill"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Tag.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(DSFonts.headline())
                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : DSColors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.1) : Color.clear)
                                .cornerRadius(UIConstants.CornerRadius.standard)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        TagManager.shared.updateTag(
            tag,
            name: name,
            colorHex: selectedColor,
            icon: selectedIcon,
            in: modelContext
        )
        dismiss()
    }
}

struct TaggedTasksListView: View {
    let tag: Tag
    
    var tasks: [TaskWork] {
        tag.tasks ?? []
    }
    
    var body: some View {
        List {
            ForEach(tasks) { task in
                NavigationLink {
                    TaskDetailView(task: task)
                } label: {
                    TaskRowView(task: task)
                }
            }
        }
        .navigationTitle("\(tag.name) Tasks")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
            Spacer()
            Text(value)
                .font(DSFonts.body().weight(.semibold))
                .foregroundColor(DSColors.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        TagsManagementView()
            .modelContainer(for: [Tag.self], inMemory: true)
    }
}
