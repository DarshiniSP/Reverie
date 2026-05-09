// OnboardingView.swift
// iAlly — Conversational Lumina Onboarding
//
// Replaces the static demo-data dump with a 3-question Lumina setup.
// The user is asked:
//   1. Their preferred name
//   2. Their most important goal right now
//   3. What a successful week looks like for them
// These answers are stored in PAI semantic memory so Lumina builds
// an accurate user model from day one.

import SwiftUI

struct OnboardingView: View {
    @Binding var isCompleted: Bool
    @State private var currentPage = 0
    private let totalInfoPages = 3

    @State private var userName = ""
    @State private var topGoal = ""
    @State private var successWeek = ""
    @State private var isSettingUp = false
    @State private var setupComplete = false

    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Your second brain",
            description: "Capture tasks, build habits, and chase big goals — all in one place. Your data stays on your device. No accounts, no tracking.",
            imageName: "brain.head.profile",
            color: DSColors.accentPrimary
        ),
        OnboardingPage(
            title: "Build momentum",
            description: "Streak tracking, energy-aware scheduling, and growth insights help you work with yourself — not against yourself.",
            imageName: "flame.fill",
            color: DSColors.warning
        ),
        OnboardingPage(
            title: "Meet Lumina",
            description: "Your on-device AI. Lumina learns your patterns, surfaces what matters, and helps you think — privately, offline-first.",
            imageName: "sparkles",
            color: DSColors.accentSecondary
        )
    ]

    var body: some View {
        ZStack {
            // Background
            (currentPage < totalInfoPages ? pages[currentPage].color : DSColors.accentSecondary)
                .opacity(0.1)
                .ignoresSafeArea()

            if currentPage < totalInfoPages {
                infoSlides
            } else {
                luminaSetupScreen
            }
        }
        .transition(.opacity)
    }

    // MARK: - Info Slides

    private var infoSlides: some View {
        VStack {
            // Skip button for UI testing
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UITest_SkipOnboarding") {
                HStack {
                    Spacer()
                    Button("Skip") {
                        withAnimation { isCompleted = true }
                    }
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(UIConstants.CornerRadius.round)
                    .accessibilityIdentifier("skipOnboardingButton")
                }
                .padding(.top, 10)
                .padding(.trailing, 20)
            }
            #endif

            TabView(selection: $currentPage) {
                ForEach(0..<totalInfoPages, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .foregroundColor(DSColors.textSecondary)
                    .padding()
                }
                Spacer()
                Button(action: {
                    withAnimation {
                        if currentPage < totalInfoPages - 1 {
                            currentPage += 1
                        } else {
                            currentPage = totalInfoPages  // → Lumina setup
                        }
                    }
                }) {
                    Text(currentPage < totalInfoPages - 1 ? "Next" : "Set up with Lumina →")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.onAccent)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 16)
                        .background(pages[currentPage].color)
                        .cornerRadius(UIConstants.CornerRadius.round)
                        .shadow(radius: 5)
                }
                .padding()
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Lumina Setup (3 questions)

    private var luminaSetupScreen: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Lumina avatar + greeting
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [DSColors.accentPrimary.opacity(0.18), DSColors.accentSecondary.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: DSColors.accentPrimary.opacity(0.2), radius: 16, x: 0, y: 8)

                    VStack(spacing: 6) {
                        Text("Hi, I'm Lumina.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(DSColors.textPrimary)

                        Text("Three quick questions so I can get to\nknow you. This becomes my memory of who you are.")
                            .font(DSFonts.body(15))
                            .foregroundColor(DSColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 40)

                // Question 1
                setupCard(
                    number: "1",
                    question: "What should I call you?",
                    placeholder: "Your name or nickname",
                    binding: $userName
                )

                // Question 2
                setupCard(
                    number: "2",
                    question: "What's your most important goal right now?",
                    placeholder: "e.g. Launch my side project, get fit, learn Swift…",
                    binding: $topGoal
                )

                // Question 3
                setupCard(
                    number: "3",
                    question: "What does a successful week look like for you?",
                    placeholder: "e.g. Hit the gym 3 times, finish key work tasks, spend time with family…",
                    binding: $successWeek
                )

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: completeSetup) {
                        Group {
                            if isSettingUp {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Lumina is remembering…")
                                }
                            } else {
                                Text("Start with Lumina")
                            }
                        }
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(DSColors.accentSecondary)
                        .cornerRadius(UIConstants.CornerRadius.extraLarge)
                        .shadow(color: .indigo.opacity(0.3), radius: 8)
                    }
                    .disabled(isSettingUp || userName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 24)

                    Button("Skip setup") {
                        withAnimation { isCompleted = true }
                    }
                    .foregroundColor(DSColors.textSecondary)
                    .font(DSFonts.label())
                    .padding(.bottom, 8)
                }
                .padding(.bottom, 40)
            }
        }
        .background(DSColors.canvasPrimary)
    }

    @ViewBuilder
    private func setupCard(number: String, question: String, placeholder: String, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Text(number)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(question)
                    .font(DSFonts.headline(16))
                    .foregroundColor(DSColors.textPrimary)
            }

            TextField(placeholder, text: binding, axis: .vertical)
                .lineLimit(2...4)
                .font(DSFonts.body(15))
                .padding(14)
                .background(DSColors.canvasSecondary)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            binding.wrappedValue.isEmpty ? DSColors.divider : DSColors.accentPrimary.opacity(0.4),
                            lineWidth: 1
                        )
                )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Setup Completion

    private func completeSetup() {
        isSettingUp = true
        Task { @MainActor in
            let name = userName.trimmingCharacters(in: .whitespaces)
            let goal = topGoal.trimmingCharacters(in: .whitespaces)
            let week = successWeek.trimmingCharacters(in: .whitespaces)

            // Persist to UserProfile (UserDefaults) so Lumina always knows the user
            var profile = UserProfile.current
            if !name.isEmpty { profile.name = name }
            if !week.isEmpty { profile.currentFocus = week }
            UserProfile.current = profile

            // Record to PAI semantic memory (fire-and-forget, bonus when PAI is reachable)
            if !name.isEmpty {
                PAIMemoryBridge.shared.recordKnowledge(
                    content: "User's preferred name is \"\(name)\".",
                    type: .insight,
                    tags: ["identity", "user-name"]
                )
            }
            if !goal.isEmpty {
                PAIMemoryBridge.shared.recordKnowledge(
                    content: "User's most important current goal: \"\(goal)\".",
                    type: .insight,
                    tags: ["goal", "top-priority"]
                )
            }
            if !week.isEmpty {
                PAIMemoryBridge.shared.recordKnowledge(
                    content: "User's definition of a successful week: \"\(week)\".",
                    type: .insight,
                    tags: ["success-criteria", "weekly-vision"]
                )
            }

            // Brief pause so the spinner shows (and PAI gets the writes in flight)
            try? await Task.sleep(nanoseconds: 800_000_000)
            isSettingUp = false
            withAnimation { isCompleted = true }
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon with layered glow rings
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.06))
                    .frame(width: 260, height: 260)
                Circle()
                    .fill(page.color.opacity(0.11))
                    .frame(width: 200, height: 200)
                Circle()
                    .fill(page.color.opacity(0.18))
                    .frame(width: 140, height: 140)
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [page.color, page.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Image(systemName: page.imageName)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundColor(.white)
                }
                .shadow(color: page.color.opacity(0.45), radius: 20, x: 0, y: 10)
            }

            Spacer().frame(height: 40)

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(DSFonts.body(16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.horizontal, 32)
                    .lineSpacing(5)
            }

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isCompleted: .constant(false))
}
