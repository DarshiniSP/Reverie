//
//  CalendarManager.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import Foundation
import EventKit
import SwiftUI
import Combine

/// Manages calendar integration with iOS EventKit
@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    private let eventStore = EKEventStore()
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isCalendarEnabled = false
    @Published var selectedCalendars: Set<String> = []
    
    private init() {
        updateAuthorizationStatus()
        loadSettings()
    }
    
    // MARK: - Authorization

    /// Update the current authorization status
    func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    /// Request full calendar access (iOS 17+)
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            updateAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    var hasCalendarAccess: Bool {
        authorizationStatus == .fullAccess
    }
    
    // MARK: - Settings Persistence
    
    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "calendarSettings"),
           let settings = try? JSONDecoder().decode(CalendarSettings.self, from: data) {
            isCalendarEnabled = settings.isEnabled
            selectedCalendars = settings.selectedCalendarIds
        }
    }
    
    func saveSettings() {
        let settings = CalendarSettings(
            isEnabled: isCalendarEnabled,
            selectedCalendarIds: selectedCalendars
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "calendarSettings")
        }
    }
    
    // MARK: - Calendar Access
    
    /// Get all available calendars
    func getCalendars() -> [EKCalendar] {
        guard hasCalendarAccess else { return [] }
        return eventStore.calendars(for: .event)
    }
    
    /// Get only selected calendars
    func getSelectedCalendars() -> [EKCalendar] {
        guard hasCalendarAccess else { return [] }
        let allCalendars = eventStore.calendars(for: .event)
        
        if selectedCalendars.isEmpty {
            return allCalendars
        }
        
        return allCalendars.filter { selectedCalendars.contains($0.calendarIdentifier) }
    }
    
    // MARK: - Event Fetching
    
    /// Fetch events for today
    func fetchTodayEvents() -> [EKEvent] {
        guard hasCalendarAccess && isCalendarEnabled else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        return fetchEvents(from: startOfDay, to: endOfDay)
    }
    
    /// Fetch events for a specific date
    func fetchEvents(for date: Date) -> [EKEvent] {
        guard hasCalendarAccess && isCalendarEnabled else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        
        return fetchEvents(from: startOfDay, to: endOfDay)
    }
    
    /// Fetch events in date range
    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard hasCalendarAccess && isCalendarEnabled else { return [] }
        
        let calendars = getSelectedCalendars()
        guard !calendars.isEmpty else { return [] }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )
        
        let events = eventStore.events(matching: predicate)
        return events.sorted { $0.startDate < $1.startDate }
    }
    
    /// Fetch upcoming events (next 7 days)
    func fetchUpcomingEvents(days: Int = 7) -> [EKEvent] {
        guard hasCalendarAccess && isCalendarEnabled else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        let futureDate = calendar.date(byAdding: .day, value: days, to: now) ?? now
        
        return fetchEvents(from: now, to: futureDate)
    }
    
    // MARK: - Event Creation
    
    /// Create a calendar event from a task
    func createEvent(from task: TaskWork) -> Bool {
        guard hasCalendarAccess else { return false }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = task.title
        event.notes = task.detail
        
        // Set dates
        if let dueDate = task.dueDate {
            event.startDate = dueDate
            
            // Duration based on task size
            let duration: TimeInterval
            switch task.size {
            case .small:
                duration = 30 * 60 // 30 minutes
            case .medium:
                duration = 60 * 60 // 1 hour
            case .large:
                duration = 2 * 60 * 60 // 2 hours
            }
            event.endDate = dueDate.addingTimeInterval(duration)
        } else {
            event.startDate = Date()
            event.endDate = Date().addingTimeInterval(60 * 60) // 1 hour default
        }
        
        // Use default calendar
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add notes about task properties
        var notes = task.detail ?? ""
        if let plan = task.plan {
            notes += "\n\nPlan: \(plan.lifeDomain.rawValue)"
        }
        if let journey = task.journey {
            notes += "\nJourney: \(journey.title)"
        }
        event.notes = notes
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }
    
    /// Create a recurring calendar event series from a Routine definition.
    ///
    /// - Parameters:
    ///   - routine: The Routine model containing frequency, activeDays, and timeOfDay.
    ///   - durationDays: Total span in days for the series (e.g. 84 for 12 weeks).
    /// - Returns: `true` on success, `false` if access is unavailable or save fails.
    func createRecurringEvent(from routine: Routine, durationDays: Int) -> Bool {
        guard hasCalendarAccess else { return false }

        // Build start date: today's date at the routine's preferred time, or right now
        let startDate: Date = {
            guard let tod = routine.timeOfDay else { return Date() }
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: Date())
            comps.hour   = cal.component(.hour,   from: tod)
            comps.minute = cal.component(.minute, from: tod)
            comps.second = 0
            return cal.date(from: comps) ?? Date()
        }()

        // Series end date gives the duration stopper
        let seriesEndDate = Calendar.current.date(
            byAdding: .day, value: durationDays, to: startDate
        ) ?? startDate
        let recurrenceEnd = EKRecurrenceEnd(end: seriesEndDate)

        // Map Mon=1..Sun=7 → EKWeekday
        let ekDayMap: [Int: EKWeekday] = [
            1: .monday, 2: .tuesday, 3: .wednesday,
            4: .thursday, 5: .friday, 6: .saturday, 7: .sunday
        ]

        // Build the recurrence rule based on frequency
        let recurrenceRule: EKRecurrenceRule
        switch routine.frequency {
        case .daily:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .daily, interval: 1, end: recurrenceEnd
            )

        case .weekly:
            let days = (routine.activeDays ?? [])
                .compactMap { ekDayMap[$0] }
                .map { EKRecurrenceDayOfWeek($0) }
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: days.isEmpty ? nil : days,
                daysOfTheMonth: nil, monthsOfTheYear: nil,
                weeksOfTheYear: nil, daysOfTheYear: nil,
                setPositions: nil, end: recurrenceEnd
            )

        case .monthly:
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .monthly, interval: 1, end: recurrenceEnd
            )

        case .custom:    // Weekdays (Mon–Fri) or user-specified days
            let sourceDays = routine.activeDays ?? [1, 2, 3, 4, 5]
            let days = sourceDays
                .compactMap { ekDayMap[$0] }
                .map { EKRecurrenceDayOfWeek($0) }
            recurrenceRule = EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: days.isEmpty ? nil : days,
                daysOfTheMonth: nil, monthsOfTheYear: nil,
                weeksOfTheYear: nil, daysOfTheYear: nil,
                setPositions: nil, end: recurrenceEnd
            )
        }

        // Create and persist the event
        let event = EKEvent(eventStore: eventStore)
        event.title     = routine.title
        event.notes     = "iAlly Routine — \(routine.frequency.rawValue)"
        event.startDate = startDate
        event.endDate   = startDate.addingTimeInterval(60 * 60)   // 1-hour block
        event.addRecurrenceRule(recurrenceRule)
        event.calendar  = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(event, span: .futureEvents)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helper Methods
    
    /// Check if an event is all-day
    func isAllDay(_ event: EKEvent) -> Bool {
        event.isAllDay
    }
    
    /// Get formatted time range for event
    func formatTimeRange(for event: EKEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        
        return "\(start) - \(end)"
    }
    
    /// Get event duration in minutes
    func duration(for event: EKEvent) -> Int {
        let interval = event.endDate.timeIntervalSince(event.startDate)
        return Int(interval / 60)
    }
    
    /// Check if event is currently happening
    func isHappening(now event: EKEvent) -> Bool {
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }
    
    /// Check if event is upcoming (starts in next hour)
    func isUpcoming(_ event: EKEvent) -> Bool {
        let now = Date()
        let oneHourLater = now.addingTimeInterval(60 * 60)
        return event.startDate > now && event.startDate <= oneHourLater
    }
}

// MARK: - Calendar Settings Model

struct CalendarSettings: Codable {
    let isEnabled: Bool
    let selectedCalendarIds: Set<String>
}

// MARK: - Calendar Event Data (for SwiftUI)

struct CalendarEventData: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendar: CalendarData
    let notes: String?
    
    init(from event: EKEvent) {
        self.id = event.eventIdentifier
        self.title = event.title
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.calendar = CalendarData(from: event.calendar)
        self.notes = event.notes
    }
}

struct CalendarData: Identifiable {
    let id: String
    let title: String
    let color: Color
    
    init(from calendar: EKCalendar) {
        self.id = calendar.calendarIdentifier
        self.title = calendar.title
        self.color = Color(calendar.cgColor)
    }
}
