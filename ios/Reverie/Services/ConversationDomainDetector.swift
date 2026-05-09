// ConversationDomainDetector.swift
// iAlly
//
// On-device, synchronous domain detection for every Lumina message.
// Drives which prompt layers are injected — no extra API call, ~1ms overhead.
//
// Detection pipeline (8 steps):
//   1. Short-circuit: pending proposal + confirmation word
//   2. Short-circuit: pure query (no markers needed)
//   3. Negation guard (suppress negated action signals)
//   4. Article + pronoun signals (CREATE vs MODIFY disambiguation)
//   5. Action verb scoring
//   6. "Complete" ambiguity resolution
//   7. Compound intent accumulation
//   8. Confidence scoring

import Foundation

// MARK: - Domain Types

/// Which rule blocks the system prompt builder should inject for this message.
enum ConversationDomain: String, CaseIterable {
    // CREATE — emit proposal markers
    case taskCreate
    case routineCreate
    case journeyCreate
    case planCreate
    case milestoneCreate

    // MODIFY — emit CRUD markers (item must exist in real-time data)
    case taskModify
    case routineModify
    case planModify
    case journeyModify
    case milestoneModify

    // Meta — no markers needed
    case query            // "what tasks do I have?" — show data only
    case confirmPending   // "yes / ok / confirm" after a proposal card
    case general          // fallback: conversational, no action
}

enum DetectionConfidence {
    case high    // rawScore >= 0.75 — inject full rules for matched domains
    case medium  // rawScore 0.45–0.74 — inject matched rules, skip tier-2 profile
    case low     // rawScore < 0.45 — inject universal task+query fallback rules
}

struct DomainDetectionResult {
    let domains: Set<ConversationDomain>
    let confidence: DetectionConfidence
    let isQueryOnly: Bool            // true → skip Layer 3 and Layer 6
    let isPendingConfirmation: Bool  // true → skip Layer 3 and Layer 6
    let rawScore: Double

    /// Fallback used for the offline path — all domains, high confidence.
    static func fallback() -> DomainDetectionResult {
        DomainDetectionResult(
            domains: Set(ConversationDomain.allCases),
            confidence: .high,
            isQueryOnly: false,
            isPendingConfirmation: false,
            rawScore: 1.0
        )
    }

    /// Welcome message detection — show task + routine create rules only.
    static func welcome() -> DomainDetectionResult {
        DomainDetectionResult(
            domains: [.taskCreate, .routineCreate],
            confidence: .medium,
            isQueryOnly: false,
            isPendingConfirmation: false,
            rawScore: 0.6
        )
    }
}

// MARK: - Detector

struct ConversationDomainDetector {

    // MARK: Entry point

    /// Analyses `message` and returns which domains and prompt layers are needed.
    /// Runs synchronously in < 2ms. Call from `LuminaConversationService.send()` before
    /// building the system prompt array.
    ///
    /// - Parameters:
    ///   - message: The user's raw input (not yet trimmed by caller is fine).
    ///   - history: Last 4 non-info, non-offline-fallback LuminaMessages for pronoun resolution.
    ///   - hasPendingProposal: true if any pending*Proposal var in the service is non-nil.
    static func detect(
        message: String,
        history: [LuminaMessage],
        hasPendingProposal: Bool
    ) -> DomainDetectionResult {

        let raw = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return DomainDetectionResult(domains: [.general], confidence: .low,
                                         isQueryOnly: false, isPendingConfirmation: false,
                                         rawScore: 0.0)
        }

        let lower = raw.lowercased()
        let tokens = lower.components(separatedBy: .whitespaces)

        // ── Step 1: Short-circuit — pending proposal + confirmation ──────────────
        if hasPendingProposal && isConfirmation(lower) {
            return DomainDetectionResult(
                domains: [.confirmPending], confidence: .high,
                isQueryOnly: false, isPendingConfirmation: true, rawScore: 1.0
            )
        }

        // ── Step 2: Short-circuit — pure query ───────────────────────────────────
        if isPureQuery(lower, tokens: tokens) {
            return DomainDetectionResult(
                domains: [.query], confidence: .high,
                isQueryOnly: true, isPendingConfirmation: false, rawScore: 0.9
            )
        }

        // ── Step 3: Negation guard ────────────────────────────────────────────────
        let negatedRanges = negationRanges(in: tokens)

