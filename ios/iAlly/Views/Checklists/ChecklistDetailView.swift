//
//  ChecklistDetailView.swift
//  iAlly
//
//  Detail view for a single checklist with item management.
//  Reuses ChecklistItemRow and ChecklistTemplatePickerView.
//

import SwiftUI
import SwiftData

struct ChecklistDetailView: View {
    @Bindable var checklist: Checklist
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var newItemTitle = ""
    @State private var isAddingItem = false
    @State private var showTemplatePicker = false
    @State private var showSaveTemplateAlert = false
    @State private var templateName = ""
    @State private var showDeleteAlert = false
    @FocusState private var itemFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with icon and title
                HStack(spacing: 16) {
                    Image(systemName: checklist.icon)
                        .font(.system(size: 36))
                        .foregroundColor(checklist.color)
                        .frame(width: 56, height: 56)
                        .background(checklist.color.opacity(0.12))
                        .cornerRadius(UIConstants.CornerRadius.large)

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Checklist title", text: $checklist.title)
                            .font(DSFonts.title())
                            .foregroundColor(DSColors.textPrimary)
                            .textFieldStyle(.plain)

                        HStack(spacing: 12) {
                            if checklist.totalCount > 0 {
                                Text("\(checklist.completedCount)/\(checklist.totalCount) done")
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            if checklist.isRecurring {
                                HStack(spacing: 4) {
                                    Image(systemName: "repeat")
                                    Text("Recurring")
                                }
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                }

                // Progress bar
                if checklist.totalCount > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Progress")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Text("\(Int(checklist.progress * 100))%")
                                .font(DSFonts.label())
                                .fontWeight(.semibold)
                                .foregroundColor(
                                    checklist.isAllCompleted ? DSColors.success : checklist.color
                                )
                        }
                        ProgressView(value: checklist.progress)
                            .tint(checklist.isAllCompleted ? DSColors.success : checklist.color)
                    }
                }

                // Items list
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Items")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        Spacer()

                        if checklist.totalCount > 0 {
                            ChecklistProgressView(
                                completed: checklist.completedCount,
                                total: checklist.totalCount
                            )
                        }
                    }

                    // Existing items
                    if checklist.totalCount > 0 {
                        VStack(spacing: 6) {
                            ForEach(checklist.items.sorted(by: { $0.order < $1.order })) { item in
                                ChecklistItemRow(
                                    item: item,
                                    onToggle: { toggleItem(item) },
                                    onDelete: { deleteItem(item) }
                                )
                            }
                        }
                    }

                    // Inline add field
                    if isAddingItem {
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.textSecondary)

                            TextField("Item title", text: $newItemTitle)
                                .font(DSFonts.body())
                                .focused($itemFieldFocused)
                                .onSubmit {
                                    addItem()
                                }

                            Button {
                                isAddingItem = false
                                newItemTitle = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(DSColors.canvasSecondary.opacity(0.5))
                        .cornerRadius(UIConstants.CornerRadius.standard)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button {
                            isAddingItem = true
                            itemFieldFocused = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Item")
                            }
                            .font(DSFonts.body(14))
                            .foregroundColor(DSColors.accentPrimary)
                        }
                        .buttonStyle(.plain)

                        if checklist.totalCount == 0 {
                            Button {
                                showTemplatePicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Use Template")
                                }
                                .font(DSFonts.body(14))
                                .foregroundColor(DSColors.accentSecondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if checklist.items.count >= 2 {
                            Button {
                                showSaveTemplateAlert = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Save Template")
                                }
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Reset All button (for recurring or completed checklists)
                if checklist.totalCount > 0 && checklist.completedCount > 0 {
                    Button {
                        checklist.resetAll()
                        try? modelContext.save()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Items")
                        }
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.warning)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(DSColors.warning.opacity(0.1))
                        .cornerRadius(UIConstants.CornerRadius.standard)
                    }
                }
            }
            .padding()
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DSColors.error)
                    }

                    Button {
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
            }
        }
        .alert("Delete Checklist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(checklist)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this checklist?")
        }
        .sheet(isPresented: $showTemplatePicker) {
            ChecklistTemplatePickerView { templateItems in
                applyTemplate(templateItems)
            }
            .presentationDetents([.medium])
        }
        .alert("Save as Template", isPresented: $showSaveTemplateAlert) {
            TextField("Template name", text: $templateName)
            Button("Cancel", role: .cancel) { templateName = "" }
            Button("Save") { saveAsTemplate() }
        } message: {
            Text("Give this checklist a name so you can reuse it")
        }
    }

    // MARK: - Item Actions

    private func addItem() {
        guard !newItemTitle.isEmpty else { return }
        let newItem = ChecklistItem(
            title: newItemTitle,
            order: checklist.items.count
        )
        checklist.items.append(newItem)
        newItemTitle = ""
        try? modelContext.save()
    }

    private func toggleItem(_ item: ChecklistItem) {
        guard let index = checklist.items.firstIndex(where: { $0.id == item.id }) else { return }
        checklist.items[index].isCompleted.toggle()
        checklist.items[index].completedAt = checklist.items[index].isCompleted ? Date() : nil
        checklist.lastUsedDate = Date()
        try? modelContext.save()
    }

    private func deleteItem(_ item: ChecklistItem) {
        checklist.items.removeAll { $0.id == item.id }
        for i in checklist.items.indices {
            checklist.items[i].order = i
        }
        try? modelContext.save()
    }

    private func applyTemplate(_ templateItems: [String]) {
        let startOrder = checklist.items.count
        for (i, title) in templateItems.enumerated() {
            let item = ChecklistItem(title: title, order: startOrder + i)
            checklist.items.append(item)
        }
        try? modelContext.save()
    }

    private func saveAsTemplate() {
        guard !templateName.isEmpty else { return }
        let items = checklist.items
            .sorted(by: { $0.order < $1.order })
            .map { $0.title }
        let template = ChecklistTemplate(name: templateName, items: items)
        modelContext.insert(template)
        try? modelContext.save()
        templateName = ""
    }
}
