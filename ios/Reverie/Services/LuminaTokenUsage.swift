// LuminaTokenUsage.swift
// iAlly
//
// Monthly token usage tracking for Lumina AI inference.
// Persisted in UserDefaults; auto-resets when the month changes.

import Foundation

struct LuminaTokenUsage: Codable {
    var totalTokensThisMonth: Int = 0
    var totalCallsThisMonth: Int = 0
    var estimatedCostUSD: Double = 0.0
    var monthKey: String = ""            // "YYYY-MM" — resets when month changes

    /// Rate: ~$0.000003 per token (Claude Sonnet output, rough estimate for budget UI).
    static let costPerToken: Double = 0.000_003

    static var current: LuminaTokenUsage {
        get {
            let key = Self.currentMonthKey()
            let saved = UserDefaults.standard.data(forKey: "pai.tokenUsage.\(key)")
            if let saved, let decoded = try? JSONDecoder().decode(LuminaTokenUsage.self, from: saved) {
                return decoded
            }
            return LuminaTokenUsage(monthKey: key)
        }
        set {
            let key = Self.currentMonthKey()
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "pai.tokenUsage.\(key)")
                UserDefaults(suiteName: AppConfig.appGroupIdentifier)?
                    .set(data, forKey: "pai.tokenUsage.\(key)")
            }
        }
    }

    mutating func record(tokens: Int) {
        let key = Self.currentMonthKey()
        if monthKey != key { self = LuminaTokenUsage(monthKey: key) }
        totalTokensThisMonth += tokens
        totalCallsThisMonth += 1
        estimatedCostUSD = Double(totalTokensThisMonth) * Self.costPerToken
    }

    static func currentMonthKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: Date())
    }
}
