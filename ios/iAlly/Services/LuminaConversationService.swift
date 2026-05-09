//
//  LuminaConversationService.swift
//  iAlly
//
//  Phase 2: Capture & Knowledge Layer
//  Manages the Lumina conversational session — message history, streaming
//  state, and PAI episodic memory recording.
//
//  GAP 3: Conversations are now persisted to SwiftData (LuminaSession /
//  PersistedLuminaMessage) so history survives app restarts.
//

import Foundation
import Observation
import SwiftData

// MARK: - Message model

struct LuminaMessage: Identifiable, Equatable {
    let id = UUID()
    let role: LuminaRole
    var content: String
    let timestamp = Date()
    /// True when this message came from the local offline fallback (Tier 2/3), NOT from the
    /// live inference provider.  These messages are shown in the chat UI but are EXCLUDED from
    /// the history array sent to the model — prevents generic offline placeholders like
    /// "Your slate is clear…" from polluting subsequent inference calls.
    var isOfflineFallback: Bool = false

    static func == (lhs: LuminaMessage, rhs: LuminaMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}

enum LuminaRole: String {
    case user = "user"
    case assistant = "assistant"
    /// Local acknowledgment only — never persisted to SwiftData, never sent to the model.
    case info = "info"
}

// MARK: - Service

@Observable
@MainActor
final class LuminaConversationService {

    static let shared = LuminaConversationService()
    private init() {}

    // MARK: State
    var messages: [LuminaMessage] = []
    var isTyping = false
    var sessionID: String = UUID().uuidString
    var lastError: String?

    /// Set this to pre-fill the Lumina input field (e.g. when promoting a Quick Note).
    /// LuminaView observes this and clears it after consuming.
    var pendingInput: String? = nil

    // GAP 3: SwiftData context injected from LuminaView via loadMostRecentSession(context:)
    var modelContext: ModelContext?

    // PAIService removed for beta — all memory is local-only

    // MARK: - GAP 3: Session persistence

