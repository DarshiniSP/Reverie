// LuminaSystemPromptBuilder.swift
// iAlly
//
// Assembles the Lumina system-prompt array from domain-detected layers.
// Only injects sections relevant to the current message — saves 60-73% tokens
// compared to the previous monolithic approach.
//
// Layers:
//   L1 (always, ~150 t):      Persona + Tier-1 profile + data grounding
//   L2 (always, ~300 t):      App context snapshot (real-time SwiftData)
//   L3 (conditional, 0-400t): Marker rules filtered to detected domains
//   L4 (conditional, 0-100t): Tier-2 auto-derived context (Journeys/Plans/Routines)
//   L5 (conditional, 0-200t): Relevant memories
//   L6 (conditional, 0-200t): Few-shot enforcement examples filtered to domains

import Foundation

struct LuminaSystemPromptBuilder {

    // MARK: - Input

    struct Input {
        let detection:   DomainDetectionResult
        let profile:     UserProfile
        let tier2Context: String      // Auto-derived from Journeys/Plans/Routines via ProfileContextBuilder
        let appContext:  String?      // buildAppContext() output; nil if no items
        let memories:    [String]     // already deduplicated; empty → L5 omitted
        let todayISO:    String       // "2026-03-04"
        let currentTime: String       // "14:32"
        let tzLabel:     String       // "SGT"
    }

    // MARK: - Main build

    static func build(_ input: Input) -> [PAIChatMessage] {
        var out: [PAIChatMessage] = []
        let d = input.detection

        // L1 — always
        out.append(.init(role: "system", content: layer1(input)))

        // L2 — app context (always when present)
        if let ctx = input.appContext {
            out.append(.init(role: "system", content: ctx))
        }

        // L3 — marker rules (skip for pure query / pending confirmation)
        if !d.isQueryOnly && !d.isPendingConfirmation {
            if let rules = markerRules(for: d.domains, input: input) {
                out.append(.init(role: "system", content: rules))
            }
        }

        // L4 — tier-2 auto-derived context (skip for low confidence / query / pending)
        if d.confidence != .low && !d.isQueryOnly && !d.isPendingConfirmation {
            if !input.tier2Context.isEmpty {
                out.append(.init(role: "system", content: input.tier2Context))
            }
        }

        // L5 — memories (omit when empty)
        if !input.memories.isEmpty {
            let body = input.memories.prefix(6).joined(separator: "\n")
            out.append(.init(role: "system", content: """
                Relevant things you remember about this user:
                \(body)
                Reference these naturally if truly relevant — do not mention you are using stored memory.
                """))
        }

        // L6 — enforcement examples (skip for pure query / pending confirmation)
        if !d.isQueryOnly && !d.isPendingConfirmation {
            out.append(.init(role: "system",
                             content: enforcementExamples(for: d.domains, input: input)))
        }

        return out
    }

    // MARK: - Token estimate (for LuminaProfileView display)

    static func estimateTokens(
        for detection: DomainDetectionResult,
        profile: UserProfile,
        tier2Context: String = ""
    ) -> (always: Int, maximum: Int) {
        func wordTokens(_ s: String) -> Int {
            Int(Double(s.split(separator: " ").count) * 1.35) + 4
        }
        let always  = wordTokens(profile.tier1Context) + 150
        let t2Max   = wordTokens(tier2Context)
        let maximum = always + t2Max + 400 + 200  // L3 max + L6 max
        return (always, maximum)
    }

    // MARK: - L1: Persona + Tier-1 + Data Grounding (always)

    private static func layer1(_ input: Input) -> String {
        var parts: [String] = []

        parts.append(
            "You are Lumina, the AI assistant inside iAlly. " +
            "Today: \(input.todayISO). Time: \(input.currentTime) \(input.tzLabel). " +
            "You can read the user's data AND take actions (create, complete, update, delete items) " +
            "using the marker format defined in the rules below."
        )

        let t1 = input.profile.tier1Context
        if !t1.isEmpty { parts.append(t1) }

        parts.append("""
            DATA GROUNDING (highest priority):
            "REAL-TIME DATA FROM USER'S IALLY DATABASE" is the ONLY truth source for existing items.
            • Never invent tasks, dates, priorities, or details not listed there.
            • Section says "None" → tell the user there are none. Do not fabricate.
            • CREATE markers: emit immediately when the user asks to create something new.
            • MODIFY markers (TASK_COMPLETE / TASK_UPDATE / TASK_DELETE / ROUTINE_DELETE / etc.): \
            ONLY emit if the exact item title appears in the real-time data. \
            If NOT found → say "I don't see [item] in your schedule." Never emit for a non-existent item.
            • List tasks individually with exact times from data. \
            Never summarise with "both due today" etc.
            """)

        return parts.joined(separator: "\n\n")
    }

