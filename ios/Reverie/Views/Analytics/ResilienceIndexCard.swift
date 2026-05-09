//
//  ResilienceIndexCard.swift
//  Reverie
//
//  Displays the Resilience Index score with a ring gauge,
//  level label, 5-signal component breakdown, data-source badge,
//  and contextual Lumina message.
//

import SwiftUI
import SwiftData

struct ResilienceIndexCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var score: ResilienceScore? = nil

    private var ringColor: Color {
        guard let s = score else { return DSColors.accentPrimary }
        return Color(hex: s.level.colorHex)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header gradient strip
            LinearGradient(
                colors: [ringColor.opacity(0.7), ringColor.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 3)
            .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))

            VStack(alignment: .leading, spacing: 16) {

                // Title row
                HStack {
                    Label("Resilience Index", systemImage: "waveform.path.ecg.rectangle")
                        .font(DSFonts.label(13))
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                    if let s = score {
                        Text(s.level.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(ringColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ringColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                // Score ring + components
                HStack(spacing: 24) {
                    // Ring gauge
                    ZStack {
                        Circle()
                            .stroke(DSColors.divider, lineWidth: 10)
                            .frame(width: 100, height: 100)

                        Circle()
                            .trim(from: 0, to: CGFloat((score?.value ?? 0) / 100.0))
                            .stroke(
                                LinearGradient(
                                    colors: [ringColor, ringColor.opacity(0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.8), value: score?.value)

                        VStack(spacing: 2) {
                            Text("\(Int(score?.value ?? 0))")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(DSColors.textPrimary)
                            Text("/ 100")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }

                    // Component bars
                    if let s = score {
                        VStack(alignment: .leading, spacing: 8) {
                            // Mood/energy check-in — shown only when contributing
                            if let wb = s.components.wellbeing {
                                componentBar(
                                    label: "Mood",
                                    value: wb,
                                    color: DSColors.accentPrimary,
                                    weight: "20%"
                                )
                            }
                            componentBar(label: "Anchors",     value: s.components.routineAdherence, color: Color(hex: "7A8A5C"), weight: s.checkInContributing ? "25%" : "31%")
                            componentBar(label: "Load",        value: s.components.loadBalance,      color: DSColors.accentSecondary, weight: s.checkInContributing ? "25%" : "31%")
                            componentBar(label: "Consistency", value: s.components.consistency,      color: DSColors.success, weight: s.checkInContributing ? "20%" : "25%")
                            componentBar(label: "Trend",       value: s.components.engagementTrend,  color: Color(hex: "9B7CB6"), weight: s.checkInContributing ? "10%" : "13%")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Skeleton
                        VStack(spacing: 8) {
                            ForEach(0..<5) { _ in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DSColors.divider)
                                    .frame(height: 10)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Data source badge
                if let s = score {
                    dataSourceBadge(contributing: s.checkInContributing)
                }

                // Lumina message
                if let s = score {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: s.level.icon)
                            .font(.system(size: 13))
                            .foregroundColor(ringColor)
                        Text(s.level.message)
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.textSecondary)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .background(ringColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Crisis support banner (shown when critical)
                if score?.level == .critical {
                    CrisisSupportBanner()
                }

                // Formula footnote — adapts based on whether check-in is active
                formulaFootnote
            }
            .padding(16)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight]))
        }
        .shadow(color: DSColors.shadow, radius: 10, x: 0, y: 3)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DSColors.divider, lineWidth: 0.5))
        .onAppear { score = ResilienceEngine.shared.compute(context: modelContext) }
    }

    // MARK: - Data Source Badge

    private func dataSourceBadge(contributing: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: contributing ? "checkmark.circle.fill" : "eye.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(contributing
                 ? "Check-in data contributing"
                 : "Behavioural signals only — check-in will refine this")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(contributing ? DSColors.success : DSColors.textTertiary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            contributing
                ? DSColors.success.opacity(0.08)
                : DSColors.canvasPrimary
        )
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                contributing ? DSColors.success.opacity(0.2) : DSColors.divider,
                lineWidth: 0.8
            )
        )
    }

    // MARK: - Formula Footnote

    private var formulaFootnote: some View {
        VStack(alignment: .leading, spacing: 3) {
            if score?.checkInContributing == true {
                Text("R = 0.20×mood + 0.25×anchors + 0.25×load + 0.20×consistency + 0.10×trend")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(DSColors.textTertiary)
            } else {
                Text("R = 0.31×anchors + 0.31×load + 0.25×consistency + 0.13×trend")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(DSColors.textTertiary)
                Text("(check-in offline — behavioural weights renormalised)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(DSColors.textTertiary.opacity(0.7))
            }
            Text("Basis: Maslach & Jackson (1981) · Sweller (1988)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DSColors.textTertiary.opacity(0.6))
        }
        .padding(.top, 2)
    }

    // MARK: - Component Bar

    private func componentBar(label: String, value: Double, color: Color, weight: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Text(weight)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(DSColors.textTertiary)
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSColors.divider).frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value), height: 5)
                        .animation(.easeOut(duration: 0.6), value: value)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Crisis Support Banner

struct CrisisSupportBanner: View {
    @State private var showResources = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(DSColors.accentPrimary)
                    .font(.system(size: 14))
                Text("You don't have to carry this alone.")
                    .font(DSFonts.label(13))
                    .foregroundColor(DSColors.textPrimary)
            }

            Text("It's okay to reach out. Talking to someone — a friend, a counsellor, or a helpline — can make a real difference.")
                .font(DSFonts.body(12))
                .foregroundColor(DSColors.textSecondary)
                .lineSpacing(2)

            Button {
                showResources.toggle()
            } label: {
                Label(showResources ? "Hide resources" : "See support resources",
                      systemImage: showResources ? "chevron.up" : "chevron.down")
                    .font(DSFonts.caption(12))
                    .foregroundColor(DSColors.accentPrimary)
            }

            if showResources {
                VStack(alignment: .leading, spacing: 8) {
                    supportRow(title: "SOS Singapore (24hr)",      detail: "1-767",       icon: "phone.fill")
                    supportRow(title: "IMH Mental Health Helpline", detail: "6389-2222",   icon: "heart.text.square.fill")
                    supportRow(title: "Talk to your school counsellor", detail: "Reach out via email or in person", icon: "person.fill.questionmark")
                }
                .padding(10)
                .background(DSColors.canvasPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(DSColors.accentPrimary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DSColors.accentPrimary.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: showResources)
    }

    private func supportRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DSFonts.body(12))
                    .fontWeight(.medium)
                    .foregroundColor(DSColors.textPrimary)
                Text(detail)
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
    }
}
