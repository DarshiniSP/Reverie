// PAIChatMessage.swift
// iAlly
//
// Lightweight message struct used by all inference providers.
// Placed in the Inference directory alongside LuminaInferenceProvider protocol.

import Foundation

struct PAIChatMessage: Codable, Sendable {
    let role: String
    let content: String
    init(role: String, content: String) { self.role = role; self.content = content }
    static func user(_ text: String) -> PAIChatMessage { .init(role: "user", content: text) }
    static func assistant(_ text: String) -> PAIChatMessage { .init(role: "assistant", content: text) }
    static func system(_ text: String) -> PAIChatMessage { .init(role: "system", content: text) }
}
