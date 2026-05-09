import SwiftUI
import SwiftData

enum CountdownType: String, Codable, CaseIterable {
    case exam       = "Exam"
    case ns         = "National Service"
    case psle       = "PSLE"
    case aLevel     = "A-Level"
    case oLevel     = "O-Level"
    case deadline   = "Deadline"
    case personal   = "Personal"

    var icon: String {
        switch self {
        case .exam, .psle, .aLevel, .oLevel: return "graduationcap.fill"
        case .ns:       return "shield.fill"
        case .deadline: return "calendar.badge.exclamationmark"
        case .personal: return "flag.fill"
        }
    }

    var color: String {
        switch self {
        case .exam, .psle, .aLevel, .oLevel: return "5C8A6E"
        case .ns:       return "3A6B8E"
        case .deadline: return "C4714A"
        case .personal: return "7A8A5C"
        }
    }
}

@Model
final class CountdownEvent {
    var id: UUID
    var title: String
    var targetDate: Date
    var type: CountdownType
    var notes: String?
    var isArchived: Bool
    var createdAt: Date

    init(
        title: String,
        targetDate: Date,
        type: CountdownType = .exam,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.targetDate = targetDate
        self.type = type
        self.notes = notes
        self.isArchived = false
        self.createdAt = Date()
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: targetDate)
        return calendar.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var urgencyColor: Color {
        switch daysRemaining {
        case ..<0:   return Color(hex: "C4514A")   // Passed
        case 0..<7:  return Color(hex: "C4714A")   // This week
        case 7..<30: return Color(hex: "D4945A")   // This month
        default:     return Color(hex: "5C8A6E")   // Plenty of time
        }
    }

    var urgencyLabel: String {
        switch daysRemaining {
        case ..<0:  return "Passed"
        case 0:     return "Today!"
        case 1:     return "Tomorrow"
        default:    return "\(daysRemaining) days"
        }
    }
}
