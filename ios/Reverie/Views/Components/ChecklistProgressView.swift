//
//  ChecklistProgressView.swift
//  iAlly
//
//  Circular progress indicator for checklist completion (adapted from SubtaskProgressView).
//

import SwiftUI

struct ChecklistProgressView: View {
    let completed: Int
    let total: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(DSColors.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        completed == total && total > 0 ? DSColors.success : DSColors.accentPrimary,
                        lineWidth: 2
                    )
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))

                if total > 0 {
                    Text("\(completed)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(
                            completed == total ? DSColors.success : DSColors.accentPrimary
                        )
                }
            }

            Text("\(completed)/\(total)")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ChecklistProgressView(completed: 0, total: 5)
        ChecklistProgressView(completed: 3, total: 7)
        ChecklistProgressView(completed: 5, total: 5)
    }
    .padding()
}
