import SwiftUI

// MARK: - Energy Persistence

enum EnergyCheckInStore {
    private static let key     = "energyCheckIn.value"
    private static let dateKey = "energyCheckIn.date"

    static func save(_ level: DailyEnergyLevel) {
        UserDefaults.standard.set(level.rawValue, forKey: key)
        UserDefaults.standard.set(Calendar.current.startOfDay(for: Date()), forKey: dateKey)
    }
    static func load() -> DailyEnergyLevel? {
        guard let saved = UserDefaults.standard.object(forKey: dateKey) as? Date,
              Calendar.current.isDateInToday(saved),
              let raw = UserDefaults.standard.string(forKey: key)
        else { return nil }
        return DailyEnergyLevel(rawValue: raw)
    }
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}

// MARK: - Energy Model

enum DailyEnergyLevel: String, CaseIterable {
    case low    = "Low"
    case medium = "Medium"
    case high   = "High"

    var icon: String {
        switch self {
        case .low:    return "battery.25"
        case .medium: return "battery.50"
        case .high:   return "battery.100.bolt"
        }
    }
    var color: Color {
        switch self {
        case .low:    return DSColors.error
        case .medium: return DSColors.warning
        case .high:   return DSColors.success
        }
    }
    var label: String {
        switch self {
        case .low:    return "Take it easy"
        case .medium: return "Steady focus"
        case .high:   return "Full power"
        }
    }
}

// MARK: - Combined Daily Check-In Card

struct DailyCheckInCard: View {
    @Binding var selectedEnergy: DailyEnergyLevel?
    @Binding var selectedStress: DailyStressLevel?
    var onEnergySelect: (DailyEnergyLevel) -> Void
    var onStressSelect: (DailyStressLevel) -> Void

    var isComplete: Bool { selectedEnergy != nil && selectedStress != nil }

    var body: some View {
        if isComplete {
            collapsedView
        } else {
            expandedCard
        }
    }

    // MARK: Collapsed pill

    private var collapsedView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                if let energy = selectedEnergy {
                    HStack(spacing: 5) {
                        Image(systemName: energy.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(energy.color)
                        Text(energy.rawValue)
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                if selectedEnergy != nil && selectedStress != nil {
                    Text("·").foregroundColor(DSColors.textTertiary)
                }
                if let stress = selectedStress {
                    HStack(spacing: 5) {
                        Image(systemName: stress.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(stress.color)
                        Text(stress.rawValue)
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedEnergy = nil
                        selectedStress = nil
                        EnergyCheckInStore.clear()
                        StressCheckInStore.clear()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(DSColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Resilience update indicator
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 10, weight: .semibold))
                Text("Resilience Index updated")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(DSColors.accentPrimary.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColors.accentPrimary.opacity(0.18), lineWidth: 1))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: Expanded card

    private var expandedCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "sun.and.horizon.fill")
                    .foregroundColor(DSColors.warning)
                Text("How are you feeling today?")
                    .font(DSFonts.label(15))
                    .foregroundColor(DSColors.textPrimary)
            }

            // Energy row
            VStack(alignment: .leading, spacing: 8) {
                Text("Energy")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                HStack(spacing: 8) {
                    ForEach(DailyEnergyLevel.allCases, id: \.self) { level in
                        CheckInOptionButton(
                            icon: level.icon,
                            label: level.rawValue,
                            color: level.color,
                            isSelected: selectedEnergy == level
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                onEnergySelect(level)
                            }
                        }
                    }
                }
            }

            // Mood row
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                HStack(spacing: 8) {
                    ForEach(DailyStressLevel.allCases, id: \.self) { level in
                        CheckInOptionButton(
                            icon: level.icon,
                            label: level.shortLabel,
                            color: level.color,
                            isSelected: selectedStress == level
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                onStressSelect(level)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [DSColors.warning.opacity(0.05), DSColors.canvasSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DSColors.warning.opacity(0.18), lineWidth: 1))
        .shadow(color: DSColors.shadow, radius: 10, x: 0, y: 3)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

// MARK: - Shared Option Button (used by both energy and mood rows)

struct CheckInOptionButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : color)
                Text(label)
                    .font(DSFonts.caption(11))
                    .foregroundColor(isSelected ? .white : DSColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : color.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : color.opacity(0.22), lineWidth: 1)
            )
        }
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}
