//
//  TagSelectionView.swift
//  iAlly
//
//  Created by Irigam Developer on 11/12/25.
//

import SwiftUI
import SwiftData

struct TagSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    
    @Binding var selectedTags: [Tag]
    @State private var searchText = ""
    @State private var showCreateTag = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                SearchBar(text: $searchText, placeholder: "Search tags...")
                    .padding()
                
                // Tags list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTags) { tag in
                            TagRow(
                                tag: tag,
                                isSelected: selectedTags.contains { $0.id == tag.id }
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                    .padding()
                }
                
                // Create new tag button
                Button {
                    showCreateTag = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create New Tag")
                    }
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.accentPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DSColors.canvasSecondary)
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreateTag) {
                CreateTagView { newTag in
                    selectedTags.append(newTag)
                }
            }
        }
    }
    
    private var filteredTags: [Tag] {
        if searchText.isEmpty {
            return allTags
        }
        return allTags.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func toggleTag(_ tag: Tag) {
        if let index = selectedTags.firstIndex(where: { $0.id == tag.id }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
}

// MARK: - Tag Row
struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Tag icon and color
                Image(systemName: tag.icon)
                    .font(DSFonts.headline())
                    .foregroundColor(Color(hex: tag.colorHex))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: tag.colorHex).opacity(0.2))
                    .cornerRadius(UIConstants.CornerRadius.standard)
                
                // Tag name
                Text(tag.name)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Spacer()
                
                // Task count
                if tag.taskCount > 0 {
                    Text("\(tag.taskCount)")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.large)
                }
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DSFonts.headline())
                    .foregroundColor(isSelected ? DSColors.accentPrimary : DSColors.textSecondary)
            }
            .padding()
            .background(DSColors.canvasPrimary)
            .cornerRadius(UIConstants.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.large)
                    .stroke(isSelected ? Color(hex: tag.colorHex) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Tag View
struct CreateTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor = Tag.predefinedColors[0]
    @State private var selectedIcon = Tag.predefinedIcons[0]
    
    let onCreate: (Tag) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Details") {
                    TextField("Tag name", text: $name)
                        .autocorrectionDisabled()
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(Tag.predefinedColors, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? DSColors.textPrimary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(Tag.predefinedIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(DSFonts.headline())
                                .foregroundColor(selectedIcon == icon ? Color(hex: selectedColor) : DSColors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : DSColors.canvasSecondary)
                                .cornerRadius(UIConstants.CornerRadius.standard)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                }
            }
            .navigationTitle("Create Tag")
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
        let tag = TagManager.shared.createTag(
            name: name.trimmingCharacters(in: .whitespaces),
            colorHex: selectedColor,
            icon: selectedIcon,
            in: modelContext
        )
        onCreate(tag)
        dismiss()
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DSColors.textSecondary)
            
            TextField(placeholder, text: $text)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
}

#Preview {
    TagSelectionView(selectedTags: .constant([]))
        .modelContainer(for: [Tag.self, TaskWork.self], inMemory: true)
}
