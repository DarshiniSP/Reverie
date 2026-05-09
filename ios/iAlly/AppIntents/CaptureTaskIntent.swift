//
//  CaptureTaskIntent.swift
//  iAlly
//
//  P4-C: "Hey Siri, add to iAlly: call dentist next Tuesday"
//
//  Stores the task title in the shared App Group UserDefaults so the main app can
//  pick it up via ShortcutManager.processPendingShortcutTaskWork(in:) on next launch.
//

import AppIntents
import Foundation

// MARK: - P4-C: Capture Task App Intent

struct CaptureTaskIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Task to iAlly"
    static var description = IntentDescription(
        "Quickly add a task to iAlly from Siri, Shortcuts, or Spotlight.",
        categoryName: "Tasks"
    )

    /// The phrase for Siri: "Add <Task> to iAlly"
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$taskTitle) to iAlly")
    }

    @Parameter(title: "Task", description: "What do you want to add?")
    var taskTitle: String

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let data = ShortcutTaskData(title: taskTitle, detail: nil, dueDate: nil, size: .medium)
        if let encoded = try? JSONEncoder().encode(data),
           let defaults = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly") {
            defaults.set(encoded, forKey: "pendingShortcutTask")
        }
        return .result(dialog: IntentDialog("Added '\(taskTitle)' to iAlly."))
    }
}