    // MARK: - L3: Domain-conditional marker rules

    private static func markerRules(
        for domains: Set<ConversationDomain>,
        input: Input
    ) -> String? {
        let hasCreate = domains.contains { isCreateDomain($0) }
        let hasModify = domains.contains { isModifyDomain($0) }
        guard hasCreate || hasModify else { return nil }

        var sections: [String] = [
            "MARKERS — output exactly ONE per response, never combined:"
        ]

        // ── CREATE blocks ──
        if hasCreate {
            sections.append("CREATE new items:")
            if domains.contains(.taskCreate) {
                sections.append(
                    "• [TASK_PROPOSAL: title=\"...\", priority=\"low|medium|high|urgent\", " +
                    "due_date=\"\(input.todayISO)T17:00:00\", detail=\"\", " +
                    "checklist=\"item1|item2|item3\"]  (checklist is optional — use for tasks with preparation steps or lists)"
                )
            }
            if domains.contains(.routineCreate) {
                sections.append(
                    "• [ROUTINE_PROPOSAL: title=\"...\", frequency=\"daily|weekly|weekdays|monthly\", " +
                    "time=\"HH:MM\", days=\"\", duration_weeks=\"12\", detail=\"\"]"
                )
            }
            if domains.contains(.journeyCreate) {
                sections.append(
                    "• [JOURNEY_PROPOSAL: title=\"...\", vision=\"...\", target_date=\"YYYY-MM-DD\", " +
                    "domain=\"personal|health|career|finance|relationships|learning|creativity\", " +
                    "icon=\"sfSymbolName\"]"
                )
            }
            if domains.contains(.planCreate) {
                sections.append(
                    "• [PLAN_PROPOSAL: title=\"...\", goal=\"...\", " +
                    "domain=\"personal|health|career|finance|relationships|learning|creativity\", " +
                    "icon=\"sfSymbolName\"]"
                )
            }
            if domains.contains(.milestoneCreate) {
                sections.append(
                    "• [MILESTONE_PROPOSAL: title=\"...\", " +
                    "journey=\"exact journey title from real-time data\", target_date=\"YYYY-MM-DD\"]"
                )
            }
        }

        // ── MODIFY blocks ──
        if hasModify {
            if hasCreate { sections.append("") }
            sections.append("MODIFY existing items — check real-time data first, item must exist:")
            if domains.contains(.taskModify) {
                sections.append("""
                    TASK (use exact title from real-time data):
                    • Not started (no focus sessions) → [TASK_DELETE: title="..."] \
                    or [TASK_UPDATE: title="...", new_title="", due_date="", priority=""]
                    • Started / in progress → [TASK_COMPLETE: title="...", remarks="user's reason"]
                    """)
            }
            if domains.contains(.routineModify) {
                sections.append("ROUTINE:\n• [ROUTINE_DELETE: title=\"...\"]")
            }
            if domains.contains(.planModify) {
                sections.append("""
                    PLAN (use name from real-time data):
                    • Not started (0 done, 0 active tasks) → [PLAN_DELETE: title="..."]
                    • Started → [PLAN_COMPLETE: title="...", remarks="user's reason"]
                    """)
            }
            if domains.contains(.journeyModify) {
                sections.append("""
                    JOURNEY:
                    • No milestones started (0% done) → [JOURNEY_DELETE: title="..."]
                    • Any milestone started → [JOURNEY_COMPLETE: title="...", remarks="user's reason"]
                    """)
            }
            if domains.contains(.milestoneModify) {
                sections.append("""
                    MILESTONE:
                    • Not started → [MILESTONE_DELETE: title="...", journey="exact journey title"]
                    • Started → [MILESTONE_COMPLETE: title="...", journey="exact journey title", \
                    remarks="user's reason"]
                    """)
            }
        }

        // ── WHEN to use each marker (filtered) ──
        sections.append(whenToUse(for: domains))

        // ── RULES 1-6 (always when Layer 3 active) ──
        sections.append("""
            RULES:
            1. ONE sentence before ANY marker: "Here's what I'll create/set up/complete/update/delete — please confirm below."
            2. NEVER say "I've added/created/done/marked/deleted" — user must tap Confirm first.
            3. After user says "Confirm/Yes/OK" → say "Tap the Confirm button on the card below." Do NOT re-emit.
            4. Plain English only. No markdown tables, no **bold**, no key=value visible to user. 12-hour clock only.
            5. Task list format: "Here are your tasks for [period]: 1. [Title]: Due at [12h time]. 2. ..." — data only.
            6. MODIFY requires existence: item NOT in real-time data → say "I don't see [item] in your data." No marker.
            """)

        // ── FIELD REFERENCE (only when task/routine create active) ──
        if domains.contains(.taskCreate) || domains.contains(.routineCreate) {
            sections.append("""
                FIELD REFERENCE:
                due_date: "\(input.todayISO)T17:00:00" (\(input.tzLabel)). \
                morning=09:00, afternoon=14:00, evening=18:00, tonight=20:00, noon=12:00. \
                "in 2 hours"=\(input.currentTime)+2h. ""=no date.
                priority: low|medium|high|urgent. \
                frequency: daily|weekly|weekdays|monthly. \
                days: Mon=1..Sun=7 e.g."1,3,5". \
                duration_weeks: 12 default (1 month=4, 6 months=26, 1 year=52).
                """)
        }

        return sections.joined(separator: "\n")
    }

