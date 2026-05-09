// LuminaNote.swift
// iAlly
//
// A quick-capture scratchpad note — like iOS Notes.
// User captures a thought fast; reviews later and promotes to Task, Journey,
// Routine, or Knowledge. Never injected into Lumina context automatically.

import Foundation
import SwiftData

@Model
final class LuminaNote {
    var id: UUID = UUID()
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isArchived: Bool = false   // archived after promoting or manual archive

    /// Which action the user took when promoting this note (for audit trail).
    var promotedTo: String? = nil  // "task" | "journey" | "routine" | "knowledge" | nil

    init(content: String) {
        self.id        = UUID()
        self.content   = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
