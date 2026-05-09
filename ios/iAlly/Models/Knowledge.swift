//
//  Knowledge.swift
//  iAlly
//
//  Phase 2: Capture & Knowledge Layer
//  First-class SwiftData model for learnings, decisions, observations,
//  quotes, insights and notes — the non-task content of a second brain.
//

import Foundation
import SwiftData

@Model
final class Knowledge {

    // MARK: Persistent properties
    // All non-optional stored properties have property-level defaults so that
    // SwiftData/CoreData can set the NSAttributeDescription.defaultValue correctly.
    // This is required for CloudKit-entitlement validation even when cloudKitDatabase: .none.
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    // typeRaw stores the KnowledgeItemType.rawValue; default matches .note
    var typeRaw: String = "Note"
    // Tags stored as a comma-separated String — CloudKit-native type.
    // [String] would become a Transformable attribute which CloudKit validation rejects.
    var tagsRaw: String = ""
    var source: String?           // URL, book title, person, app, etc.
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPAISynced: Bool = false  // true once successfully sent to PAI memory

    // MARK: Init
    init(
        title: String,
        content: String,
        type: KnowledgeItemType,
        tags: [String] = [],
        source: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.typeRaw = type.rawValue
        self.tagsRaw = tags.joined(separator: ",")
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPAISynced = false
    }

    // MARK: Computed (not stored — SwiftData/CloudKit ignore these)

    /// Tags decoded from the stored comma-separated string.
    /// Using a computed getter/setter keeps all call sites unchanged.
    var tags: [String] {
        get {
            guard !tagsRaw.isEmpty else { return [] }
            return tagsRaw.split(separator: ",").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }
        }
        set {
            tagsRaw = newValue.joined(separator: ",")
        }
    }

    /// Knowledge item type decoded from typeRaw.
    /// Renamed from `type` to `itemType` to avoid a collision with the `type` keyword
    /// in @Model macro expansion, which caused CoreData to omit attribute defaults.
    var itemType: KnowledgeItemType {
        KnowledgeItemType(rawValue: typeRaw) ?? .note
    }
}

// MARK: - Knowledge item type

enum KnowledgeItemType: String, Codable, CaseIterable, Identifiable {
    case learning     = "Learning"
    case decision     = "Decision"
    case observation  = "Observation"
    case quote        = "Quote"
    case insight      = "Insight"
    case note         = "Note"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .learning:    return "lightbulb.fill"
        case .decision:    return "arrow.triangle.branch"
        case .observation: return "eye.fill"
        case .quote:       return "quote.bubble.fill"
        case .insight:     return "sparkles"
        case .note:        return "note.text"
        }
    }

    var colorHex: String {
        switch self {
        case .learning:    return "#F5A623"
        case .decision:    return "#7ED321"
        case .observation: return "#4A90E2"
        case .quote:       return "#9B59B6"
        case .insight:     return "#E74C3C"
        case .note:        return "#7F8C8D"
        }
    }
}
