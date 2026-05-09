//
//  LuminaSession.swift
//  iAlly
//
//  GAP 3: Persistent Conversation History
//  Stores Lumina chat sessions and their messages in SwiftData so conversations
//  survive app restarts. LuminaConversationService loads the most recent session
//  on launch and persists every new message turn as it arrives.
//

import Foundation
import SwiftData

/// One Lumina conversation session (maps to a PAI memory namespace sessionID).
@Model
final class LuminaSession {
    var id: UUID = UUID()
    var sessionID: String = ""           // UUID used in PAI memory namespace
    var title: String = "Conversation"   // Auto-set from first user message (max 40 chars)
    var startedAt: Date = Date()
    var lastMessageAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PersistedLuminaMessage.session)
    var messages: [PersistedLuminaMessage]? = []

    init(sessionID: String) {
        self.sessionID = sessionID
    }

    /// Convenience: ordered messages oldest-first.
    var orderedMessages: [PersistedLuminaMessage] {
        (messages ?? []).sorted { $0.timestamp < $1.timestamp }
    }
}

/// A single persisted message within a LuminaSession.
@Model
final class PersistedLuminaMessage {
    var id: UUID = UUID()
    var role: String = "user"      // "user" | "assistant"
    var content: String = ""
    var timestamp: Date = Date()

    var session: LuminaSession?

    init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