        // ── Step 4: Article signals ────────────────────────────────────────────────
        let articleBoost = articleSignalBoost(in: tokens)
        // > 0 → leans CREATE, < 0 → leans MODIFY

        // ── Step 5: Score all action verbs ────────────────────────────────────────
        var scores: [ConversationDomain: Double] = [:]
        for (domain, phrases) in verbTable {
            var score = 0.0
            for phrase in phrases {
                let words = phrase.components(separatedBy: " ")
                let weight: Double = words.count > 1 ? 0.35 : 0.25
                if lower.contains(phrase) {
                    // Check that the matched verb is not in a negated window
                    if !isNegated(phrase: phrase, in: tokens, negatedRanges: negatedRanges) {
                        score += weight
                    }
                }
            }
            if score > 0 {
                scores[domain] = score
            }
        }

        // ── Step 6: "Complete" ambiguity resolution ────────────────────────────────
        scores = resolveCompleteAmbiguity(lower: lower, tokens: tokens,
                                          scores: scores, history: history,
                                          hasPendingProposal: hasPendingProposal)

        // Apply article boost: strengthen or weaken CREATE vs MODIFY scores
        scores = applyArticleBoost(scores: scores, boost: articleBoost)

        // Apply pronoun resolution: "it" / "this" / "that" → infer from history
        scores = applyPronounResolution(lower: lower, scores: scores, history: history)

        // ── Step 7: Compound intent — collect all domains >= 0.25 ─────────────────
        let activeDomains = scores.filter { $0.value >= 0.25 }.keys
        var resultDomains = Set(activeDomains)

        // ── Step 8: Confidence ────────────────────────────────────────────────────
        var rawScore = scores.values.max() ?? 0.0

        // Boosts / penalties
        if articleBoost > 0 {
            let hasCreateDomains = resultDomains.contains(where: isCreateDomain)
            if hasCreateDomains { rawScore += 0.15 }
        } else if articleBoost < 0 {
            let hasModifyDomains = resultDomains.contains(where: isModifyDomain)
            if hasModifyDomains { rawScore += 0.15 }
        }

        // Pronoun resolution boost
        if hasPronoun(lower) && !history.isEmpty { rawScore += 0.10 }

        // Past-tense penalty (narration, not request)
        if hasPastTenseNarration(lower) { rawScore -= 0.20 }

        rawScore = min(1.0, max(0.0, rawScore))

        // Low confidence fallback
        if resultDomains.isEmpty || rawScore < 0.25 {
            resultDomains = [.taskCreate]
            rawScore = 0.3
        }

        let confidence: DetectionConfidence
        switch rawScore {
        case 0.75...: confidence = .high
        case 0.45..<0.75: confidence = .medium
        default: confidence = .low
        }

        // Low confidence → expand to universal task+query fallback
        if confidence == .low {
            resultDomains.insert(.taskCreate)
            resultDomains.insert(.taskModify)
        }