    private static func whenToUse(for domains: Set<ConversationDomain>) -> String {
        var lines: [String] = ["WHEN to use each marker:"]
        if domains.contains(.taskCreate) {
            lines.append("• \"add / remind / schedule / create\" → [TASK_PROPOSAL:] (one-off)")
        }
        if domains.contains(.routineCreate) {
            lines.append("• \"set up a habit / every day / recurring\" → [ROUTINE_PROPOSAL:]")
        }
        if domains.contains(.journeyCreate) {
            lines.append("• \"start a goal (months-long)\" → [JOURNEY_PROPOSAL:]")
        }
        if domains.contains(.planCreate) {
            lines.append("• \"create a project / plan\" → [PLAN_PROPOSAL:]")
        }
        if domains.contains(.milestoneCreate) {
            lines.append("• \"add a milestone\" → [MILESTONE_PROPOSAL:]")
        }
        if domains.contains(.taskModify) {
            lines.append("• \"mark done / complete / finish a task\" → [TASK_COMPLETE: remarks=\"...\"]")
            lines.append("• \"reschedule / rename / change / update a task\" → [TASK_UPDATE:]")
            lines.append("• \"delete / remove / cancel a task\" (not started) → [TASK_DELETE:]")
        }
        if domains.contains(.routineModify) {
            lines.append("• \"delete / stop / cancel a routine\" → [ROUTINE_DELETE:]")
        }
        if domains.contains(.planModify) {
            lines.append("• \"delete / abandon a plan\" (not started) → [PLAN_DELETE:]")
            lines.append("• \"complete / wrap up / finish a plan\" → [PLAN_COMPLETE: remarks=\"...\"]")
        }
        if domains.contains(.journeyModify) {
            lines.append("• \"delete / abandon a journey\" (no milestones started) → [JOURNEY_DELETE:]")
            lines.append("• \"complete / wrap up / finish a journey\" → [JOURNEY_COMPLETE: remarks=\"...\"]")
        }
        if domains.contains(.milestoneModify) {
            lines.append("• \"delete a milestone\" (not started) → [MILESTONE_DELETE:]")
            lines.append("• \"complete a milestone\" → [MILESTONE_COMPLETE: remarks=\"...\"]")
        }
        lines.append("• \"plan to do X at 5pm\" → [TASK_PROPOSAL:] (not PLAN_PROPOSAL)")
        lines.append("• Everything else → plain English. WHEN IN DOUBT → [TASK_PROPOSAL:].")
        return lines.joined(separator: "\n")
    }

