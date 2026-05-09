//
//  ComingSoonView.swift
//  iAlly
//
//  Created for Phase 1 placeholder features
//

import SwiftUI

struct ComingSoonView: View {
    let featureName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            DSColors.canvasPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundColor(DSColors.accentPrimary)
                
                Text("\(featureName) Coming Soon")
                    .font(DSFonts.title())
                    .foregroundColor(DSColors.textPrimary)
                
                Text("This feature will be available in a future update.")
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button("Got It") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(featureName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ComingSoonView(featureName: "Analytics Dashboard")
    }
}
