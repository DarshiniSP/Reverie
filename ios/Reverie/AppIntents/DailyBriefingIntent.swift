//
//  DailyBriefingIntent.swift
//  iAlly
//
//  P4-C: "Hey Siri, what's my focus for today in iAlly?"
//
//  Reads the latest Lumina briefing insight from the shared App Group UserDefaults
//  (written by ProactiveIntelligenceEngine) and speaks it back via Siri.
//

import AppIntents
import Foundation

// MARK: - P4-C: Daily Briefing App Intent

struct DailyBriefingIntent: AppIntent {

    static var title: LocalizedStringResource = "Get Today's Focus from iAlly"
    static var description = IntentDescription(
        "Ask iAlly what you should focus on today. Lumina will brief you.",
        categoryName: "Intelligence"
    )

    // MARK: - Perform

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let insight = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly")?
            .string(forKey: "lumina.widget.insight")
            ?? "Open iAlly to see your daily briefing."

        let focusTask = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly")?
            .string(forKey: "lumina.widget.focusTask")

        let response: String
        if let focus = focusTask, !focus.isEmpty {
            response = "\(insight) Your focus task is: \(focus)."
        } else {
            response = insight
        }

        return .result(dialog: IntentDialog(stringLiteral: response))
    }
}
