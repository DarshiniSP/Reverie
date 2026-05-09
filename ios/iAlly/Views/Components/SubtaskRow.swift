//
//  SubtaskRow.swift
//  iAlly
//
//  Created for subtasks feature
//

import SwiftUI
import SwiftData

struct SubtaskRow: View {
    @Bindable var subtask: TaskWork
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left border (category color at 50% opacity for subtasks)
            Rectangle()
                .fill(Color(hex: subtask.displayColorHex))
                .opacity(subtask.displayOpacity)
                .frame(width: 4)
            
            HStack(spacing: 12) {
                // Completion checkbox with icon background
                Button {
                    toggleCompletion()
                } label: {
                    ZStack {
                        // Icon background (category color, subtle)
                        Circle()
                            .fill(Color(hex: subtask.displayColorHex))
                            .opacity(subtask.displayOpacity * 0.2)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(DSFonts.headline())
                            .foregroundColor(
                                subtask.isCompleted 
                                    ? .green 
                                    : Color(hex: subtask.displayColorHex).opacity(subtask.displayOpacity)
                            )
                    }
                }
                .buttonStyle(.plain)
                
                // Subtask title
                Button {
                    onTap()
                } label: {
                    Text(subtask.title)
                        .font(DSFonts.body())
                        .foregroundColor(subtask.isCompleted ? DSColors.textSecondary : DSColors.textPrimary)
                        .strikethrough(subtask.isCompleted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                
                // Delete button
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.error)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        // Background tint (category color, very subtle)
        .background(
            Color(hex: subtask.displayColorHex)
                .opacity(subtask.displayOpacity * 0.1)
        )
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
    
    private func toggleCompletion() {
        if subtask.isCompleted {
            subtask.completedAt = nil
        } else {
            subtask.completedAt = Date()
        }
    }
}