    // MARK: - L6: Few-shot enforcement examples (domain-filtered)

    private static func enforcementExamples(
        for domains: Set<ConversationDomain>,
        input: Input
    ) -> String {
        var lines: [String] = [
            "MARKER FORMAT REMINDER — Today: \(input.todayISO). Now: \(input.currentTime) \(input.tzLabel).",
            "ONE sentence + ONE marker. Nothing else. NO MARKER = NOTHING HAPPENS.",
            ""
        ]

        if domains.contains(.taskCreate) {
            lines.append("""
                ✅ "remind me to buy milk at 5pm" →
                Here's what I'll create — please confirm below.
                [TASK_PROPOSAL: title="Buy milk", priority="medium", due_date="\(input.todayISO)T17:00:00", detail=""]
                """)
        }
        if domains.contains(.taskModify) {
            lines.append("""
                ✅ "mark Buy milk as done" →
                Here's what I'll complete — please confirm below.
                [TASK_COMPLETE: title="Buy milk"]
                """)
            lines.append("""
                ✅ "reschedule Buy milk to tomorrow 9am" →
                Here's what I'll update — please confirm below.
                [TASK_UPDATE: title="Buy milk", due_date="<tomorrowISO>T09:00:00", priority=""]
                """)
            lines.append("""
                ✅ "delete Buy milk" →
                Here's what I'll delete — please confirm below.
                [TASK_DELETE: title="Buy milk"]
                """)
        }
        if domains.contains(.routineModify) {
            lines.append("""
                ✅ "delete / stop my Morning Meditation routine" →
                Here's what I'll delete — please confirm below.
                [ROUTINE_DELETE: title="Morning Meditation"]
                """)
        }
        if domains.contains(.planModify) {
            lines.append("""
                ✅ "complete / wrap up my Home Renovation plan" (has active tasks) →
                Here's what I'll complete — please confirm below.
                [PLAN_COMPLETE: title="Home Renovation", remarks="user's reason for closing"]
                """)
            lines.append("""
                ✅ "delete my Home Renovation plan" (0 done, 0 active) →
                Here's what I'll delete — please confirm below.
                [PLAN_DELETE: title="Home Renovation"]
                """)
        }
        if domains.contains(.journeyModify) {
            lines.append("""
                ✅ "I want to stop my Run a Marathon journey — I had an injury" →
                Here's what I'll complete — please confirm below.
                [JOURNEY_COMPLETE: title="Run a Marathon", remarks="had an injury"]
                """)
            lines.append("""
                ✅ "delete Run a Marathon journey" (not started, no milestones) →
                Here's what I'll delete — please confirm below.
                [JOURNEY_DELETE: title="Run a Marathon"]
                """)
        }
        if domains.contains(.milestoneModify) {
            lines.append("""
                ✅ "complete the Week 1 Training milestone — finished it" →
                Here's what I'll complete — please confirm below.
                [MILESTONE_COMPLETE: title="Week 1 Training", journey="Run a Marathon", remarks="finished it"]
                """)
        }

        // Always included: negative example + NEVER past tense rule
        lines.append("""
            ❌ "cancel my appointment with my boss" (NOT in real-time data) →
            I don't see any appointment with your boss in your schedule.
            [NO MARKER — never emit MODIFY for a non-existent item]

            ❌ NEVER: "I've added/marked/deleted..." — no past tense. ❌ NEVER: plain text without a marker for actions.
            """)

        return lines.joined(separator: "\n")
    }

    // MARK: - Domain classification helpers

    private static func isCreateDomain(_ d: ConversationDomain) -> Bool {
        switch d {
        case .taskCreate, .routineCreate, .journeyCreate, .planCreate, .milestoneCreate:
            return true
        default:
            return false
        }
    }

    private static func isModifyDomain(_ d: ConversationDomain) -> Bool {
        switch d {
        case .taskModify, .routineModify, .planModify, .journeyModify, .milestoneModify:
            return true
        default:
            return false
        }
    }
}
