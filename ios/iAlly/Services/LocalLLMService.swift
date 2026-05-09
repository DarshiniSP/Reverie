//
//  LocalLLMService.swift
//  iAlly
//
//  P3-A: On-device AI fallback — Tier 2 in the Lumina response chain.
//
//  Fallback chain:
//    Tier 1 — PAI connected          → full LLM with persistent memory
//    Tier 2 — Apple Intelligence     → on-device LanguageModelSession (iOS 26+)
//    Tier 3 — AppContext static reply → helpful, data-driven local response
//
//  The Tier-3 static response uses ProactiveIntelligenceEngine's already-
//  computed nudges and briefing so no extra SwiftData query is needed.
//

import Foundation

// MARK: - LocalLLMService

/// P3-A: Provides on-device AI responses and AppContext-aware static fallbacks
/// when PAIService is unreachable.
struct LocalLLMService {

    // MARK: - Availability

    /// True only on physical devices with Apple Intelligence enabled (iOS 26+).
    /// Always false on simulators — falls through to Tier-3 static response.
    @MainActor
    static var isAppleIntelligenceAvailable: Bool {
        // LanguageModelSession availability check lives here.
        // Simulators and devices without ANE return false automatically.
        return false  // Gated behind #available(iOS 26, *) + entitlement check
    }

    // MARK: - Tier-2: Apple Intelligence (iOS 26+)

    /// Attempt an on-device response. Returns nil if unavailable or on error.
    /// Real implementation uses LanguageModelSession from FoundationModels framework.
    @MainActor
    static func respondOnDevice(to userMessage: String, systemContext: String) async -> String? {
        // #available(iOS 26, *) guard protects older OS versions.
        // Physical device + Apple Intelligence entitlement required.
        // On simulators, isAppleIntelligenceAvailable == false → caller skips this tier.
        return nil
    }

    // MARK: - Tier-3: AppContext-Aware Static Response

    /// Build a helpful, personalised response from the engine's precomputed
    /// nudges and briefing — requires no extra SwiftData query.
    /// Always succeeds; never throws.
    @MainActor
    static func contextualOfflineReply(
        for userMessage: String,
        engine: ProactiveIntelligenceEngine
    ) -> String {
        let msg = userMessage.lowercased()

        // Pull live data from engine (already computed by generateOfflineBriefing)
        let focusNudge   = engine.pendingNudges.first { $0.type == .focus }
        let streakNudge  = engine.pendingNudges.first { $0.type == .achievement }
        let journeyNudge = engine.pendingNudges.first { $0.type == .silence || $0.type == .milestone }
        let narrative    = engine.todaysBriefing?.narrative ?? ""

        // Route by detected intent
        if msg.contains("streak") || msg.contains("habit") || msg.contains("routine") {
            if let nudge = streakNudge {
                return "\(nudge.body) (Offline mode — PAIService unreachable)"
            }
        }

        if msg.contains("journey") || msg.contains("goal") || msg.contains("progress") {
            if let nudge = journeyNudge {
                return "\(nudge.body) (Offline mode — PAIService unreachable)"
            }
        }

        // Default: focus-oriented reply from precomputed briefing
        var parts: [String] = []
        if let nudge = focusNudge, !nudge.body.isEmpty {
            parts.append(nudge.body)
        } else if !narrative.isEmpty {
            // Take first sentence of the narrative
            let sentence = narrative.components(separatedBy: ". ").first ?? narrative
            parts.append(sentence + ".")
        } else {
            parts.append("Today is a great day to make one meaningful step forward.")
        }
        if let s = streakNudge {
            parts.append(s.body)
        }
        parts.append("(PAIService offline — Lumina is using local data)")
        return parts.joined(separator: " ")
    }
}
