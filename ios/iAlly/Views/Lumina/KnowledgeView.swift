//
//  KnowledgeView.swift
//  iAlly
//
//  Phase 2: Capture & Knowledge Layer
//  A dedicated space for learnings, decisions, observations — the non-task
//  content of a second brain.  Grouped by KnowledgeItemType with search.
//

import SwiftUI
import SwiftData

struct KnowledgeView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Knowledge.createdAt, order: .reverse) private var allItems: [Knowledge]

    @State private var searchQuery = ""
    @State private var selectedType: KnowledgeItemType? = nil
    @State private var showAddSheet = false
    @State private var editingItem: Knowledge?
    @State private var sortOption: KnowledgeSortOption = .newest

    var filteredItems: [Knowledge] {
        allItems.filter { item in
            let matchesType = selectedType == nil || item.itemType == selectedType
            let matchesSearch = searchQuery.isEmpty
                || item.title.localizedCaseInsensitiveContains(searchQuery)
                || item.content.localizedCaseInsensitiveContains(searchQuery)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                typePicker
                itemList
            }
            .navigationTitle("Knowledge")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchQuery, prompt: "Search knowledge…")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addKnowledgeButton")
                }
                ToolbarItem(placement: .secondaryAction) {
                    Menu {
                        ForEach(KnowledgeSortOption.allCases, id: \.self) { opt in
                            Button(opt.rawValue) { sortOption = opt }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddKnowledgeView()
            }
            .sheet(item: $editingItem) { item in
                EditKnowledgeView(item: item)
            }
        }
    }

    // MARK: - Type filter chips

    private var typePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                KnowledgeFilterChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }
                ForEach(KnowledgeItemType.allCases) { type in
                    KnowledgeFilterChip(
                        label: type.rawValue,
                        icon: type.icon,
                        isSelected: selectedType == type,
                        colorHex: type.colorHex
                    ) {
                        selectedType = selectedType == type ? nil : type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(DSColors.canvasPrimary)
    }

    // MARK: - Item list

    @ViewBuilder
    private var itemList: some View {
        if filteredItems.isEmpty {
            ContentUnavailableView(
                searchQuery.isEmpty ? "No Knowledge Yet" : "No Matches",
                systemImage: "lightbulb",
                description: Text(
                    searchQuery.isEmpty
                        ? "Tap + to capture a learning, decision, insight or observation."
                        : "Try different search terms."
                )
            )
        } else {
            List {
                ForEach(filteredItems) { item in
                    KnowledgeRowView(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { editingItem = item }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                let repo = KnowledgeRepository(context: modelContext)
                                try? repo.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Row

struct KnowledgeRowView: View {
    let item: Knowledge

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Type icon
            Image(systemName: item.itemType.icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: item.itemType.colorHex))
                .frame(width: 36, height: 36)
                .background(Color(hex: item.itemType.colorHex).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(1)

                Text(item.content)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.createdAt, style: .date)
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    if !item.tags.isEmpty {
                        Text(item.tags.prefix(2).joined(separator: " · "))
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    // Knowledge items are stored locally via LocalMemoryService
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("knowledgeCell_\(item.title)")
    }
}

// MARK: - Filter chip component

struct KnowledgeFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    var colorHex: String = DSColors.accentPrimaryHex
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(DSFonts.body(13))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(hex: colorHex) : DSColors.canvasSecondary)
                .foregroundColor(isSelected ? DSColors.onAccent : DSColors.textPrimary)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Add Knowledge sheet

struct AddKnowledgeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var content = ""
    @State private var type: KnowledgeItemType = .learning
    @State private var tagsInput = ""
    @State private var source = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you capture?") {
                    TextField("Title", text: $title)
                        .focused($titleFocused)
                    TextField("Content / Details", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section("Type") {
                    Picker("Type", selection: $type) {
                        ForEach(KnowledgeItemType.allCases) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Optional") {
                    TextField("Tags (comma separated)", text: $tagsInput)
                    TextField("Source (book, URL, person…)", text: $source)
                }
            }
            .navigationTitle("Add Knowledge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func save() {
        let tags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let repo = KnowledgeRepository(context: modelContext)
        _ = try? repo.create(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            tags: tags,
            source: source.isEmpty ? nil : source
        )
        dismiss()
    }
}

// MARK: - Edit Knowledge sheet

struct EditKnowledgeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let item: Knowledge
    @State private var title: String
    @State private var content: String
    @State private var tagsInput: String

    init(item: Knowledge) {
        self.item = item
        _title = State(initialValue: item.title)
        _content = State(initialValue: item.content)
        _tagsInput = State(initialValue: item.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Content", text: $content, axis: .vertical)
                        .lineLimit(4...10)
                }
                Section("Tags") {
                    TextField("Comma separated", text: $tagsInput)
                }
                Section {
                    Text("Type: \(item.itemType.rawValue)")
                        .foregroundColor(DSColors.textSecondary)
                    if let source = item.source, !source.isEmpty {
                        Text("Source: \(source)")
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let tags = tagsInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let repo = KnowledgeRepository(context: modelContext)
        try? repo.update(item, title: title, content: content, tags: tags)
        dismiss()
    }
}

#Preview {
    KnowledgeView()
        .modelContainer(for: Knowledge.self, inMemory: true)
}
