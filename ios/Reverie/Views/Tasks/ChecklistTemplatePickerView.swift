//
//  ChecklistTemplatePickerView.swift
//  iAlly
//
//  Sheet for selecting a reusable checklist template to apply to a task.
//

import SwiftUI
import SwiftData

struct ChecklistTemplatePickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\ChecklistTemplate.usageCount, order: .reverse)])
    private var templates: [ChecklistTemplate]

    let onApply: ([String]) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates Yet",
                        systemImage: "checklist",
                        description: Text("Save a checklist from any task to create a reusable template.")
                    )
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                applyTemplate(template)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: template.icon)
                                        .font(DSFonts.headline())
                                        .foregroundColor(DSColors.accentPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(DSColors.accentPrimary.opacity(0.1))
                                        .cornerRadius(UIConstants.CornerRadius.standard)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(DSFonts.body())
                                            .foregroundColor(DSColors.textPrimary)
                                        Text("\(template.items.count) items")
                                            .font(DSFonts.caption())
                                            .foregroundColor(DSColors.textSecondary)
                                    }

                                    Spacer()

                                    if template.usageCount > 0 {
                                        Text("Used \(template.usageCount)x")
                                            .font(DSFonts.caption())
                                            .foregroundColor(DSColors.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }
            }
            .navigationTitle("Checklist Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func applyTemplate(_ template: ChecklistTemplate) {
        template.usageCount += 1
        try? modelContext.save()
        onApply(template.items)
        dismiss()
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
    }
}
