import SwiftUI

// MARK: - Persistence

enum StressCheckInStore {
    private static let valueKey = "stressCheckIn.value"
    private static let dateKey  = "stressCheckIn.date"

    static func save(_ level: DailyStressLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: valueKey)
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: dateKey)
    }

    static func load() -> DailyStressLevel? {
        guard
            let saved = UserDefaults.standard.object(forKey: dateKey) as? Date,
            Calendar.current.isDateInToday(saved),
            let raw = UserDefaults.standard.string(forKey: valueKey)
        else { return nil }
        return DailyStressLevel(rawValue: raw)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: valueKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}

// MARK: - Model

enum DailyStressLevel: String, CaseIterable {
    case calm     = "Calm"
    case moderate = "Stressed"
    case high     = "Overwhelmed"

    var icon: String {
        switch self {
        case .calm:     return "leaf.fill"
        case .moderate: return "brain.head.profile"
        case .high:     return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .calm:     return DSColors.success
        case .moderate: return DSColors.warning
        case .high:     return DSColors.error
        }
    }

    var shortLabel: String { rawValue }

    // Offline insight shown every time the app opens when this stress level is active
    var dailyInsights: [String] {
        switch self {
        case .calm:
            return [
                "You're in a great headspace today. Use this clarity to make progress on something meaningful.",
                "Calm days are rare — a good time to tackle something you've been putting off.",
                "Steady energy is your superpower today. Make it count."
            ]
        case .moderate:
            return [
                "You're carrying a lot right now. Pick just one priority for the morning and protect that focus.",
                "Stressed but still standing. Break your biggest task into the smallest possible first step.",
                "When everything feels urgent, almost nothing actually is. What truly needs to happen today?",
                "Drink some water, take three breaths, then start the one thing that will matter tomorrow.",
                "Stress is a signal, not a sentence. What's one thing you can take off your plate today?"
            ]
        case .high:
            return [
                "Feeling overwhelmed is your mind asking for a rest, not more effort. Start with one small win.",
                "You don't have to do everything today. What's the single most important thing?",
                "High stress narrows focus. That's not failure — it's your brain protecting you. Work with it.",
                "Write down everything stressing you. Getting it out of your head and onto a list reduces it instantly.",
                "It's okay to not be okay. Focus on the next 2 hours only — not the whole week.",
                "Even completing one small task today is a win worth celebrating."
            ]
        }
    }

    var todayInsight: String {
        // Rotate through insights based on day of year so it feels fresh daily
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let pool = dailyInsights
        return pool[dayOfYear % pool.count]
    }
}

// MARK: - Stress Insight Banner (shown on app open when stress is set)

struct StressInsightBanner: View {
    let stress: DailyStressLevel
    @State private var isExpanded = true

    var body: some View {
        if isExpanded {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stress.color.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: stress.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(stress.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reverie for you today")
                        .font(DSFonts.caption(11))
                        .foregroundColor(DSColors.textTertiary)
                        .textCase(.uppercase)
                    Text(stress.todayInsight)
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { isExpanded = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DSColors.textTertiary)
                }
            }
            .padding(14)
            .background(stress.color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(stress.color.opacity(0.15), lineWidth: 0.5)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
