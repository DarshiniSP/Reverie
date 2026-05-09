//
//  ChecklistItemRow.swift
//  iAlly
//
//  Lightweight checkbox row for checklist items within a task.
//

import SwiftUI

struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(DSFonts.headline())
                    .foregroundColor(item.isCompleted ? DSColors.success : DSColors.textSecondary)
            }
            .buttonStyle(.plain)

            // Title
            Text(item.title)
                .font(DSFonts.body())
                .foregroundColor(item.isCompleted ? DSColors.textSecondary : DSColors.textPrimary)
                .strikethrough(item.isCompleted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Delete
            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            item.isCompleted
                ? DSColors.success.opacity(0.05)
                : DSColors.canvasSecondary.opacity(0.5)
        )
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
}
