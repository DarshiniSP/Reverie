//
//  CompleteRoutineIntent.swift
//  iAlly
//
//  P4-C: "Hey Siri, mark gym as done in iAlly"
//
//  Stores the routine name in the shared App Group UserDefaults so the main app
//  can complete the matching routine via ShortcutManager on next foreground.
//

import AppIntents
import Foundation

// MARK: - P4-C: Complete Routine App Intent

struct CompleteRoutineIntent: AppIntent {

    static var title: LocalizedStringResource = "Mark Routine Complete in iAlly"
    static var description = IntentDescription(
        "Tell iAlly you've completed a daily routine. Great for gym, meditation, journaling.",
        categoryName: "Routines"
    )

    /// The phrase for Siri: "Mark <Routine> as done in iAlly"
    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$routineName) as done in iAlly")
    }

    @Parameter(title: "Routine", description: "Which routine did you complete?")
    var routineName: String

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults(suiteName: "group.Irigam-Innovations.iAlly")?
            .set(routineName, forKey: "pendingRoutineCompletion")
        return .result(dialog: IntentDialog("Marked '\(routineName)' complete in iAlly. Well done! 💪"))
    }
}