        return DomainDetectionResult(
            domains: resultDomains,
            confidence: confidence,
            isQueryOnly: false,
            isPendingConfirmation: false,
            rawScore: rawScore
        )
    }

    // MARK: - Step 1: Confirmation detection

    private static let confirmationWords: [String] = [
        "yes", "confirm", "ok", "okay", "do it", "go ahead", "sure", "yep",
        "create it", "save it", "add it", "proceed", "sounds good", "that's right",
        "correct", "affirmative", "definitely", "absolutely", "please do",
        "go for it", "let's do it"
    ]

    private static func isConfirmation(_ lower: String) -> Bool {
        let trimmed = lower.trimmingCharacters(in: .punctuationCharacters)
        return confirmationWords.contains(where: { trimmed == $0 || trimmed.hasPrefix($0 + " ") })
    }

    // MARK: - Step 2: Pure query detection

    private static let queryPhrases: [String] = [
        "what tasks", "what do i have", "show me", "list my", "how many",
        "tell me about", "do i have", "give me a summary", "any tasks",
        "what's on", "what is on", "remind me what", "how am i doing",
        "what are my", "can you show", "display my", "what plans",
        "what journeys", "which tasks", "when is", "what routines"
    ]

    private static let actionVerbs: [String] = [
        "create", "add", "make", "schedule", "remind", "delete", "remove",
        "complete", "finish", "update", "rename", "reschedule", "cancel"
    ]

    private static func isPureQuery(_ lower: String, tokens: [String]) -> Bool {
        let hasQuery = queryPhrases.contains { lower.contains($0) }
        guard hasQuery else { return false }
        // Ensure no action verb overrides the query
        let hasAction = actionVerbs.contains { lower.contains($0) }
        return !hasAction
    }

    // MARK: - Step 3: Negation guard

    private static let negationTokens: [String] = [
        "don't", "dont", "do not", "didn't", "didn't", "never",
        "no need to", "forget it", "cancel that", "not", "stop",
        "without", "shouldn't", "shouldnt", "won't", "wont"
    ]

    private static func negationRanges(in tokens: [String]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for (i, token) in tokens.enumerated() {
            let cleaned = token.trimmingCharacters(in: .punctuationCharacters)
            if negationTokens.contains(cleaned) {
                let end = min(i + 5, tokens.count)
                ranges.append(i..<end)
            }
        }
        return ranges
    }

    private static func isNegated(phrase: String, in tokens: [String],
                                   negatedRanges: [Range<Int>]) -> Bool {
        guard !negatedRanges.isEmpty else { return false }
        let phraseWords = phrase.components(separatedBy: " ")
        // Find where this phrase appears in the token array
        for startIdx in 0...(max(0, tokens.count - phraseWords.count)) {
            let window = tokens[startIdx..<min(startIdx + phraseWords.count, tokens.count)]
            if Array(window).map({ $0.trimmingCharacters(in: .punctuationCharacters) }) == phraseWords {
                return negatedRanges.contains { $0.contains(startIdx) }
            }
        }
        return false
    }

    // MARK: - Step 4: Article signals

    private static let createArticles: Set<String> = ["a", "an", "new", "another", "one"]
    private static let modifyArticles: Set<String> = ["the", "my", "this", "that", "those", "these", "it"]

    private static let itemNouns: Set<String> = [
        "task", "routine", "journey", "plan", "milestone", "habit",
        "goal", "project", "checkpoint", "reminder", "to-do", "todo"
    ]

    /// Returns > 0 if CREATE signal, < 0 if MODIFY signal, 0 if neutral.
    private static func articleSignalBoost(in tokens: [String]) -> Double {
        var createSignals = 0
        var modifySignals = 0
        for (i, token) in tokens.enumerated() {
            let cleaned = token.trimmingCharacters(in: .punctuationCharacters)
            guard i + 1 < tokens.count else { continue }
            let nextToken = tokens[i + 1].trimmingCharacters(in: .punctuationCharacters)
            guard itemNouns.contains(nextToken) else { continue }
            if createArticles.contains(cleaned) { createSignals += 1 }
            if modifyArticles.contains(cleaned) { modifySignals += 1 }
        }
        if createSignals > modifySignals { return 0.3 }
        if modifySignals > createSignals { return -0.3 }
        return 0.0
    }

    // MARK: - Step 5: Verb scoring table

    private static let verbTable: [ConversationDomain: [String]] = [
        // ── CREATE ──
        .taskCreate: [
            "add a task", "create a task", "new task", "remind me to", "remind me about",
            "schedule a", "set up a task", "make a task", "put a task", "log a task",
            "add an item", "make a reminder", "create a reminder", "add a reminder",
            "i need to", "i want to", "don't forget to", "can you add", "please add",
            "add", "create", "remind", "schedule", "put", "need to"
        ],
        .routineCreate: [
            "start a routine", "create a routine", "new routine", "set up a routine",
            "add a routine", "make a habit", "start a habit", "new habit",
            "every day", "every morning", "every evening", "every week", "every monday",
            "daily habit", "weekly habit", "recurring task", "do this daily",
            "routine", "habit", "recurring"
        ],
        .journeyCreate: [
            "start a journey", "create a journey", "new journey", "begin a journey",
            "long-term goal", "life goal", "set a goal", "big goal",
            "months-long", "work toward over", "embark on", "vision for",
            "i want to achieve", "i aspire to", "journey", "life mission"
        ],
        .planCreate: [
            "create a plan", "start a plan", "new plan", "make a plan",
            "create a project", "new project", "start a project", "set up a project",
            "roadmap", "strategy", "action plan", "project plan",
            "plan", "project", "strategy"
        ],
        .milestoneCreate: [
            "add a milestone", "create a milestone", "new milestone",
            "checkpoint for", "step toward", "mark a step", "add a checkpoint",
            "milestone", "checkpoint"
        ],

        // ── MODIFY ──
        .taskModify: [
            "mark done", "mark as done", "mark complete", "mark as complete",
            "check off", "complete the task", "finish the task", "done with",
            "reschedule", "move to tomorrow", "change the date", "change the time",
            "update the task", "rename the task", "edit the task",
            "delete the task", "remove the task", "cancel the task",
            "task is done", "i finished", "i completed", "i did"
        ],
        .routineModify: [
            "stop the routine", "delete the routine", "cancel the routine",
            "end the routine", "remove the routine", "stop my routine",
            "delete my routine", "cancel my routine"
        ],
        .planModify: [
            "finish the plan", "complete the plan", "done with the plan",
            "delete the plan", "remove the plan", "abandon the plan",
            "wrap up the plan", "close the plan", "plan is done"
        ],
        .journeyModify: [
            "complete the journey", "finish the journey", "done with the journey",
            "delete the journey", "remove the journey", "abandon the journey",
            "close the journey", "journey is done", "complete my journey",
            "finish my journey", "delete my journey"
        ],
        .milestoneModify: [
            "complete the milestone", "mark milestone done", "finish the milestone",
            "delete the milestone", "remove the milestone", "milestone is done",
            "complete this milestone"
        ],

        // ── QUERY ──
        .query: [
            "what tasks", "what do i have", "show me my", "list my", "how many tasks",
            "tell me about", "do i have any", "give me a summary", "what's on my list",
            "remind me what", "how am i doing", "what are my tasks", "what plans",
            "what journeys", "what routines", "any overdue"
        ]
    ]

    // MARK: - Step 6: "Complete" ambiguity resolution

    private static let pastTensePatterns: [String] = [
        "i completed", "i've completed", "i finished", "i've finished",
        "i wrapped up", "i did", "i've done", "already done", "already finished",
        "just completed", "just finished", "just did", "i accomplished"
    ]

    private static let completeVerbs: [String] = [
        "complete", "finish", "wrap up", "mark done", "mark as done", "close out"
    ]

    private static func resolveCompleteAmbiguity(
        lower: String,
        tokens: [String],
        scores: [ConversationDomain: Double],
        history: [LuminaMessage],
        hasPendingProposal: Bool
    ) -> [ConversationDomain: Double] {

        var updated = scores

        // Check if "complete" or synonyms are the dominant signal
        let hasCompleteVerb = completeVerbs.contains { lower.contains($0) }
        guard hasCompleteVerb else { return updated }

        // Step 6.1: Past tense narration → not a MODIFY request
        if pastTensePatterns.contains(where: { lower.contains($0) }) {
            updated.removeValue(forKey: .taskModify)
            updated.removeValue(forKey: .planModify)
            updated.removeValue(forKey: .journeyModify)
            updated.removeValue(forKey: .milestoneModify)
            updated[.query] = max(updated[.query] ?? 0, 0.3)
            return updated
        }

        // Step 6.2: Look at the noun phrase after the complete verb
        let itemNounHints: [(nouns: [String], domain: ConversationDomain)] = [
            (["task", "item", "to-do", "todo", "reminder"], .taskModify),
            (["plan", "project", "strategy"], .planModify),
            (["journey", "goal", "long-term goal", "mission"], .journeyModify),
            (["milestone", "checkpoint", "step", "phase"], .milestoneModify)
        ]

        for (i, token) in tokens.enumerated() {
            let cleaned = token.trimmingCharacters(in: .punctuationCharacters)
            guard completeVerbs.contains(cleaned) else { continue }

            // Scan up to 6 tokens after the verb
            let scanEnd = min(i + 7, tokens.count)
            let scanTokens = tokens[i..<scanEnd].map {
                $0.trimmingCharacters(in: .punctuationCharacters)
            }
            let scanPhrase = scanTokens.joined(separator: " ")

            for hint in itemNounHints {
                if hint.nouns.contains(where: { scanPhrase.contains($0) }) {
                    // Boost the matched MODIFY domain, remove unrelated ones
                    updated[hint.domain] = max(updated[hint.domain] ?? 0, 0.6)
                    // Suppress other MODIFY domains unless they also matched independently
                    for domain in [ConversationDomain.taskModify, .planModify,
                                   .journeyModify, .milestoneModify] {
                        if domain != hint.domain && (updated[domain] ?? 0) < 0.35 {
                            updated.removeValue(forKey: domain)
                        }
                    }
                    return updated
                }
            }
        }

        // Step 6.3: History-based pronoun resolution when noun is unclear
        if let inferredDomain = lastMentionedModifyDomain(in: history) {
            updated[inferredDomain] = max(updated[inferredDomain] ?? 0, 0.5)
        }

        return updated
    }

    // MARK: - Article boost application

    private static func applyArticleBoost(
        scores: [ConversationDomain: Double],
        boost: Double
    ) -> [ConversationDomain: Double] {
        guard boost != 0 else { return scores }
        var updated = scores
        if boost > 0 {
            // Boost CREATE domains, penalise MODIFY
            for domain in scores.keys where isCreateDomain(domain) {
                updated[domain] = (updated[domain] ?? 0) + 0.15
            }
            for domain in scores.keys where isModifyDomain(domain) {
                let current = updated[domain] ?? 0
                if current - 0.15 < 0.25 { updated.removeValue(forKey: domain) }
                else { updated[domain] = current - 0.15 }
            }
        } else {
            // Boost MODIFY domains, penalise CREATE
            for domain in scores.keys where isModifyDomain(domain) {
                updated[domain] = (updated[domain] ?? 0) + 0.15
            }
            for domain in scores.keys where isCreateDomain(domain) {
                let current = updated[domain] ?? 0
                if current - 0.15 < 0.25 { updated.removeValue(forKey: domain) }
                else { updated[domain] = current - 0.15 }
            }
        }
        return updated
    }

    // MARK: - Pronoun resolution

    private static let pronouns: Set<String> = ["it", "this", "that", "same one", "those"]

    private static func hasPronoun(_ lower: String) -> Bool {
        pronouns.contains { lower.contains(" \($0) ") || lower.hasSuffix(" \($0)") }
    }

    private static func applyPronounResolution(
        lower: String,
        scores: [ConversationDomain: Double],
        history: [LuminaMessage]
    ) -> [ConversationDomain: Double] {
        guard hasPronoun(lower), !history.isEmpty else { return scores }
        guard let inferredDomain = lastMentionedModifyDomain(in: history) else { return scores }
        var updated = scores
        updated[inferredDomain] = max(updated[inferredDomain] ?? 0, 0.5)
        return updated
    }

    /// Scans the last 2 assistant messages for the most recently named item type
    /// and returns the corresponding MODIFY domain.
    private static func lastMentionedModifyDomain(in history: [LuminaMessage]) -> ConversationDomain? {
        let recentAssistant = history
            .filter { $0.role == .assistant }
            .suffix(2)
            .reversed()

        let proposalPatterns: [(String, ConversationDomain)] = [
            ("JOURNEY_PROPOSAL", .journeyModify),
            ("PLAN_PROPOSAL", .planModify),
            ("MILESTONE_PROPOSAL", .milestoneModify),
            ("ROUTINE_PROPOSAL", .routineModify),
            ("TASK_PROPOSAL", .taskModify),
            ("journey", .journeyModify),
            ("plan", .planModify),
            ("milestone", .milestoneModify),
            ("routine", .routineModify),
            ("task", .taskModify)
        ]

        for message in recentAssistant {
            let content = message.content.lowercased()
            for (pattern, domain) in proposalPatterns {
                if content.contains(pattern.lowercased()) {
                    return domain
                }
            }
        }
        return nil
    }

    // MARK: - Past tense narration check

    private static func hasPastTenseNarration(_ lower: String) -> Bool {
        pastTensePatterns.contains { lower.contains($0) }
    }

    // MARK: - Domain classification helpers

    private static func isCreateDomain(_ domain: ConversationDomain) -> Bool {
        [.taskCreate, .routineCreate, .journeyCreate, .planCreate, .milestoneCreate].contains(domain)
    }

    private static func isModifyDomain(_ domain: ConversationDomain) -> Bool {
        [.taskModify, .routineModify, .planModify, .journeyModify, .milestoneModify].contains(domain)
    }
}
