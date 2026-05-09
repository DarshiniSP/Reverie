//
//  LifeDomainInferenceService.swift
//  iAlly
//
//  Extends LifeDomain with an AI-powered classification helper.
//  Uses LuminaInferenceRouter for cloud classification when local keywords miss.
//
//  P1-C: Added inferLocally() — keyword-based, always available offline.
//        infer() now tries local first; only calls AI when local draws a blank.
//

import Foundation

extension LifeDomain {

    // MARK: - P1-C: Local Keyword Inference (no network, instant)

    /// Keyword-based domain classifier. Runs instantly on any device without network.
    /// Returns `nil` only when no keyword matches (caller can fall through to AI).
    static func inferLocally(from text: String) -> LifeDomain? {
        let lower = text.lowercased()

        // Maps: domain → keywords that strongly suggest it.
        // Ordered from most-specific to least — first match wins.
        let rules: [(domain: LifeDomain, keywords: [String])] = [
            (.health, [
                "workout", "exercise", "run", "running", "gym", "yoga", "meditation",
                "sleep", "diet", "meal", "eat", "nutrition", "doctor", "dentist",
                "appointment", "prescription", "medicine", "health", "fitness",
                "steps", "weight", "calories", "hydrate", "water", "stretch",
                "physiotherapy", "therapy", "mental health"
            ]),
            (.finance, [
                "budget", "pay", "payment", "invoice", "tax", "expense", "saving",
                "invest", "investment", "bank", "account", "bill", "salary",
                "money", "cost", "finance", "financial", "debt", "loan", "mortgage",
                "credit", "insurance", "pension", "retirement", "spend", "spending"
            ]),
            (.career, [
                "meeting", "project", "client", "report", "presentation",
                "deadline", "work", "job", "career", "office", "email",
                "interview", "resume", "cv", "promotion", "review", "performance",
                "manager", "team", "colleague", "conference", "standup", "sprint",
                "deploy", "code", "develop", "ship", "launch", "proposal", "contract"
            ]),
            (.learning, [
                "read", "reading", "book", "course", "study", "learn", "research",
                "article", "tutorial", "lecture", "class", "certificate",
                "skill", "practice", "note", "notes", "review", "quiz", "exam",
                "language", "podcast", "video", "training", "workshop", "seminar"
            ]),
            (.relationships, [
                "call", "catch up", "birthday", "anniversary", "friend",
                "family", "partner", "date", "dinner", "coffee", "visit",
                "gift", "thank you", "letter", "message", "reach out",
                "parents", "kids", "children", "spouse", "sibling", "network"
            ]),
            (.creativity, [
                "write", "writing", "draw", "design", "art", "music",
                "play", "creative", "brainstorm", "idea", "story", "blog",
                "photo", "video", "edit", "compose", "paint", "sketch",
                "prototype", "build", "make", "craft", "create"
            ]),
            (.home, [
                "clean", "cleaning", "tidy", "laundry", "grocery", "groceries",
                "cook", "cooking", "repair", "fix", "home", "house", "garden",
                "plants", "furniture", "organize", "organise", "declutter",
                "maintenance", "plumber", "electrician", "shopping", "errands"
            ]),
            (.personal, [
                "goal", "habit", "journal", "reflect", "plan", "review",
                "self", "personal", "growth", "mindset", "vision", "mission",
                "values", "gratitude", "intention", "affirmation", "routine"
            ])
        ]

        for rule in rules {
            for keyword in rule.keywords {
                if lower.contains(keyword) {
                    return rule.domain
                }
            }
        }
        return nil
    }

    // MARK: - Primary Inference (local-first, AI on miss)

    /// Infer the best-fitting life domain from a free-text title.
    ///
    /// Strategy:
    ///   1. Try keyword-based local inference (instant, works offline) → P1-C
    ///   2. Fall back to AI classification only if local draws a blank AND provider is configured
    static func infer(from title: String) async -> LifeDomain? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 4 else { return nil }

        // 1. Local keyword inference — fast path
        if let local = inferLocally(from: trimmed) {
            return local
        }

        // 2. AI fallback — only when a provider is configured and local drew a blank
        guard LuminaInferenceRouter.shared.isActiveProviderConfigured else { return nil }

        let options = LifeDomain.allCases
            .map { $0.rawValue.lowercased() }
            .joined(separator: ", ")

        let systemPrompt = """
        Classify the following title into exactly one life domain.
        Available domains: \(options)
        Reply with ONLY the single domain word in lowercase (e.g. "health"). Nothing else.
        """

        let msgs = [
            PAIChatMessage(role: "system", content: systemPrompt),
            PAIChatMessage(role: "user", content: trimmed)
        ]

        guard let content = try? await LuminaInferenceRouter.shared.generate(messages: msgs) else {
            return nil
        }
        let raw = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return LifeDomain(rawValue: raw.capitalized)
    }
}
