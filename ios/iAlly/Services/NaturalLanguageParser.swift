//
//  NaturalLanguageParser.swift
//  iAlly
//
//  Created by Irigam Developer on 11/12/25.
//

import Foundation

/// Parses natural language input to extract task details, dates, and metadata
class NaturalLanguageParser {
    static let shared = NaturalLanguageParser()
    
    private init() {}
    
    // MARK: - Main Parsing Method
    
    /// Parse natural language text into structured task data
    /// Examples:
    /// - "Buy milk tomorrow at 3pm"
    /// - "Call dentist next monday"
    /// - "Review presentation on friday small task"
    /// - "Exercise daily"
    func parse(_ input: String) -> ParsedTask {
        var parsed = ParsedTask(originalInput: input)
        
        let lowercased = input.lowercased()
        
        // Extract due date
        if let (date, cleanedText) = extractDate(from: input) {
            parsed.dueDate = date
            parsed.cleanedTitle = cleanedText
        } else {
            parsed.cleanedTitle = input
        }
        
        // Extract time if present
        if let time = extractTime(from: lowercased) {
            if let dueDate = parsed.dueDate {
                parsed.dueDate = combineDateTime(date: dueDate, time: time)
            } else {
                // If time specified but no date, assume today
                parsed.dueDate = combineDateTime(date: Date(), time: time)
            }
        }
        
        // Extract task size
        if let size = extractTaskSize(from: lowercased) {
            parsed.size = size
            // Remove size keywords from title
            parsed.cleanedTitle = removeSizeKeywords(from: parsed.cleanedTitle ?? input)
        }
        
        // Detect recurrence patterns
        if let frequency = extractRecurrence(from: lowercased) {
            parsed.isRecurring = true
            parsed.recurrencePattern = frequency
            // Remove recurrence keywords from title
            parsed.cleanedTitle = removeRecurrenceKeywords(from: parsed.cleanedTitle ?? input)
        }

        // P1-E: Extract priority locally (instant, no PAI)
        if let priority = extractPriority(from: lowercased) {
            parsed.priority = priority
            parsed.cleanedTitle = removePriorityKeywords(from: parsed.cleanedTitle ?? input)
        }

        // P1-E: Extract domain locally via keyword matching
        parsed.inferredDomain = extractDomain(from: parsed.cleanedTitle ?? input)

        // Clean up the title
        parsed.cleanedTitle = parsed.cleanedTitle?.trimmingCharacters(in: .whitespacesAndNewlines)

        return parsed
    }
    
    // MARK: - Date Extraction
    
    private func extractDate(from text: String) -> (Date, String)? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()
        
        // Relative dates
        if lowercased.contains("today") {
            return (calendar.startOfDay(for: now), removeWord("today", from: text))
        }

