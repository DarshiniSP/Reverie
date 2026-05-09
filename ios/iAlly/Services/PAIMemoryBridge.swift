// PAIMemoryBridge.swift
// iAlly — Local Memory Bridge
//
// Translates iAlly user actions into local episodic memory events.
// Every meaningful action (task completion, journey milestone, routine check-in,
// note capture, weekly reflection) is recorded as a structured memory event so
// Lumina builds an accurate model of the user's life over time.
//
// Design principles:
//   • Fire-and-forget: never blocks the UI thread or the user's action
//   • Idempotent: safe to call multiple times for the same event
//   • Structured metadata: every event carries context tags for future retrieval
//   • All storage is on-device via LocalMemoryService (SwiftData)

import Foundation
import SwiftData

@MainActor
final class PAIMemoryBridge {

    // MARK: - Shared instance

    static let shared = PAIMemoryBridge()

    // Set from iAllyApp so LocalMemoryService can persist events.
    var modelContext: ModelContext?

    private init() {}

    // MARK: - Task Events

    /// Record that a task was completed.
    /// Captures: title, priority, plan/journey context, how long it was open.
    func recordTaskCompleted(_ task: TaskWork) {
        let daysOpen: Int
        if let due = task.dueDate {
            daysOpen = Calendar.current.dateComponents([.day], from: task.createdAt, to: due).day ?? 0
        } else {
            daysOpen = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        }
        let priority = task.priority?.rawValue ?? "none"
        let planContext = task.plan?.name ?? ""
        let journeyContext = task.journey?.title ?? ""

        var content = "Completed task: \"\(task.title)\"."
        if !planContext.isEmpty { content += " Part of plan: \"\(planContext)\"." }
        if !journeyContext.isEmpty { content += " Contributing to journey: \"\(journeyContext)\"." }
        content += " Priority: \(priority). Open for \(daysOpen) day(s)."

        let metadata: [String: String] = [
            "event_type": "task_completed",
            "task_id": task.persistentModelID.hashValue.description,
            "priority": priority,
            "plan": planContext,
            "journey": journeyContext,
            "days_open": "\(daysOpen)"
        ]
        storeLocally(content: content, type: "episodic", metadata: metadata)
    }