    /// Load the most recent persisted conversation into memory.
    /// Call this from LuminaView's .task before sendWelcomeIfNeeded().
    func loadMostRecentSession(context: ModelContext) {
        self.modelContext = context
        guard messages.isEmpty else { return }  // Already loaded (e.g. second .task call)

        var descriptor = FetchDescriptor<LuminaSession>(
            sortBy: [SortDescriptor(\.lastMessageAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard
            let session = (try? context.fetch(descriptor))?.first,
            let msgs = session.messages, !msgs.isEmpty
        else { return }

        // Restore in-memory state from the most recent persisted session
        sessionID = session.sessionID
        messages = msgs
            .sorted { $0.timestamp < $1.timestamp }
            .map { LuminaMessage(role: LuminaRole(rawValue: $0.role) ?? .user, content: $0.content) }
    }

    /// Persist a single message to the current LuminaSession in SwiftData.
    private func persistMessage(role: String, content: String) {
        guard let ctx = modelContext else { return }
        let sid = sessionID

        // Find or create the session record for this sessionID
        let descriptor = FetchDescriptor<LuminaSession>(
            predicate: #Predicate { $0.sessionID == sid }
        )
        let session: LuminaSession
        if let existing = (try? ctx.fetch(descriptor))?.first {
            session = existing
        } else {
            session = LuminaSession(sessionID: sid)
            ctx.insert(session)
        }
        session.lastMessageAt = Date()

        // Auto-title from the first user message
        if session.title == "Conversation", role == "user" {
            session.title = String(content.prefix(40))
        }

        let msg = PersistedLuminaMessage(role: role, content: content)
        msg.session = session
        ctx.insert(msg)
        try? ctx.save()
    }

    // MARK: - Public API

    /// Send a user message and stream Lumina's reply back into `messages`.
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Append and persist user bubble
        messages.append(LuminaMessage(role: .user, content: trimmed))
        persistMessage(role: "user", content: trimmed)
        PAIMemoryBridge.shared.recordConversationMessage(trimmed, role: "user", sessionID: sessionID)

        isTyping = true
        lastError = nil

        // ── Domain detection (synchronous, ~1ms) ─────────────────────────────────
        // Uses the last 4 non-info, non-offline messages for pronoun resolution.
        let recentHistory = messages.filter { !$0.isOfflineFallback && $0.role != .info }.suffix(4)
        let hasPending = pendingTaskProposal         != nil
                      || pendingRoutineProposal       != nil
                      || pendingJourneyProposal        != nil
                      || pendingPlanProposal           != nil
                      || pendingMilestoneProposal      != nil
                      || pendingTaskCompleteProposal   != nil
                      || pendingTaskUpdateProposal     != nil
                      || pendingTaskDeleteProposal     != nil
                      || pendingRoutineDeleteProposal  != nil
                      || pendingPlanDeleteProposal     != nil
                      || pendingPlanCompleteProposal   != nil
                      || pendingJourneyDeleteProposal  != nil
                      || pendingJourneyCompleteProposal != nil
                      || pendingMilestoneDeleteProposal != nil
                      || pendingMilestoneCompleteProposal != nil
        let detection = ConversationDomainDetector.detect(
            message: trimmed,
            history: Array(recentHistory),
            hasPendingProposal: hasPending
        )

        // ── Date / time context ───────────────────────────────────────────────────
        let dateFmt = ISO8601DateFormatter()
        dateFmt.formatOptions = [.withFullDate]
        let todayISO = dateFmt.string(from: Date())
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"
        let currentTime = timeFmt.string(from: Date())
        let tzLabel = TimeZone.current.abbreviation() ?? TimeZone.current.identifier

        // ── App context (real-time SwiftData snapshot) ────────────────────────────
        let appContext = buildAppContext()

        // ── Memory fetch (local only) ───────────────────────────────────────────
        let localResults = LocalMemoryService.shared.search(query: trimmed, limit: 6)
        let memoryLines = localResults.map { "- \($0.content)" }

        // ── Tier 2 auto-derived context ────────────────────────────────────────
        let tier2Context = buildTier2Context(for: detection.domains)

        // ── Assemble system prompt via tiered builder ─────────────────────────────
        let systemMessages = LuminaSystemPromptBuilder.build(.init(
            detection:   detection,
            profile:     UserProfile.current,
            tier2Context: tier2Context,
            appContext:  appContext,
            memories:    Array(memoryLines.prefix(6)),
            todayISO:    todayISO,
            currentTime: currentTime,
            tzLabel:     tzLabel
        ))

        // Build full history for the model.
        // Cap to the last 10 sendable messages (5 exchanges) so old responses
        // don't pollute the context.
        // Exclude:
        //   • .info messages  — local-only acknowledgments, never sent to model
        //   • .isOfflineFallback — generic Tier 2/3 offline responses ("Your slate is clear…")
        //     These are shown in the chat UI but should NOT go to the provider because they
        //     are not real model responses and will confuse subsequent inference calls.
        let recentMessages = messages.filter { !$0.isOfflineFallback && $0.role != .info }.suffix(10)
        let history: [PAIChatMessage] = systemMessages + recentMessages.map { msg in
            // Scrub PII from user messages before they leave the device.
            // Assistant messages are not scrubbed (they originate from the model, not the user).
            let content = msg.role == .user
                ? PIIScrubber.shared.scrub(msg.content).scrubbed
                : msg.content
            return PAIChatMessage(role: msg.role.rawValue, content: content)
        }

        // Reserve assistant bubble slot
        var assistantMsg = LuminaMessage(role: .assistant, content: "")
        messages.append(assistantMsg)
        let assistantIdx = messages.count - 1

        // --- Inference logging setup (captured before do/catch so both branches can use them) ---
        let logStart      = Date()
        let logProvider   = "\(LuminaInferenceRouter.shared.selectedProviderID.displayName) · \(LuminaInferenceRouter.shared.selectedProviderID.modelName)"
        let logUserMsg    = history.last(where: { $0.role == "user" })?.content ?? trimmed

        do {
            // Route directly to the user-selected inference provider (Claude / OpenAI / Gemini / Mercury).
            // PAIService is no longer on the critical inference path — it handles memory only.
            for try await chunk in LuminaInferenceRouter.shared.stream(messages: history) {
                guard !chunk.isEmpty else { continue }
                assistantMsg.content += chunk
                messages[assistantIdx] = assistantMsg
            }

            // Parse for agent action markers before persisting.
            // Save raw content first — routine parser needs the original before stripping.
            let rawContent = assistantMsg.content

            // --- Log successful call ---
            InferenceLogger.shared.add(InferenceLog(
                timestamp:  logStart,
                provider:   logProvider,
                userMsg:    logUserMsg,
                payload:    history,
                response:   rawContent,
                durationMs: Int(Date().timeIntervalSince(logStart) * 1000),
                error:      nil
            ))
            let (cleanContent, taskProposal) = parseAgentAction(from: rawContent)
            if cleanContent != rawContent {
                assistantMsg.content = cleanContent
                messages[assistantIdx] = assistantMsg
            }

            // Parse all proposal types. Priority (high→low): journey > plan > milestone >
            // routine > task_complete > task_update > task_delete > task_create
            // Parse all CRUD proposal types from the raw (pre-strip) response.
            // MODIFY proposals (delete/complete) take priority over CREATE proposals.
            let journeyDeleteProposal    = parseJourneyDeleteProposal(from: rawContent)
            let journeyCompleteProposal  = parseJourneyCompleteProposal(from: rawContent)
            let planDeleteProposal       = parsePlanDeleteProposal(from: rawContent)
            let planCompleteProposal     = parsePlanCompleteProposal(from: rawContent)
            let milestoneDeleteProposal  = parseMilestoneDeleteProposal(from: rawContent)
            let milestoneCompleteProposal = parseMilestoneCompleteProposal(from: rawContent)
            let routineDeleteProposal    = parseRoutineDeleteProposal(from: rawContent)
            let completeProposal         = parseTaskCompleteProposal(from: rawContent)
            let updateProposal           = parseTaskUpdateProposal(from: rawContent)
            let deleteProposal           = parseTaskDeleteProposal(from: rawContent)
            let journeyProposal          = parseJourneyProposal(from: rawContent)
            let planProposal             = parsePlanProposal(from: rawContent)
            let milestoneProposal        = parseMilestoneProposal(from: rawContent)
            let routineProposal          = parseRoutineProposal(from: rawContent)

            // Clear all pending — exactly one will be set below
            pendingJourneyDeleteProposal    = nil
            pendingJourneyCompleteProposal  = nil
            pendingPlanDeleteProposal       = nil
            pendingPlanCompleteProposal     = nil
            pendingMilestoneDeleteProposal  = nil
            pendingMilestoneCompleteProposal = nil
            pendingJourneyProposal          = nil
            pendingPlanProposal             = nil
            pendingMilestoneProposal        = nil
            pendingRoutineProposal          = nil
            pendingRoutineDeleteProposal    = nil
            pendingTaskCompleteProposal     = nil
            pendingTaskUpdateProposal       = nil
            pendingTaskDeleteProposal       = nil
            pendingTaskProposal             = nil

            // Priority: MODIFY (delete/complete) → CREATE
            if let p = journeyDeleteProposal         { pendingJourneyDeleteProposal    = p
            } else if let p = journeyCompleteProposal { pendingJourneyCompleteProposal = p
            } else if let p = planDeleteProposal     { pendingPlanDeleteProposal       = p
            } else if let p = planCompleteProposal   { pendingPlanCompleteProposal     = p
            } else if let p = milestoneDeleteProposal  { pendingMilestoneDeleteProposal  = p
            } else if let p = milestoneCompleteProposal { pendingMilestoneCompleteProposal = p
            } else if let p = routineDeleteProposal  { pendingRoutineDeleteProposal    = p
            } else if let p = completeProposal       { pendingTaskCompleteProposal     = p
            } else if let p = updateProposal         { pendingTaskUpdateProposal       = p
            } else if let p = deleteProposal         { pendingTaskDeleteProposal       = p
            } else if let p = journeyProposal        { pendingJourneyProposal          = p
            } else if let p = planProposal           { pendingPlanProposal             = p
            } else if let p = milestoneProposal      { pendingMilestoneProposal        = p
            } else if let p = routineProposal        { pendingRoutineProposal          = p
            } else                                   { pendingTaskProposal             = taskProposal
            }

            // Response-side interpretation fallback ─────────────────────────────────────
            // If the provider responded with natural-language creation text but did NOT
            // output a [TASK_PROPOSAL:] marker (Mercury's common failure mode), extract the
            // task title and due date from the response and synthesise a proposal so the
            // confirm-card still appears.  The displayed message is replaced with proper
            // Lumina wording ("Here's what I'll create — please confirm below.").
            if pendingTaskProposal             == nil,
               pendingRoutineProposal          == nil,
               pendingRoutineDeleteProposal    == nil,
               pendingJourneyProposal          == nil,
               pendingJourneyDeleteProposal    == nil,
               pendingJourneyCompleteProposal  == nil,
               pendingPlanProposal             == nil,
               pendingPlanDeleteProposal       == nil,
               pendingPlanCompleteProposal     == nil,
               pendingMilestoneProposal        == nil,
               pendingMilestoneDeleteProposal  == nil,
               pendingMilestoneCompleteProposal == nil,
               pendingTaskCompleteProposal     == nil,
               pendingTaskUpdateProposal       == nil,
               pendingTaskDeleteProposal       == nil,
               let extracted = extractTaskFromCreationResponse(rawContent) {
                pendingTaskProposal = extracted
                assistantMsg.content = "Here's what I'll create — please confirm below."
                messages[assistantIdx] = assistantMsg
            }
            // ─────────────────────────────────────────────────────────────────────────────

            // Persist final assistant message
            persistMessage(role: "assistant", content: assistantMsg.content)
            PAIMemoryBridge.shared.recordConversationMessage(
                assistantMsg.content, role: "assistant", sessionID: sessionID
            )
        } catch {
            // --- Log failed call ---
            InferenceLogger.shared.add(InferenceLog(
                timestamp:  logStart,
                provider:   logProvider,
                userMsg:    logUserMsg,
                payload:    history,
                response:   "",
                durationMs: Int(Date().timeIntervalSince(logStart) * 1000),
                error:      error.localizedDescription
            ))

            // Fallback chain when the direct provider call fails.
            // Tier 1 (direct provider) failed — try on-device intelligence before giving up.
            var offlineReply: String? = nil
            // Tier 2: Apple Intelligence on-device (iOS 26+, physical device only).
            if LocalLLMService.isAppleIntelligenceAvailable {
                // Use the already-computed detection so Apple Intelligence receives
                // only the domains relevant to this message (no extra API call).
                let offlineContext = LuminaSystemPromptBuilder.build(.init(
                    detection:   detection,
                    profile:     UserProfile.current,
                    tier2Context: tier2Context,
                    appContext:  appContext,
                    memories:    [],
                    todayISO:    todayISO,
                    currentTime: currentTime,
                    tzLabel:     tzLabel
                )).map(\.content).joined(separator: "\n\n")
                offlineReply = await LocalLLMService.respondOnDevice(
                    to: trimmed,
                    systemContext: offlineContext
                )
            }
            if let reply = offlineReply {
                // Tier 2 succeeded — show reply, no error banner.
                var tier2Msg = LuminaMessage(role: .assistant, content: reply)
                tier2Msg.isOfflineFallback = true  // Exclude from next inference call's history
                messages[assistantIdx] = tier2Msg
                persistMessage(role: "assistant", content: reply)
                lastError = nil
            } else {
                // Tier 3: AppContext-aware static response.
                let reply = LocalLLMService.contextualOfflineReply(
                    for: trimmed,
                    engine: ProactiveIntelligenceEngine.shared
                )
                var tier3Msg = LuminaMessage(role: .assistant, content: reply)
                tier3Msg.isOfflineFallback = true  // Exclude from next inference call's history
                messages[assistantIdx] = tier3Msg
                persistMessage(role: "assistant", content: reply)
                lastError = error.localizedDescription
            }
        }

        isTyping = false
    }

    // MARK: - Auto-Milestone Generation

    /// After a Journey is created, makes a one-shot inference call (NOT added to chat history)
    /// asking the model to produce a set of logical, time-spaced milestones.
    /// Returns the created milestone titles for use in the UI ack.
    @MainActor
    func generateMilestones(for journey: Journey, modelContext: ModelContext) async -> [String] {
        let router = LuminaInferenceRouter.shared
        guard router.isConfigured(router.selectedProviderID) else { return [] }

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium; dateFmt.timeStyle = .none

        let targetStr = journey.targetDate.map { dateFmt.string(from: $0) } ?? "open-ended"
        let todayISO  = ISO8601DateFormatter().string(from: Date()).prefix(10)

        let systemMsg = PAIChatMessage(role: "system", content: """
            You are a goal-planning assistant. Respond ONLY with milestone lines — no prose, no greetings.
            Format (one per line): MILESTONE: title="...", target_date="YYYY-MM-DD"
            Generate 3–5 logical, achievable milestones that progress toward the journey goal.
            Space them evenly between today (\(todayISO)) and the target date (\(targetStr)).
            If the journey is open-ended, space milestones roughly 4–8 weeks apart.
            Milestones should be concrete, measurable, and build on each other.
            """)
        let userMsg = PAIChatMessage(role: "user", content: """
            Journey: \(journey.title)
            Vision: \(journey.vision ?? "")
            Domain: \(journey.lifeDomain.rawValue)
            Target date: \(targetStr)
            """)

        var rawResponse = ""
        do {
            for try await chunk in router.stream(messages: [systemMsg, userMsg]) {
                rawResponse += chunk
            }
        } catch {
#if DEBUG
            print("[generateMilestones] stream error: \(error)")
#endif
            return []
        }

        // Parse MILESTONE lines using regex to correctly handle commas inside titles.
        // Pattern: title="<any chars>", target_date="YYYY-MM-DD"
        // Splitting body by "," is fragile when titles contain commas — regex is robust.
        var created: [String] = []
        let lines = rawResponse.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Accept "MILESTONE:" with optional leading junk (e.g. numbered lists "1. MILESTONE:")
            guard let milestoneRange = trimmed.range(of: "MILESTONE:", options: .caseInsensitive) else { continue }
            let body = String(trimmed[milestoneRange.upperBound...])

            // Extract title="..." — regex handles commas inside the quoted value
            let mTitle = extractQuotedValue(key: "title", from: body) ?? ""
            guard !mTitle.isEmpty else { continue }

            // Extract target_date="YYYY-MM-DD"
            let mDateStr = extractQuotedValue(key: "target_date", from: body)

            let targetDate = mDateStr.flatMap { parseMarkerDate($0) }
            let milestone = Milestone(title: mTitle, targetDate: targetDate, order: created.count)
            milestone.journey = journey
            modelContext.insert(milestone)
            created.append(mTitle)
        }
        if !created.isEmpty { try? modelContext.save() }
        return created
    }

    /// Extracts the value from `key="value"` in a string using regex.
    /// Handles values that contain commas or other special chars.
    private func extractQuotedValue(key: String, from string: String) -> String? {
        // Pattern: key="<captured>" — greedy inside quotes
        let pattern = #"(?i)"# + NSRegularExpression.escapedPattern(for: key) + #"\s*=\s*"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: 1), in: string) else { return nil }
        let value = String(string[range]).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Show a warm welcome when the tab opens for the first time in a session.
    func sendWelcomeIfNeeded() async {
        guard messages.isEmpty else { return }

        isTyping = true

        // Build welcome prompt using the tiered builder with a fixed welcome detection
        // (taskCreate + routineCreate at medium confidence — enough for identity lock).
        let welcomeDateFmt = ISO8601DateFormatter()
        welcomeDateFmt.formatOptions = [.withFullDate]
        let welcomeTimeFmt = DateFormatter()
        welcomeTimeFmt.dateFormat = "HH:mm"
        let welcomeDetection = DomainDetectionResult.welcome()
        var promptMessages = LuminaSystemPromptBuilder.build(.init(
            detection:   welcomeDetection,
            profile:     UserProfile.current,
            tier2Context: buildTier2Context(for: welcomeDetection.domains),
            appContext:  buildAppContext(),
            memories:    [],
            todayISO:    welcomeDateFmt.string(from: Date()),
            currentTime: welcomeTimeFmt.string(from: Date()),
            tzLabel:     TimeZone.current.abbreviation() ?? TimeZone.current.identifier
        ))

        // Layer 4: additional identity lock — prevents model from self-introducing
        // as Mercury / Claude / GPT instead of as Lumina.
        promptMessages.append(PAIChatMessage(role: "system", content: """
            CRITICAL — IDENTITY OVERRIDE:
            You are Lumina. DO NOT say "I'm Mercury", "I'm Claude", "I'm GPT", or any
            model name. You are Lumina — the AI built into iAlly. Always refer to yourself
            only as Lumina when identity comes up. Never mention the underlying model.
            """))

        promptMessages.append(PAIChatMessage(
            role: "user",
            content: "Hello Lumina! I just opened our conversation. Please give me a brief, warm, personalised welcome (2–3 sentences). Be concise and encouraging."
        ))

        var welcomeMsg = LuminaMessage(role: .assistant, content: "")
        messages.append(welcomeMsg)
        let idx = messages.count - 1

        do {
            // Use the same direct-provider router used for chat turns.
            // PAIService is memory-only and must NOT be on the welcome path.
            for try await chunk in LuminaInferenceRouter.shared.stream(messages: promptMessages) {
                guard !chunk.isEmpty else { continue }
                welcomeMsg.content += chunk
                messages[idx] = welcomeMsg
            }
        } catch {
            messages[idx] = LuminaMessage(
                role: .assistant,
                content: "Hi! I'm Lumina, your personal second brain. How can I help you today?"
            )
        }

        // Persist welcome message
        persistMessage(role: "assistant", content: messages[idx].content)
        isTyping = false
    }

    /// Clear history and start a fresh session.
    func startNewSession() {
        messages = []
        sessionID = UUID().uuidString
        isTyping = false
        lastError = nil
        pendingTaskProposal      = nil
        pendingRoutineProposal   = nil
        pendingJourneyProposal   = nil
        pendingPlanProposal      = nil
        pendingMilestoneProposal = nil
        pendingTaskCompleteProposal      = nil
        pendingTaskUpdateProposal        = nil
        pendingTaskDeleteProposal        = nil
        pendingRoutineDeleteProposal     = nil
        pendingPlanDeleteProposal        = nil
        pendingPlanCompleteProposal      = nil
        pendingJourneyDeleteProposal     = nil
        pendingJourneyCompleteProposal   = nil
        pendingMilestoneDeleteProposal   = nil
        pendingMilestoneCompleteProposal = nil

        // Create a persisted session record so future messages have a home
        if let ctx = modelContext {
            let session = LuminaSession(sessionID: sessionID)
            ctx.insert(session)
            try? ctx.save()
        }
    }

    // MARK: - GAP 8: Agent Action Support

    /// Appends a local acknowledgment bubble to the chat (e.g. "✓ Task created: …").
    /// The message is display-only: it is NOT persisted to SwiftData and NOT included
    /// in the conversation history sent to the model — fixing all three confirmation bugs:
    ///  1. Confirmation no longer sends as a user message triggering a model response.
    ///  2. No duplicate: it lives only in the in-memory `messages` array.
    ///  3. No past-tense echo: the model never sees the confirmation text.
    func appendLocalAck(_ text: String) {
        messages.append(LuminaMessage(role: .info, content: text))
    }

    /// Proposed task waiting for user confirmation in LuminaView.
    var pendingTaskProposal: LuminaTaskProposal? = nil

    /// Proposed recurring routine waiting for user confirmation in LuminaView.
    var pendingRoutineProposal: LuminaRoutineProposal? = nil

    /// Proposed journey waiting for user confirmation in LuminaView.
    var pendingJourneyProposal: LuminaJourneyProposal? = nil

    /// Proposed plan waiting for user confirmation in LuminaView.
    var pendingPlanProposal: LuminaPlanProposal? = nil

    /// Proposed milestone waiting for user confirmation in LuminaView.
    var pendingMilestoneProposal: LuminaMilestoneProposal? = nil

    /// Proposed task-complete action waiting for user confirmation.
    var pendingTaskCompleteProposal: LuminaTaskCompleteProposal? = nil

    /// Proposed task-update action waiting for user confirmation.
    var pendingTaskUpdateProposal: LuminaTaskUpdateProposal? = nil

    /// Proposed task-delete action waiting for user confirmation.
    var pendingTaskDeleteProposal: LuminaTaskDeleteProposal? = nil

    /// Proposed routine-delete action waiting for user confirmation.
    var pendingRoutineDeleteProposal: LuminaRoutineDeleteProposal? = nil

    // MARK: Plan CRUD proposals
    var pendingPlanDeleteProposal:    LuminaPlanDeleteProposal?    = nil
    var pendingPlanCompleteProposal:  LuminaPlanCompleteProposal?  = nil

    // MARK: Journey CRUD proposals
    var pendingJourneyDeleteProposal:    LuminaJourneyDeleteProposal?    = nil
    var pendingJourneyCompleteProposal:  LuminaJourneyCompleteProposal?  = nil

    // MARK: Milestone CRUD proposals
    var pendingMilestoneDeleteProposal:    LuminaMilestoneDeleteProposal?    = nil
    var pendingMilestoneCompleteProposal:  LuminaMilestoneCompleteProposal?  = nil


    /// Parse ALL `[TASK_*: ...]` and `[REMINDER: ...]` markers from a streamed response.
    /// Strips every marker from the display text while preserving surrounding
    /// prose, then returns a proposal built from the FIRST valid marker.
    ///
    /// `[REMINDER:...]` is treated identically to `[TASK_PROPOSAL:...]` — both create a
    /// task proposal card in LuminaView. This prevents PAI from generating `[REMINDER:]`
    /// markers that would otherwise leak raw into the chat.
    private func parseAgentAction(from response: String) -> (cleanContent: String, proposal: LuminaTaskProposal?) {
        // Regex: matches [TASK_...] and [REMINDER...] markers.
        // \s* after \[ tolerates the space the LLM sometimes emits: "[ TASK_PROPOSAL:..."
        // dotMatchesLineSeparators allows the marker body to span a newline.
        guard let regex = try? NSRegularExpression(
            pattern: #"\[\s*(?:TASK_|REMINDER)[^\[]*?\]"#,
            options: [.dotMatchesLineSeparators]
        ) else {
            // Regex compile failure (should never happen) — still strip unknown markers.
            return (Self.stripUnknownMarkers(from: response), nil)
        }

        let nsStr     = response as NSString
        let fullRange = NSRange(location: 0, length: nsStr.length)
        let matches   = regex.matches(in: response, range: fullRange)

        // No TASK_/REMINDER markers found — strip unknown markers (e.g. [TO-DO:], [ACTION:])
        // then check for any unterminated [TASK_/[REMINDER tail at the end.
        if matches.isEmpty {
            var noMarkerClean = Self.stripUnknownMarkers(from: response)
            for prefix in ["[TASK_", "[ TASK_", "[REMINDER", "[ REMINDER"] {
                if let tailRange = noMarkerClean.range(of: prefix, options: [.caseInsensitive, .backwards]),
                   noMarkerClean.range(of: "]", range: tailRange.lowerBound..<noMarkerClean.endIndex) == nil {
                    noMarkerClean = String(noMarkerClean[noMarkerClean.startIndex..<tailRange.lowerBound])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            return (noMarkerClean, nil)
        }

        // Extract first marker body → proposal.
        var proposal: LuminaTaskProposal? = nil
        let firstMatchStr = nsStr.substring(with: matches[0].range)
        if let colonIdx = firstMatchStr.firstIndex(of: ":") {
            var body = String(firstMatchStr[firstMatchStr.index(after: colonIdx)...])
            if body.hasSuffix("]") { body = String(body.dropLast()) }
            proposal = parseMarkerBody(body)
        }

        // Remove ALL markers in reverse order so earlier ranges stay valid after each deletion.
        var clean = response
        for match in matches.reversed() {
            if let range = Range(match.range, in: clean) {
                clean.replaceSubrange(range, with: "")
            }
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Secondary pass: strip any leftover unterminated [TASK_ / [ TASK_ fragment (rare edge case).
        if let tailRange = clean.range(of: #"(?i)\[\s*TASK_"#, options: [.regularExpression, .backwards]),
           clean.range(of: "]", range: tailRange.lowerBound..<clean.endIndex) == nil {
            clean = String(clean[clean.startIndex..<tailRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Third pass: strip [ROUTINE_PROPOSAL:...] markers (parsed separately by parseRoutineProposal).
        // \s* tolerates spaces after "[" that the LLM occasionally emits.
        if let routineRegex = try? NSRegularExpression(
            pattern: #"\[\s*ROUTINE_PROPOSAL:[^\[]*?\]"#,
            options: [.dotMatchesLineSeparators]
        ) {
            let nsClean    = clean as NSString
            let cleanRange = NSRange(location: 0, length: nsClean.length)
            let rMatches   = routineRegex.matches(in: clean, range: cleanRange)
            for m in rMatches.reversed() {
                if let r = Range(m.range, in: clean) { clean.replaceSubrange(r, with: "") }
            }
            clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Also strip any unterminated [ ROUTINE_PROPOSAL fragment at the tail.
        if let tailRange = clean.range(of: #"(?i)\[\s*ROUTINE_PROPOSAL"#, options: [.regularExpression, .backwards]),
           clean.range(of: "]", range: tailRange.lowerBound..<clean.endIndex) == nil {
            clean = String(clean[clean.startIndex..<tailRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Fourth pass — universal cleanup: strip ANY remaining [WORD: ...] or [WORD_WORD ...]
        // markers that weren't caught above (e.g. [UPCOMING_TASK:], [ACTION:], [TODO:], etc.).
        // These are non-standard markers the LLM occasionally generates; they must never appear
        // raw in the chat UI.
        clean = Self.stripUnknownMarkers(from: clean)

        return (clean, proposal)
    }

    /// Strips any remaining `[UPPERCASE_WORD: ...]` style markers that were not handled
    /// by the task/routine parsers above.  Handles hyphens in marker names (e.g. [TO-DO:])
    /// which the LLM occasionally generates despite being instructed otherwise.
    private static func stripUnknownMarkers(from text: String) -> String {
        // \s* after \[ catches "[ TO-DO:]" etc. Pattern includes `-` for [TO-DO:] style markers.
        guard let regex = try? NSRegularExpression(
            pattern: #"\[\s*[A-Z][A-Z0-9_-]*[\s:][^\[]*?\]"#,
            options: [.dotMatchesLineSeparators]
        ) else { return text }

        var clean = text
        let nsStr = clean as NSString
        let matches = regex.matches(in: clean, range: NSRange(location: 0, length: nsStr.length))
        for match in matches.reversed() {
            if let range = Range(match.range, in: clean) {
                clean.replaceSubrange(range, with: "")
            }
        }
        // Also strip any unterminated [UPPERCASE (or [UPPER-CASE) fragment at the very end.
        if let tailRange = clean.range(
            of: #"\[[A-Z][A-Z0-9_-]+"#,
            options: [.regularExpression, .backwards]
        ), clean.range(of: "]", range: tailRange.lowerBound..<clean.endIndex) == nil {
            clean = String(clean[clean.startIndex..<tailRange.lowerBound])
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Response-side interpretation fallback.
    ///
    /// When Mercury (or another provider) responds with natural-language creation text
    /// instead of a `[TASK_PROPOSAL:]` marker — e.g.:
    ///   "I've added a new task for you:\n\n**Task:** Buy milk\n**When:** Today at 7:00 PM"
    ///
    /// …we extract the title and due date from the response and synthesise a proposal so that
    /// the confirm-card still appears.  This makes the system robust regardless of whether
    /// the model follows the marker instructions.
    ///
    /// Returns `nil` if the response does NOT look like a task-creation reply (so we don't
    /// accidentally trigger on conversational responses).
    private func extractTaskFromCreationResponse(_ text: String) -> LuminaTaskProposal? {
        let lower = text.lowercased()

        // Guard: only trigger on clear "I did something" creation phrases.
        let claimPhrases = ["i've added", "i have added", "i've created", "i have created",
                            "added a new task", "created a new task", "new task for you",
                            "added it to your", "i've set up a task", "set up a new task"]
        guard claimPhrases.contains(where: { lower.contains($0) }) else { return nil }

        // Don't double-trigger if a valid marker is already present.
        guard !text.contains("[TASK_PROPOSAL:"), !text.contains("[ROUTINE_PROPOSAL:") else { return nil }

        // Strip markdown bold markers to make parsing simpler.
        let stripped = text.replacingOccurrences(of: "**", with: "")

        // ── Extract title ──────────────────────────────────────────────────────────────
        // Mercury's common format:   Task: Buy milk
        // (after stripping ** the format is always plain "Task: <value>")
        var title: String? = nil
        if let regex = try? NSRegularExpression(pattern: #"Task:\s*(.+?)(?:\s{2,}|\n|$)"#,
                                                options: []) {
            let ns = stripped as NSString
            let all = NSRange(location: 0, length: ns.length)
            if let m = regex.firstMatch(in: stripped, range: all), m.numberOfRanges > 1 {
                let r = m.range(at: 1)
                if r.location != NSNotFound {
                    title = ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        guard let taskTitle = title, !taskTitle.isEmpty else { return nil }

        // ── Extract due date ───────────────────────────────────────────────────────────
        // Prefer the "When:" line if present (Mercury always emits it), else use full text.
        var dateSource = stripped
        if let regex = try? NSRegularExpression(pattern: #"When:\s*(.+?)(?:\s{2,}|\n|$)"#,
                                                options: []) {
            let ns = stripped as NSString
            let all = NSRange(location: 0, length: ns.length)
            if let m = regex.firstMatch(in: stripped, range: all), m.numberOfRanges > 1 {
                let r = m.range(at: 1)
                if r.location != NSNotFound {
                    dateSource = ns.substring(with: r)
                }
            }
        }
        let dueDate = NaturalLanguageParser.shared.parse(dateSource).dueDate

        return LuminaTaskProposal(title: taskTitle, detail: nil, priority: "medium", dueDate: dueDate)
    }

    /// Parse the key="value" body inside a `[TASK_*: ...]` marker into a `LuminaTaskProposal`.
    private func parseMarkerBody(_ markerBody: String) -> LuminaTaskProposal? {
        let title      = extractQuotedValue(key: "title",     from: markerBody) ?? ""
        let detail     = extractQuotedValue(key: "detail",    from: markerBody)
        let priority   = extractQuotedValue(key: "priority",  from: markerBody)
        let dueDateStr = extractQuotedValue(key: "due_date",  from: markerBody)
        let checklistStr = extractQuotedValue(key: "checklist", from: markerBody)

        guard !title.isEmpty else { return nil }

        // Parse due_date using the shared helper (handles local-timezone bare strings).
        var resolvedDate: Date? = dueDateStr.flatMap { parseMarkerDate($0) }

        // NLP fallback: scan title + detail for natural-language date phrases.
        if resolvedDate == nil {
            let combined = [title, detail].compactMap { $0 }.joined(separator: " ")
            resolvedDate = NaturalLanguageParser.shared.parse(combined).dueDate
        }

        // Parse pipe-delimited checklist items: checklist="Passport|Boarding pass|Charger"
        let checklistItems: [String]? = checklistStr?.components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return LuminaTaskProposal(title: title, detail: detail,
                                  priority: priority, dueDate: resolvedDate,
                                  checklistItems: checklistItems)
    }

    /// Parse a `[ROUTINE_PROPOSAL: ...]` marker from a streamed response and return a proposal.
    private func parseRoutineProposal(from response: String) -> LuminaRoutineProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*ROUTINE_PROPOSAL:[^\[]*?\]"#, from: response) else { return nil }

        let title            = extractQuotedValue(key: "title",          from: body) ?? ""
        let frequencyStr     = extractQuotedValue(key: "frequency",      from: body) ?? "daily"
        let timeStr          = extractQuotedValue(key: "time",           from: body)
        let daysStr          = extractQuotedValue(key: "days",           from: body)
        let durationWeeksStr = extractQuotedValue(key: "duration_weeks", from: body)
        let detail           = extractQuotedValue(key: "detail",         from: body)

        guard !title.isEmpty else { return nil }

        // Map frequency string → RecurrenceFrequency
        let frequency: RecurrenceFrequency
        switch frequencyStr.lowercased() {
        case "weekly":   frequency = .weekly
        case "monthly":  frequency = .monthly
        case "weekdays": frequency = .custom    // Mon–Fri
        default:         frequency = .daily
        }

        // Parse "HH:MM" time string → a Date carrying today's date + specified time
        var timeOfDay: Date? = nil
        if let ts = timeStr {
            let parts = ts.components(separatedBy: ":")
            if parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour   = hour
                comps.minute = minute
                comps.second = 0
                timeOfDay = Calendar.current.date(from: comps)
            }
        }

        // Parse days string "1,3,5" → [Int]  (Mon=1 … Sun=7)
        var daysOfWeek: [Int]? = nil
        if frequency == .weekly || frequency == .custom, let ds = daysStr {
            let parsed = ds.components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if !parsed.isEmpty { daysOfWeek = parsed }
        }
        // "weekdays" (custom) defaults to Mon–Fri when no explicit days given
        if frequency == .custom && daysOfWeek == nil {
            daysOfWeek = [1, 2, 3, 4, 5]
        }

        // Duration weeks — clamp to 1–52, default 12 (≈3 months)
        let durationWeeks = min(52, max(1, Int(durationWeeksStr ?? "") ?? 12))

        return LuminaRoutineProposal(
            title: title, frequency: frequency, timeOfDay: timeOfDay,
            daysOfWeek: daysOfWeek, durationWeeks: durationWeeks, detail: detail
        )
    }

    // MARK: - Journey / Plan / Milestone parsers

    /// Parses a `[JOURNEY_PROPOSAL: ...]` marker from a streamed response.
    private func parseJourneyProposal(from response: String) -> LuminaJourneyProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*JOURNEY_PROPOSAL:[^\[]*?\]"#, from: response) else { return nil }
        let title         = extractQuotedValue(key: "title",       from: body) ?? ""
        let vision        = extractQuotedValue(key: "vision",      from: body)
        let targetDateStr = extractQuotedValue(key: "target_date", from: body)
        let domain        = extractQuotedValue(key: "domain",      from: body).map { $0.lowercased() }
        let icon          = extractQuotedValue(key: "icon",        from: body)
        let colorHex      = extractQuotedValue(key: "color",       from: body)
        guard !title.isEmpty else { return nil }
        let targetDate = targetDateStr.flatMap { parseMarkerDate($0) }
        return LuminaJourneyProposal(title: title, vision: vision, targetDate: targetDate,
                                     domain: domain, icon: icon, colorHex: colorHex)
    }

    /// Parses a `[PLAN_PROPOSAL: ...]` marker from a streamed response.
    private func parsePlanProposal(from response: String) -> LuminaPlanProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*PLAN_PROPOSAL:[^\[]*?\]"#, from: response) else { return nil }
        let title    = extractQuotedValue(key: "title",  from: body) ?? ""
        let goal     = extractQuotedValue(key: "goal",   from: body)
        let domain   = extractQuotedValue(key: "domain", from: body).map { $0.lowercased() }
        let icon     = extractQuotedValue(key: "icon",   from: body)
        let colorHex = extractQuotedValue(key: "color",  from: body)
        guard !title.isEmpty else { return nil }
        return LuminaPlanProposal(title: title, goal: goal, domain: domain, icon: icon, colorHex: colorHex)
    }

    /// Parses a `[MILESTONE_PROPOSAL: ...]` marker from a streamed response.
    private func parseMilestoneProposal(from response: String) -> LuminaMilestoneProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*MILESTONE_PROPOSAL:[^\[]*?\]"#, from: response) else { return nil }
        let title         = extractQuotedValue(key: "title",       from: body) ?? ""
        let journeyTitle  = extractQuotedValue(key: "journey",     from: body)
        let targetDateStr = extractQuotedValue(key: "target_date", from: body)
        guard !title.isEmpty else { return nil }
        let targetDate = targetDateStr.flatMap { parseMarkerDate($0) }
        return LuminaMilestoneProposal(title: title, journeyTitle: journeyTitle, targetDate: targetDate)
    }

    // MARK: - CRUD Proposal Parsers

    /// Parse [TASK_COMPLETE: title="...", remarks="..."] from a model response.
    private func parseTaskCompleteProposal(from response: String) -> LuminaTaskCompleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*TASK_COMPLETE:[^\[]*?\]"#, from: response) else { return nil }
        let title   = extractQuotedValue(key: "title",   from: body) ?? ""
        let remarks = extractQuotedValue(key: "remarks", from: body) ?? ""
        guard !title.isEmpty else { return nil }
        return LuminaTaskCompleteProposal(title: title, remarks: remarks)
    }

    /// Parse [TASK_UPDATE: title="...", new_title="...", due_date="...", priority="..."] from a model response.
    private func parseTaskUpdateProposal(from response: String) -> LuminaTaskUpdateProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*TASK_UPDATE:[^\[]*?\]"#, from: response) else { return nil }
        let matchTitle = extractQuotedValue(key: "title",     from: body) ?? ""
        let newTitle   = extractQuotedValue(key: "new_title", from: body)
        let dueDateStr = extractQuotedValue(key: "due_date",  from: body)
        let priority   = extractQuotedValue(key: "priority",  from: body)
        guard !matchTitle.isEmpty else { return nil }
        let dueDate = dueDateStr.flatMap { parseMarkerDate($0) }
        return LuminaTaskUpdateProposal(matchTitle: matchTitle, newTitle: newTitle, dueDate: dueDate, priority: priority)
    }

    /// Parse [TASK_DELETE: title="..."] from a model response.
    private func parseTaskDeleteProposal(from response: String) -> LuminaTaskDeleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*TASK_DELETE:[^\[]*?\]"#, from: response) else { return nil }
        let title = extractQuotedValue(key: "title", from: body) ?? ""
        guard !title.isEmpty else { return nil }
        return LuminaTaskDeleteProposal(title: title)
    }

    /// Parse [ROUTINE_DELETE: title="..."] from a model response.
    private func parseRoutineDeleteProposal(from response: String) -> LuminaRoutineDeleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*ROUTINE_DELETE:[^\[]*?\]"#, from: response) else { return nil }
        let title = extractQuotedValue(key: "title", from: body) ?? ""
        guard !title.isEmpty else { return nil }
        return LuminaRoutineDeleteProposal(title: title)
    }

    // MARK: - Plan CRUD Parsers

    private func parsePlanDeleteProposal(from response: String) -> LuminaPlanDeleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*PLAN_DELETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = ""
        parseKeyValues(body) { key, value in if key == "title" { title = value } }
        return title.isEmpty ? nil : LuminaPlanDeleteProposal(title: title)
    }

    private func parsePlanCompleteProposal(from response: String) -> LuminaPlanCompleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*PLAN_COMPLETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = "", remarks = ""
        parseKeyValues(body) { key, value in
            switch key { case "title": title = value; case "remarks": remarks = value; default: break }
        }
        return title.isEmpty ? nil : LuminaPlanCompleteProposal(title: title, remarks: remarks)
    }

    // MARK: - Journey CRUD Parsers

    private func parseJourneyDeleteProposal(from response: String) -> LuminaJourneyDeleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*JOURNEY_DELETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = ""
        parseKeyValues(body) { key, value in if key == "title" { title = value } }
        return title.isEmpty ? nil : LuminaJourneyDeleteProposal(title: title)
    }

    private func parseJourneyCompleteProposal(from response: String) -> LuminaJourneyCompleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*JOURNEY_COMPLETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = "", remarks = ""
        parseKeyValues(body) { key, value in
            switch key { case "title": title = value; case "remarks": remarks = value; default: break }
        }
        return title.isEmpty ? nil : LuminaJourneyCompleteProposal(title: title, remarks: remarks)
    }

    // MARK: - Milestone CRUD Parsers

    private func parseMilestoneDeleteProposal(from response: String) -> LuminaMilestoneDeleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*MILESTONE_DELETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = "", journeyTitle = ""
        parseKeyValues(body) { key, value in
            switch key { case "title": title = value; case "journey": journeyTitle = value; default: break }
        }
        return title.isEmpty ? nil : LuminaMilestoneDeleteProposal(title: title, journeyTitle: journeyTitle)
    }

    private func parseMilestoneCompleteProposal(from response: String) -> LuminaMilestoneCompleteProposal? {
        guard let body = extractMarkerBody(pattern: #"\[\s*MILESTONE_COMPLETE:[^\[]*?\]"#, from: response) else { return nil }
        var title = "", journeyTitle = "", remarks = ""
        parseKeyValues(body) { key, value in
            switch key {
            case "title":   title        = value
            case "journey": journeyTitle = value
            case "remarks": remarks      = value
            default: break
            }
        }
        return title.isEmpty ? nil : LuminaMilestoneCompleteProposal(title: title, journeyTitle: journeyTitle, remarks: remarks)
    }

    // MARK: - Parser Helpers

    /// Parse a date string produced by Lumina's LLM output.
    ///
    /// The LLM is told to emit times in the user's LOCAL timezone (e.g. SGT) but its
    /// output typically contains NO timezone suffix (e.g. "2026-03-04T17:00:00").
    ///
    /// ISO8601DateFormatter with .withInternetDateTime requires a suffix ("Z" / "+HH:MM"),
    /// and .withFullDate+.withFullTime also demands timezone — so BOTH standard attempts
    /// fail for the LLM's typical output, leaving dueDate=nil.
    ///
    /// This helper adds a third pass using DateFormatter with TimeZone.current so the
    /// bare datetime string is correctly interpreted in the user's local timezone.
    private func parseMarkerDate(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }

        // 1. Full ISO8601 with explicit timezone offset ("...+08:00" or "...Z")
        let isoTZ = ISO8601DateFormatter()
        isoTZ.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate,
                               .withColonSeparatorInTime, .withTimeZone]
        if let d = isoTZ.date(from: raw) { return d }

        // 2. "YYYY-MM-DDTHH:mm:ss" — no timezone, interpret as LOCAL time
        let dtFmt = DateFormatter()
        dtFmt.locale = Locale(identifier: "en_US_POSIX")
        dtFmt.timeZone = TimeZone.current
        dtFmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = dtFmt.date(from: raw) { return d }

        // 3. Date-only "YYYY-MM-DD" — start of day in local timezone
        let dFmt = DateFormatter()
        dFmt.locale = Locale(identifier: "en_US_POSIX")
        dFmt.timeZone = TimeZone.current
        dFmt.dateFormat = "yyyy-MM-dd"
        if let d = dFmt.date(from: raw) { return d }

        return nil
    }

    /// Extracts and returns the body of a marker (content after the first colon, before the closing `]`).
    private func extractMarkerBody(pattern: String, from response: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let nsStr = response as NSString
        guard let match = regex.firstMatch(in: response, range: NSRange(location: 0, length: nsStr.length)) else { return nil }
        let matchStr = nsStr.substring(with: match.range)
        guard let colonIdx = matchStr.firstIndex(of: ":") else { return nil }
        var body = String(matchStr[matchStr.index(after: colonIdx)...])
        if body.hasSuffix("]") { body = String(body.dropLast()) }
        return body
    }

    /// Scans a marker body for all `key="value"` pairs using regex and calls the handler for each.
    /// This handles commas inside quoted values correctly (unlike the old comma-split approach).
    private func parseKeyValues(_ body: String, handler: (String, String) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: #"(\w+)\s*=\s*"([^"]*)""#) else { return }
        let nsStr = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: nsStr.length))
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let keyRange = Range(match.range(at: 1), in: body),
                  let valRange = Range(match.range(at: 2), in: body) else { continue }
            let key   = String(body[keyRange]).trimmingCharacters(in: .whitespaces)
            let value = String(body[valRange]).trimmingCharacters(in: .whitespaces)
            handler(key, value)
        }
    }

    // MARK: - Tier 2 Auto-Derived Context

    /// Builds Tier 2 profile context auto-derived from Journeys, Plans, and Routines.
    /// Replaces the old manual UserProfile.tier2Context fields.
    private func buildTier2Context(for domains: Set<ConversationDomain>) -> String {
        guard let ctx = modelContext else { return "" }

        // Fetch all, then filter in Swift — avoids CoreData crash when
        // CloudKit schema doesn't yet have the "status" column.
        let journeys = ((try? ctx.fetch(FetchDescriptor<Journey>())) ?? [])
            .filter { $0.status != nil }
        let plans = ((try? ctx.fetch(FetchDescriptor<Plan>())) ?? [])
            .filter { $0.status != nil }
        let routines = ((try? ctx.fetch(FetchDescriptor<Routine>())) ?? [])
            .filter { $0.isActive }

        return ProfileContextBuilder.tier2Context(
            journeys: journeys, plans: plans, routines: routines,
            for: domains
        )
    }

    // MARK: - Real-Time App Context Builder

    /// Queries SwiftData via the injected modelContext and returns a grounded snapshot of
    /// the user's tasks, plans, journeys, and routines.  Injected as a system message
    /// before every Lumina turn so PAI answers are factual, not hallucinated.
    private func buildAppContext() -> String? {
        guard let ctx = modelContext else { return nil }

        // --- Fetch all incomplete tasks ---
        // No fetchLimit and no sortBy here: SwiftData executes a limited+sorted fetch as a
        // SQL "ORDER BY … LIMIT n" query which can miss tasks that are in the context's
        // in-memory pending-changes set (inserted but not yet flushed to SQLite).
        // Journeys work correctly because they use an unconstrained FetchDescriptor — we
        // match that pattern here so newly added tasks are visible on the very next send.
        // Sorting and capping are done in memory below, which is fast and always up-to-date.
        let taskDesc = FetchDescriptor<TaskWork>(
            predicate: #Predicate<TaskWork> { $0.completedAt == nil }
        )
        guard let allTasks = try? ctx.fetch(taskDesc) else { return nil }

        let calendar      = Calendar.current
        let now           = Date()
        let todayStart    = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        let weekEnd       = calendar.date(byAdding: .day, value: 7, to: tomorrowStart)!

        let overdueTasks = allTasks.filter { t in
            guard let d = t.dueDate else { return false }
            return calendar.startOfDay(for: d) < todayStart && !t.isSubtask
        }
        let todayTasks = allTasks.filter { t in
            guard let d = t.dueDate else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= todayStart && day < tomorrowStart && !t.isSubtask
        }
        let upcomingTasks = allTasks.filter { t in
            guard let d = t.dueDate else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= tomorrowStart && day < weekEnd && !t.isSubtask
        }
        let inboxTasks = allTasks.filter { t in
            t.dueDate == nil && t.plan == nil && t.journey == nil && !t.isSubtask
        }

        // --- Fetch plans (all, filter active in memory to avoid optional-enum predicate issues) ---
        let allPlans    = (try? ctx.fetch(FetchDescriptor<Plan>())) ?? []
        let activePlans = allPlans.filter { $0.status == .active || $0.status == nil }

        // --- Fetch journeys (all, filter in-progress / not-started in memory) ---
        let allJourneys    = (try? ctx.fetch(FetchDescriptor<Journey>())) ?? []
        let activeJourneys = allJourneys.filter {
            let s = $0.status
            return s == .inProgress || s == .notStarted || s == nil
        }

        // --- Fetch active routines ---
        let routineDesc = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.isActive }
        )
        let activeRoutines = (try? ctx.fetch(routineDesc)) ?? []

        // --- Assemble grounded context block ---
        var lines: [String] = [
            "=== REAL-TIME DATA FROM USER'S IALLY DATABASE ===",
            "CRITICAL: Use ONLY the data below to answer factual questions about the user's",
            "tasks, plans, journeys, and routines. If something is NOT listed here it does",
            "NOT exist. Never invent, assume, or hallucinate any task, appointment, or event.",
            ""
        ]

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "EEEE, MMM d yyyy 'at' HH:mm"
        lines.append("Current date/time: \(dateFmt.string(from: now))")
        lines.append("")

        // Overdue tasks
        if overdueTasks.isEmpty {
            lines.append("OVERDUE TASKS: None")
        } else {
            lines.append("OVERDUE TASKS (\(overdueTasks.count)):")
            for t in overdueTasks.prefix(15) {
                let due = t.dueDate.map { ctxDateTimeStr($0) } ?? "no date"
                lines.append("  • \(t.title) — overdue since \(due)")
            }
            if overdueTasks.count > 15 { lines.append("  …and \(overdueTasks.count - 15) more") }
        }
        lines.append("")

        // Today's tasks
        if todayTasks.isEmpty {
            lines.append("TODAY'S TASKS: None scheduled for today")
        } else {
            lines.append("TODAY'S TASKS (\(todayTasks.count)):")
            for t in todayTasks {
                let time: String
                if let d = t.dueDate {
                    let cal  = Calendar.current
                    let hour = cal.component(.hour,   from: d)
                    let min  = cal.component(.minute, from: d)
                    // Tasks saved with only a date (no specific time) are stored at midnight 00:00.
                    // Show "no specific time" for those so Lumina doesn't echo "12:00 AM".
                    time = (hour == 0 && min == 0) ? "no specific time" : ctxTimeStr(d)
                } else {
                    time = "no specific time"
                }
                lines.append("  • \(t.title) — due at \(time)")
            }
        }
        lines.append("")

        // Upcoming (next 7 days)
        if upcomingTasks.isEmpty {
            lines.append("UPCOMING TASKS (next 7 days): None")
        } else {
            lines.append("UPCOMING TASKS (next 7 days) (\(upcomingTasks.count)):")
            for t in upcomingTasks.prefix(10) {
                let due = t.dueDate.map { ctxDateTimeStr($0) } ?? "no date"
                lines.append("  • \(t.title) — due \(due)")
            }
            if upcomingTasks.count > 10 { lines.append("  …and \(upcomingTasks.count - 10) more") }
        }
        lines.append("")

        // Inbox
        if inboxTasks.isEmpty {
            lines.append("INBOX (no due date / no plan / no journey): Empty")
        } else {
            lines.append("INBOX (\(inboxTasks.count) tasks, no due date):")
            for t in inboxTasks.prefix(8) { lines.append("  • \(t.title)") }
            if inboxTasks.count > 8 { lines.append("  …and \(inboxTasks.count - 8) more") }
        }
        lines.append("")

        // Active plans
        if activePlans.isEmpty {
            lines.append("ACTIVE PLANS: None")
        } else {
            lines.append("ACTIVE PLANS (\(activePlans.count)):")
            for p in activePlans {
                lines.append("  • \(p.name) [\(p.lifeDomain.rawValue)] — \(p.completedTaskCount) done, \(p.activeTaskCount) active")
                if let g = p.goal, !g.isEmpty {
                    lines.append("    Goal: \(g.prefix(100))")
                }
            }
        }
        lines.append("")

        // Active journeys
        if activeJourneys.isEmpty {
            lines.append("ACTIVE JOURNEYS: None")
        } else {
            lines.append("ACTIVE JOURNEYS (\(activeJourneys.count)):")
            for j in activeJourneys {
                let status     = j.status?.rawValue ?? "active"
                let pct        = Int(j.progress * 100)
                let milestones = j.milestones ?? []
                let done       = milestones.filter { $0.isCompleted }.count
                var jLine      = "  • \(j.title) [status: \(status), \(pct)% done, milestones: \(done)/\(milestones.count)]"
                if let days = j.daysRemaining { jLine += ", \(days) days remaining" }
                lines.append(jLine)
                let nextMilestones = milestones
                    .filter { !$0.isCompleted }
                    .sorted { $0.order < $1.order }
                    .prefix(3)
                for m in nextMilestones { lines.append("    ↳ Next: \(m.title)") }
            }
        }
        lines.append("")

        // Active routines
        if activeRoutines.isEmpty {
            lines.append("ACTIVE ROUTINES: None")
        } else {
            lines.append("ACTIVE ROUTINES (\(activeRoutines.count)):")
            for r in activeRoutines {
                lines.append("  • \(r.title) [\(r.frequency.rawValue), streak: \(r.currentStreak) days]")
            }
        }
        lines.append("")
        lines.append("=== END OF USER DATA ===")
        return lines.joined(separator: "\n")
    }

    /// Formats a Date as "Mon Mar 3" for the app context snapshot (date only).
    private func ctxDateStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    /// Formats a Date as "Mon Mar 3 at 2:00 PM", or just "Mon Mar 3" if no specific time was
    /// set (time component is midnight 00:00).  This prevents the LLM from fabricating times.
    private func ctxDateTimeStr(_ date: Date) -> String {
        let cal  = Calendar.current
        let hour = cal.component(.hour,   from: date)
        let min  = cal.component(.minute, from: date)
        let f    = DateFormatter()
        f.amSymbol = "AM"
        f.pmSymbol = "PM"
        if hour == 0 && min == 0 {
            f.dateFormat = "EEE MMM d"          // no specific time — show date only
        } else {
            f.dateFormat = "EEE MMM d 'at' h:mm a"   // e.g. "Mon Mar 3 at 2:00 PM"
        }
        return f.string(from: date)
    }

    /// Formats a Date as "5:17 PM" (12-hour with AM/PM) for the app context snapshot.
    private func ctxTimeStr(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"   // e.g. "5:17 PM" — 12-hour clock with AM/PM marker
        f.amSymbol  = "AM"
        f.pmSymbol  = "PM"
        return f.string(from: date)
    }
}

// MARK: - Agent Action models

/// A proposed task waiting for the user to confirm or cancel in LuminaView.
struct LuminaTaskProposal: Equatable {
    var title: String
    var detail: String?
    var priority: String?       // "low" | "medium" | "high" | "urgent"
    var dueDate: Date?          // Resolved from ISO8601 marker field or NLP fallback
    var checklistItems: [String]? // Pipe-delimited items from checklist="item1|item2|item3"
}

/// A proposed recurring routine waiting for the user to confirm or cancel in LuminaView.
struct LuminaRoutineProposal: Equatable {
    var title: String
    var frequency: RecurrenceFrequency  // .daily | .weekly | .monthly | .custom (weekdays)
    var timeOfDay: Date?                // Today's date with the LLM-specified HH:MM time
    var daysOfWeek: [Int]?              // Mon=1 … Sun=7 (for weekly/custom frequency)
    var durationWeeks: Int              // 1–52; default 12 ≈ 3 months
    var detail: String?
}

/// A proposed Journey waiting for user confirmation.
struct LuminaJourneyProposal: Equatable {
    var title: String
    var vision: String?          // "why" behind the journey
    var targetDate: Date?
    var domain: String?          // LifeDomain.rawValue e.g. "learning", "health"
    var icon: String?            // SF Symbol name
    var colorHex: String?
}

/// A proposed Plan waiting for user confirmation.
struct LuminaPlanProposal: Equatable {
    var title: String
    var goal: String?            // success metric / outcome
    var domain: String?          // LifeDomain.rawValue
    var icon: String?
    var colorHex: String?
}

/// A proposed Milestone waiting for user confirmation.
struct LuminaMilestoneProposal: Equatable {
    var title: String
    var journeyTitle: String?    // fuzzy-matched to an existing Journey
    var targetDate: Date?
}

/// Proposal to mark an existing task as complete (with optional user remarks).
struct LuminaTaskCompleteProposal: Equatable {
    var title: String            // fuzzy-matched to an existing TaskWork
    var remarks: String          // stored in task.completionReflection
}

/// Proposal to update fields on an existing task.
struct LuminaTaskUpdateProposal: Equatable {
    var matchTitle: String       // title used to locate the task (fuzzy)
    var newTitle: String?        // rename to this if provided
    var dueDate: Date?           // new due date if provided
    var priority: String?        // new priority if provided
}

/// Proposal to delete an existing task (only if not started).
struct LuminaTaskDeleteProposal: Equatable {
    var title: String            // fuzzy-matched to an existing TaskWork
}

/// Proposal to delete an existing Routine (and its future generated tasks).
struct LuminaRoutineDeleteProposal: Equatable {
    var title: String            // fuzzy-matched to an existing Routine
}

// MARK: - Plan CRUD proposals

/// Proposal to delete a Plan that has not been started (0 done, 0 active tasks).
struct LuminaPlanDeleteProposal: Equatable {
    var title: String            // fuzzy-matched to Plan.name
}

/// Proposal to mark a Plan as complete with closing remarks.
struct LuminaPlanCompleteProposal: Equatable {
    var title: String            // fuzzy-matched to Plan.name
    var remarks: String          // reason for completing/stopping
}

// MARK: - Journey CRUD proposals

/// Proposal to delete a Journey that has no started milestones.
struct LuminaJourneyDeleteProposal: Equatable {
    var title: String            // fuzzy-matched to Journey.title
}

/// Proposal to mark a Journey as complete with closing remarks.
struct LuminaJourneyCompleteProposal: Equatable {
    var title: String            // fuzzy-matched to Journey.title
    var remarks: String          // reason for completing/stopping
}

// MARK: - Milestone CRUD proposals

/// Proposal to delete a Milestone that has not been started.
struct LuminaMilestoneDeleteProposal: Equatable {
    var title: String            // fuzzy-matched to Milestone.title
    var journeyTitle: String     // scope to the correct Journey
}

/// Proposal to mark a Milestone as complete with closing remarks.
struct LuminaMilestoneCompleteProposal: Equatable {
    var title: String            // fuzzy-matched to Milestone.title
    var journeyTitle: String     // scope to the correct Journey
    var remarks: String          // reason / reflection
}
