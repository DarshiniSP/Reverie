//
//  SubtaskProgressView.swift
//  iAlly
//
//  Created for subtasks feature
//

import SwiftUI

struct SubtaskProgressView: View {
    let completed: Int
    let total: Int
    
    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(DSColors.textSecondary.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DSColors.accentPrimary, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(-90))
                
                if total > 0 {
                    Text("\(completed)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(DSColors.accentPrimary)
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
        SubtaskProgressView(completed: 0, total: 5)
        SubtaskProgressView(completed: 2, total: 5)
        SubtaskProgressView(completed: 5, total: 5)
    }
    .padding()
}