    /// Record that a task was created (captures intent, not completion).
    func recordTaskCreated(_ task: TaskWork) {
        guard !task.title.isEmpty else { return }
        let detail = task.detail ?? ""
        let content = "Created task: \"\(task.title)\"." + (detail.isEmpty ? "" : " Notes: \(detail)")
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "task_created",
            "priority": task.priority?.rawValue ?? "none"
        ])
    }

    // MARK: - Journey Events

    /// Record a new milestone being added to a journey via Lumina.
    func recordMilestoneCreated(_ milestone: Milestone) {
        let journeyName = milestone.journey?.title ?? "unknown journey"
        let content = "Added milestone: \"\(milestone.title)\" to journey \"\(journeyName)\"."
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "milestone_created",
            "journey": journeyName
        ])
    }

    /// Record that a journey milestone was reached.
    func recordMilestoneCompleted(milestone: Milestone, journey: Journey) {
        let content = "Reached milestone \"\(milestone.title)\" on journey \"\(journey.title)\"."
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "milestone_completed",
            "journey": journey.title
        ])
    }

    /// Record that a new journey was started.
    func recordJourneyStarted(_ journey: Journey) {
        let vision = journey.vision ?? ""
        let content = "Started a new journey: \"\(journey.title)\"." + (vision.isEmpty ? "" : " Vision: \(vision)")
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "journey_started",
            "journey": journey.title
        ])
    }

    // MARK: - Routine Events

    /// Record a routine check-in (habit completed for the day).
    func recordRoutineCheckin(_ routine: Routine) {
        let content = "Completed routine: \"\(routine.title)\" today."
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "routine_checkin",
            "routine": routine.title
        ])
    }

    /// Record a routine streak break (missed a day).
    func recordRoutineStreakBroken(_ routine: Routine, streak: Int) {
        let content = "Missed routine \"\(routine.title)\" after a \(streak)-day streak."
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "routine_streak_broken",
            "routine": routine.title,
            "streak": "\(streak)"
        ])
    }

    // MARK: - Knowledge / Notes

    /// Record a learning, decision, or observation as semantic memory.
    func recordKnowledge(content: String, type: KnowledgeType, tags: [String] = []) {
        guard !content.isEmpty else { return }
        var taggedContent = content
        if !tags.isEmpty { taggedContent += " [tags: \(tags.joined(separator: ", "))]" }
        storeLocally(content: taggedContent, type: "semantic", metadata: [
            "event_type": "knowledge_captured",
            "knowledge_type": type.rawValue
        ])
    }

    /// Record a quick capture — the system will classify it later.
    func recordQuickCapture(_ text: String) {
        guard !text.isEmpty else { return }
        storeLocally(content: "Quick capture: \"\(text)\"", type: "episodic", metadata: [
            "event_type": "quick_capture"
        ])
    }

    // MARK: - Reflection Events

    /// Record a weekly review reflection summary.
    func recordWeeklyReflection(summary: String, week: Date = Date()) {
        let weekStr = ISO8601DateFormatter().string(from: week)
        storeLocally(
            content: "Weekly reflection (\(weekStr)): \(summary)",
            type: "episodic",
            metadata: ["event_type": "weekly_reflection", "week": weekStr]
        )
    }

    /// Record a focus session completion.
    func recordFocusSession(taskTitle: String, durationMinutes: Int) {
        let content = "Completed \(durationMinutes)-minute focus session on: \"\(taskTitle)\"."
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "focus_session",
            "duration_minutes": "\(durationMinutes)"
        ])
    }

    // MARK: - Conversation Events

    /// Record a single Lumina conversation turn as local memory.
    /// NOTE: Conversation turns are intentionally NOT stored in LocalMemoryService
    /// to avoid duplicating the live chat history that's already in recentMessages.
    func recordConversationMessage(_ text: String, role: String, sessionID: String) {
        // No-op for beta — conversation turns already exist in recentMessages.
        // Re-enable if a persistent conversation summarisation layer is added later.
    }

    /// Record the intent classification result from Lumina Capture.
    func recordLuminaCapture(_ rawInput: String, classifiedAs intent: String) {
        guard !rawInput.isEmpty else { return }
        storeLocally(
            content: "Quick capture classified as [\(intent)]: \"\(rawInput)\"",
            type: "episodic",
            metadata: ["event_type": "lumina_capture", "intent": intent]
        )
    }

    // MARK: - Plan Events

    /// Record a new plan being created via Lumina.
    func recordPlanCreated(_ plan: Plan) {
        let domain = plan.lifeDomain.rawValue
        let content = "Created plan: \"\(plan.name)\" in life domain: \(domain)."
            + (plan.goal.map { " Goal: \($0)" } ?? "")
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "plan_created",
            "life_domain": domain
        ])
    }

    /// Record a plan being completed.
    func recordPlanCompleted(_ plan: Plan) {
        let domain = plan.lifeDomain.rawValue
        let content = "Completed plan: \"\(plan.name)\" in life domain: \(domain)."
            + (plan.goal.map { " Goal was: \($0)" } ?? "")
        storeLocally(content: content, type: "episodic", metadata: [
            "event_type": "plan_completed",
            "life_domain": domain
        ])
    }

    // MARK: - Local storage helper

    /// Writes a memory event to LocalMemoryService (SwiftData). Instant, no network.
    private func storeLocally(content: String, type: String, metadata: [String: String]) {
        LocalMemoryService.shared.store(content: content, type: type, metadata: metadata)
    }
}

// MARK: - Knowledge Type

enum KnowledgeType: String {
    case learning    = "learning"     // Something you learned
    case decision    = "decision"     // A decision you made
    case observation = "observation"  // Something you noticed
    case quote       = "quote"        // An inspiring or useful quote
    case insight     = "insight"      // A personal insight
}
