//
//  StreakRecoveryView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI

struct StreakRecoveryView: View {
    let routineName: String
    let newStreak: Int
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiCount: Int = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Celebration Card
            VStack(spacing: 20) {
                // Animated Icon
                ZStack {
                    Circle()
                        .fill(DSColors.success.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 50))
                        .foregroundColor(DSColors.warning)
                        .rotationEffect(.degrees(confettiCount > 0 ? 10 : -10))
                        .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: confettiCount)
                }
                .scaleEffect(scale)
                
                // Message
                VStack(spacing: 8) {
                    Text("Comeback!")
                        .font(DSFonts.title())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("Your **\(routineName)** streak is back!")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame")
                            .foregroundColor(DSColors.warning)
                        Text("\(newStreak) day\(newStreak == 1 ? "" : "s")")
                            .font(DSFonts.headline(24))
                            .foregroundColor(DSColors.warning)
                    }
                    .padding(.top, 8)
                }
                .opacity(opacity)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.round)
                    .fill(DSColors.canvasSecondary)
                    .shadow(color: DSColors.shadow, radius: 20)
            )
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            
            // Confetti particles
            ForEach(0..<confettiCount, id: \.self) { index in
                ConfettiParticle(index: index)
            }
        }
        .onAppear {
            startAnimation()
            
            // Auto dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                dismiss()
            }
        }
    }
    
    private func startAnimation() {
        // Scale and fade in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Trigger confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                confettiCount = 30
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 0.8
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

struct ConfettiParticle: View {
    let index: Int
    
    @State private var offsetY: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let colors: [Color] = [
        .orange, .yellow, DSColors.success, .blue, .purple, .pink
    ]
    
    private var color: Color {
        colors[index % colors.count]
    }
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .cornerRadius(2)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .offset(x: offsetX, y: offsetY)
            .onAppear {
                // Random starting position near center
                let startX = CGFloat.random(in: -50...50)
                let startY = CGFloat.random(in: -50...50)
                
                // Random end position (falling down and spreading out)
                let endX = startX + CGFloat.random(in: -100...100)
                let endY = startY + CGFloat.random(in: 200...400)
                
                // Random rotation
                let endRotation = Double.random(in: -360...360)
                
                // Stagger animation slightly
                let delay = Double(index) * 0.02
                
                withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                    offsetX = endX
                    offsetY = endY
                    rotation = endRotation
                    opacity = 0
                }
            }
    }
}

#Preview {
    StreakRecoveryView(
        routineName: "Morning Meditation",
        newStreak: 5,
        isPresented: .constant(true)
    )
}