        if lowercased.contains("tomorrow") {
            if let date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                return (date, removeWord("tomorrow", from: text))
            }
        }

        // Time-of-day shorthand (no explicit date → assume today)
        let timeOfDayPhrases: [(phrase: String, hour: Int, minute: Int)] = [
            ("end of day",    17,  0),
            ("end-of-day",    17,  0),
            ("eod",           17,  0),
            ("by end of day", 17,  0),
            ("tonight",       20,  0),
            ("this evening",  18,  0),
            ("this afternoon",14,  0),
            ("this morning",   9,  0),
            ("this noon",     12,  0),
            ("at noon",       12,  0),
            ("midday",        12,  0),
            ("midnight",       0,  0),
            ("this week",      0,  0),   // start of next Monday
        ]
        for entry in timeOfDayPhrases {
            if lowercased.contains(entry.phrase) {
                var components: DateComponents
                if entry.phrase == "this week" {
                    // Nearest upcoming Monday
                    let weekday = calendar.component(.weekday, from: now)
                    let daysUntilMonday = (9 - weekday) % 7
                    let monday = calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: calendar.startOfDay(for: now)) ?? now
                    let cleaned = text.replacingOccurrences(of: entry.phrase, with: "", options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return (monday, cleaned)
                } else {
                    components = calendar.dateComponents([.year, .month, .day], from: now)
                    components.hour   = entry.hour
                    components.minute = entry.minute
                    components.second = 0
                    if let date = calendar.date(from: components) {
                        let cleaned = text.replacingOccurrences(of: entry.phrase, with: "", options: .caseInsensitive)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return (date, cleaned)
                    }
                }
            }
        }
        
        // Day names (next monday, tuesday, etc.)
        // Apple Calendar convention: index+1 must match weekday (1=Sun, 2=Mon, ..., 7=Sat)
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, weekday) in weekdays.enumerated() {
            if lowercased.contains(weekday) {
                if let date = getNext(weekday: index + 1, from: now) {
                    return (date, removeWord(weekday, from: text))
                }
            }
        }
        
        // "next week" / "next month"
        if lowercased.contains("next week") {
            if let date = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: now)) {
                return (date, removePhrase("next week", from: text))
            }
        }
        
        if lowercased.contains("next month") {
            if let date = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now)) {
                return (date, removePhrase("next month", from: text))
            }
        }
        
        // Relative day references
        if let match = lowercased.range(of: #"in (\d+) days?"#, options: .regularExpression) {
            let matchedText = String(lowercased[match])
            if let number = extractNumber(from: matchedText) {
                if let date = calendar.date(byAdding: .day, value: number, to: calendar.startOfDay(for: now)) {
                    return (date, text.replacingOccurrences(of: matchedText, with: "", options: .caseInsensitive))
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Time Extraction
    
    private func extractTime(from text: String) -> DateComponents? {
        // Match patterns like "at 3pm", "at 14:00", "3:30pm"
        let patterns = [
            #"at (\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,  // at 3pm, at 3:30pm
            #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,      // 3pm, 3:30pm
            #"at (\d{1,2}):(\d{2})"#                    // at 14:30 (24-hour)
        ]
        
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matchedText = String(text[match])
                
                // Extract hour and minute
                let parts = matchedText.components(separatedBy: CharacterSet(charactersIn: ": atampm"))
                    .filter { !$0.isEmpty }
                
                guard let hourStr = parts.first, let hour = Int(hourStr) else { continue }
                
                let minute = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
                
                // Determine if AM/PM
                var adjustedHour = hour
                if matchedText.contains("pm") && hour < 12 {
                    adjustedHour = hour + 12
                } else if matchedText.contains("am") && hour == 12 {
                    adjustedHour = 0
                }
                
                var timeComponents = DateComponents()
                timeComponents.hour = adjustedHour
                timeComponents.minute = minute
                return timeComponents
            }
        }
        
        return nil
    }
    
    // MARK: - Task Size Extraction
    
    private func extractTaskSize(from text: String) -> TaskSize? {
        if text.contains("small") || text.contains("quick") || text.contains("tiny") {
            return .small
        }
        if text.contains("large") || text.contains("big") || text.contains("huge") {
            return .large
        }
        if text.contains("medium") {
            return .medium
        }
        return nil
    }
    
    // MARK: - P1-E: Priority Extraction (local, no PAI)

    /// Extract task priority from natural language keywords.
    /// Returns `nil` when no priority keyword is found (caller keeps .medium default).
    func extractPriority(from text: String) -> Priority? {
        let lower = text.lowercased()

        // Urgent keywords (highest precedence)
        let urgentKeywords = ["urgent", "asap", "critical", "emergency", "immediately", "right now", "right away"]
        for kw in urgentKeywords where lower.contains(kw) { return .urgent }

        // High priority keywords
        let highKeywords = ["important", "priority", "must", "need to", "don't forget", "key", "essential", "vital"]
        for kw in highKeywords where lower.contains(kw) { return .high }

        // Low priority keywords
        let lowKeywords = ["someday", "maybe", "when i can", "low priority", "not urgent", "whenever", "eventually", "if time"]
        for kw in lowKeywords where lower.contains(kw) { return .low }

        return nil
    }

    /// Remove priority keywords from the task title so they don't pollute it.
    func removePriorityKeywords(from text: String) -> String {
        var result = text
        let allKeywords = [
            "urgent", "asap", "critical", "emergency", "immediately", "right now", "right away",
            "important", "priority", "must", "don't forget", "key", "essential", "vital",
            "someday", "maybe", "when i can", "low priority", "not urgent", "whenever", "eventually", "if time"
        ]
        for kw in allKeywords {
            result = result.replacingOccurrences(of: kw, with: "", options: [.caseInsensitive, .regularExpression])
        }
        return result
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - P1-E: Domain Extraction (delegates to LifeDomainInferenceService local path)

    /// Synchronously infer a LifeDomain from keyword matching.
    /// Uses the same keyword rules as LifeDomainInferenceService.inferLocally().
    func extractDomain(from text: String) -> LifeDomain? {
        LifeDomain.inferLocally(from: text)
    }

    // MARK: - Recurrence Pattern Extraction

    private func extractRecurrence(from text: String) -> String? {
        if text.contains("daily") || text.contains("every day") {
            return "daily"
        }
        if text.contains("weekly") || text.contains("every week") {
            return "weekly"
        }
        if text.contains("monthly") || text.contains("every month") {
            return "monthly"
        }
        if text.contains("weekday") || text.contains("every weekday") {
            return "weekdays"
        }
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func getNext(weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)
        
        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: date))
    }
    
    private func combineDateTime(date: Date, time: DateComponents) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components) ?? date
    }
    
    private func extractNumber(from text: String) -> Int? {
        let pattern = #"\d+"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Int(String(text[match]))
        }
        return nil
    }
    
    private func removeWord(_ word: String, from text: String) -> String {
        text.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removePhrase(_ phrase: String, from text: String) -> String {
        text.replacingOccurrences(of: phrase, with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removeSizeKeywords(from text: String) -> String {
        var result = text
        let sizeKeywords = ["small", "medium", "large", "quick", "tiny", "big", "huge"]
        for keyword in sizeKeywords {
            result = removeWord(keyword, from: result)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removeRecurrenceKeywords(from text: String) -> String {
        var result = text
        let recurrenceKeywords = ["daily", "weekly", "monthly", "every day", "every week", "every month", "weekday", "every weekday"]
        for keyword in recurrenceKeywords {
            result = removePhrase(keyword, from: result)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Parsed Task Model

struct ParsedTask {
    let originalInput: String
    var cleanedTitle: String?
    var dueDate: Date?
    var size: TaskSize?
    var isRecurring: Bool = false
    var recurrencePattern: String?
    /// Priority — extracted locally by keyword (P1-E) or enriched by PAI
    var priority: Priority?
    /// Life domain inferred from keywords (P1-E) — nil when no keyword matched
    var inferredDomain: LifeDomain?
    /// Suggested plan or journey context from Lumina (nil when no AI provider configured)
    var suggestedContext: String?
    /// True when this result was enriched by PAI (false = local regex only)
    var isAIEnriched: Bool = false

    var suggestedTitle: String {
        cleanedTitle?.isEmpty == false ? cleanedTitle! : originalInput
    }
}

// MARK: - PAI InterpretPhase Integration

extension NaturalLanguageParser {

    /// Parses `input` locally first (instant) then enriches with PAI's InterpretPhase
    /// (async, runs when AI provider is configured). Returns the AI-enriched ParsedTask.
    ///
    /// Usage in AddTaskView:
    /// ```swift
    /// let enriched = await NaturalLanguageParser.shared.parseWithAI(input)
    /// self.parsedTask = enriched
    /// ```
    @MainActor
    func parseWithAI(_ input: String) async -> ParsedTask {
        // Step 1: local parse (always instant, works offline)
        var base = parse(input)

        // Step 2: AI enrichment — only when a provider is configured
        let router = LuminaInferenceRouter.shared
        guard router.isActiveProviderConfigured else { return base }
        guard input.count > 8 else { return base } // skip for very short inputs

        let systemPrompt = """
        You are Lumina's InterpretPhase. Extract structured task data from the user's natural language input.
        Respond in JSON only, no explanation. Use this exact schema:
        {"title": "clean task title", "priority": "urgent|high|medium|low", "size": "tiny|small|medium|large|huge", "context": "any plan or goal this relates to, or empty string"}
        If you cannot determine a field, omit it. Respond with valid JSON only.
        """

        do {
            let content = try await router.generate(messages: [
                .system(systemPrompt),
                .user(input)
            ])

            // Parse AI's JSON response
            if let data = content.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {

                // Apply enrichment to base result — PAI overrides local regex where it has data
                if let title = json["title"], !title.isEmpty {
                    base.cleanedTitle = title
                }
                if let priorityStr = json["priority"],
                   let p = Priority(rawValue: priorityStr.capitalized) {
                    base.priority = p
                }
                if let sizeStr = json["size"],
                   let s = TaskSize(rawValue: sizeStr.capitalized) {
                    base.size = s
                }
                if let ctx = json["context"], !ctx.isEmpty {
                    base.suggestedContext = ctx
                }
                base.isAIEnriched = true
            }
        } catch {
            // PAI enrichment failed — return the local parse result unchanged
        }

        return base
    }
}
