// LuminaProfileView.swift
// iAlly
//
// Settings page for the Lumina profile.
// Organised by injection tier so users understand exactly what Lumina sees:
//
//   Tier 1 (ALWAYS SHARED): name, timezone, communicationStyle, currentFocus
//   Tier 2 (SHARED WHEN RELEVANT): auto-derived from Journeys, Plans, Routines
//   Tier 3 (NEVER AUTO-SHARED): healthNotes — stored on device, user pastes manually
//
// Access: Settings → Lumina AI → Lumina Profile

import SwiftUI
import SwiftData

struct LuminaProfileView: View {

    @State private var profile = UserProfile.current
    @State private var saveDebounce: Task<Void, Never>? = nil

    // Token estimate state
    @State private var alwaysTokens = 0
    @State private var maxTokens    = 0

    // SwiftData queries for auto-derived Tier 2 context
    // Note: Avoid #Predicate filters on optional enum fields (status) —
    // CloudKit schema may not have the column yet, causing a crash.
    @Query private var allJourneys: [Journey]
    @Query private var allPlans: [Plan]
    @Query private var allRoutines: [Routine]

    private var journeys: [Journey] { allJourneys.filter { $0.status != nil } }
    private var plans: [Plan] { allPlans.filter { $0.status != nil } }
    private var routines: [Routine] { allRoutines.filter { $0.isActive } }

    var body: some View {
        List {
            tokenBanner
            tier1Section
            tier2Section
            tier3Section
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.canvasPrimary.ignoresSafeArea())
        .navigationTitle("Lumina Profile")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { refreshTokenEstimate() }
        .onChange(of: profile.name)               { _, _ in autosave() }
        .onChange(of: profile.communicationStyle)  { _, _ in autosave() }
        .onChange(of: profile.currentFocus)        { _, _ in autosave() }
        .onChange(of: profile.healthNotes)         { _, _ in autosave() }
    }

    // MARK: - Token Banner

    private var tokenBanner: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 20))
                    .foregroundColor(DSColors.accentPrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("~\(alwaysTokens) tokens always · ~\(maxTokens) tokens maximum")
                        .font(DSFonts.body().weight(.medium))
                        .foregroundColor(DSColors.textPrimary)
                    Text("Lumina only receives relevant sections per message.")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(DSColors.accentPrimary.opacity(0.08))
    }

    // MARK: - Tier 1: Always Shared

    private var tier1Section: some View {
        Section {
            profileTextField(
                label: "Name",
                placeholder: "Your name",
                binding: $profile.name
            )

            // Timezone — auto-detected
            profileReadOnlyRow(
                label: "Timezone",
                value: profile.timezone,
                note: "Detected automatically"
            )

            profileTextField(
                label: "Communication style",
                placeholder: "e.g. brief and direct",
                binding: $profile.communicationStyle
            )

            profileTextField(
                label: "Current focus",
                placeholder: "e.g. iAlly launch by June",
                binding: $profile.currentFocus
            )
        } header: {
            tierHeader(
                title: "ALWAYS SHARED",
                systemImage: "checkmark.shield.fill",
                color: DSColors.accentPrimary
            )
        } footer: {
            Text("Sent with every Lumina message (~\(alwaysTokens) tokens). Keep it brief.")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
    }

    // MARK: - Tier 2: Auto-Derived Context

    private var tier2Section: some View {
        Section {
            let goalsPreview = ProfileContextBuilder.goalsContext(from: journeys)
            let lifestylePreview = ProfileContextBuilder.lifestyleContext(from: plans, routines: routines)
            let hasContent = !goalsPreview.isEmpty || !lifestylePreview.isEmpty

            if hasContent {
                if !goalsPreview.isEmpty {
                    autoDerivedRow(
                        label: "Goals",
                        source: "from Journeys",
                        value: goalsPreview
                    )
                }
                if !lifestylePreview.isEmpty {
                    autoDerivedRow(
                        label: "Lifestyle",
                        source: "from Plans & Routines",
                        value: lifestylePreview
                    )
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(DSColors.textTertiary)
                    Text("Start creating Journeys, Plans, and Routines — Lumina will learn your context automatically.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textTertiary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            tierHeader(
                title: "SHARED WHEN RELEVANT",
                systemImage: "arrow.triangle.2.circlepath",
                color: DSColors.accentSecondary
            )
        } footer: {
            Text("Auto-generated from your Journeys, Plans, and Routines. Lumina sees relevant sections per message.")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
    }

    // MARK: - Tier 3: Never Auto-Shared

    private var tier3Section: some View {
        Section {
            ZStack(alignment: .topLeading) {
                if profile.healthNotes.isEmpty {
                    Text("e.g. Type 1 diabetic, avoid high-intensity tasks before meals")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $profile.healthNotes)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
            }
        } header: {
            tierHeader(
                title: "NEVER AUTO-SHARED",
                systemImage: "lock.fill",
                color: DSColors.error
            )
        } footer: {
            Text("Stored on device only. Paste into a Lumina conversation yourself when it's relevant.")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .listRowBackground(DSColors.error.opacity(0.05))
    }

    // MARK: - Reusable row components

    @ViewBuilder
    private func profileTextField(
        label: String,
        placeholder: String,
        binding: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DSFonts.caption().weight(.medium))
                .foregroundColor(DSColors.textSecondary)
            TextField(placeholder, text: binding, axis: .vertical)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(1...4)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func profileReadOnlyRow(label: String, value: String, note: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(DSFonts.caption().weight(.medium))
                    .foregroundColor(DSColors.textSecondary)
                Text(value)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
            }
            Spacer()
            Text(note)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textTertiary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func autoDerivedRow(label: String, source: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(DSFonts.caption().weight(.medium))
                    .foregroundColor(DSColors.textSecondary)
                Text(source)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DSColors.accentSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(DSColors.accentSecondary.opacity(0.12))
                    .clipShape(Capsule())
            }
            Text(value)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func tierHeader(title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            Text(title)
        }
    }

    // MARK: - Persistence

    private func autosave() {
        saveDebounce?.cancel()
        saveDebounce = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            UserProfile.current = profile
            refreshTokenEstimate()
        }
    }

    private func refreshTokenEstimate() {
        let tier2Preview = ProfileContextBuilder.fullPreview(
            journeys: journeys, plans: plans, routines: routines
        )
        let (a, m) = LuminaSystemPromptBuilder.estimateTokens(
            for: .welcome(),
            profile: profile,
            tier2Context: tier2Preview
        )
        alwaysTokens = a
        maxTokens    = m
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LuminaProfileView()
    }
}
