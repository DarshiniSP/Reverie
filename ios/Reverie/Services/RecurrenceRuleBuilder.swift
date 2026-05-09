//
//  RecurrenceRuleBuilder.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import Foundation

/// Builds and manages advanced recurrence patterns for routines
class RecurrenceRuleBuilder {
    static let shared = RecurrenceRuleBuilder()
    
    private init() {}
    
    // MARK: - Next Occurrence Calculation
    
    /// Calculate the next occurrence date for a routine
    func nextOccurrence(from date: Date, routine: Routine) -> Date? {
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: date)
        
        // Check up to 365 days in the future (safety limit)
        for _ in 0..<365 {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            
            if isOccurrence(date: currentDate, routine: routine) {
                return currentDate
            }
        }
        
        return nil
    }
    
    /// Get all occurrences within a date range
    func occurrences(from startDate: Date, to endDate: Date, routine: Routine) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        var currentDate = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        while currentDate <= end {
            if isOccurrence(date: currentDate, routine: routine) {
                // Check if this instance has been modified
                let key = dateKey(currentDate)
                if let modification = routine.instanceModifications[key] {
                    if modification.isSkipped {
                        // Skip this occurrence
                    } else if let newDate = modification.newDate {
                        // Use rescheduled date
                        dates.append(newDate)
                    } else {
                        dates.append(currentDate)
                    }
                } else {
                    dates.append(currentDate)
                }
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates.sorted()
    }
    
    /// Check if a specific date is an occurrence based on the routine's rules
    func isOccurrence(date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        let checkDate = calendar.startOfDay(for: date)
        
        // Check if routine is active
        guard routine.isActive else { return false }
        
        // Check if before start date
        let routineStart = routine.startDate ?? routine.createdAt
        if checkDate < calendar.startOfDay(for: routineStart) {
            return false
        }
        
        // Check if after end date
        if let endDate = routine.endDate, checkDate > calendar.startOfDay(for: endDate) {
            return false
        }
        
        // Check if in exceptions list
        if routine.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: checkDate) }) {
            return false
        }
        
        // Check based on frequency
        switch routine.frequency {
        case .daily:
            return isDailyOccurrence(date: checkDate, routine: routine)
            
        case .weekly:
            return isWeeklyOccurrence(date: checkDate, routine: routine)
            
        case .monthly:
            return isMonthlyOccurrence(date: checkDate, routine: routine)
            
        case .custom:
            return isCustomOccurrence(date: checkDate, routine: routine)
        }
    }
    
    // MARK: - Frequency-Specific Checks
    
    private func isDailyOccurrence(date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        
        // Check weekdays only option
        if routine.weekdaysOnly {
            let weekday = calendar.component(.weekday, from: date)
            // 1 = Sunday, 7 = Saturday
            if weekday == 1 || weekday == 7 {
                return false
            }
        }
        
        // Check custom interval (every N days)
        if let intervalDays = routine.customIntervalDays, intervalDays > 1 {
            let routineStart = routine.startDate ?? routine.createdAt
            let daysSinceStart = calendar.dateComponents([.day], from: routineStart, to: date).day ?? 0
            return daysSinceStart >= 0 && daysSinceStart % intervalDays == 0
        }
        
        return true
    }
    
    private func isWeeklyOccurrence(date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        
        guard let activeDays = routine.activeDays, !activeDays.isEmpty else {
            return false
        }
        
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if this weekday is active (1=Sun, 2=Mon, ..., 7=Sat)
        guard activeDays.contains(weekday) else {
            return false
        }
        
        // Check week interval (every N weeks)
        if let weekInterval = routine.weekInterval, weekInterval > 1 {
            let routineStart = routine.startDate ?? routine.createdAt
            let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: routineStart, to: date).weekOfYear ?? 0
            return weeksSinceStart >= 0 && weeksSinceStart % weekInterval == 0
        }
        
        return true
    }
    
    private func isMonthlyOccurrence(date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        
        // Check month interval (every N months)
        if let monthInterval = routine.monthInterval, monthInterval > 1 {
            let routineStart = routine.startDate ?? routine.createdAt
            let monthsSinceStart = calendar.dateComponents([.month], from: routineStart, to: date).month ?? 0
            guard monthsSinceStart >= 0 && monthsSinceStart % monthInterval == 0 else {
                return false
            }
        }
        
        // Check if it's a specific week of the month (e.g., 2nd Monday)
        if let monthWeek = routine.monthWeek, let activeDays = routine.activeDays, !activeDays.isEmpty {
            return isWeekOfMonth(date: date, week: monthWeek, weekdays: activeDays)
        }
        
        // Otherwise, check if it's a specific day of the month
        if let activeDays = routine.activeDays, !activeDays.isEmpty {
            let day = calendar.component(.day, from: date)
            return activeDays.contains(day)
        }
        
        return false
    }
    
    private func isCustomOccurrence(date: Date, routine: Routine) -> Bool {
        let calendar = Calendar.current
        
        // Custom can be either:
        // 1. Specific weekdays (activeDays contains weekdays 1-7)
        // 2. Interval-based (customIntervalDays set, like "every 3 days")
        
        if let intervalDays = routine.customIntervalDays, intervalDays > 1 {
            // Interval-based: every N days from start date
            let routineStart = routine.startDate ?? routine.createdAt
            let daysSinceStart = calendar.dateComponents([.day], from: routineStart, to: date).day ?? 0
            return daysSinceStart >= 0 && daysSinceStart % intervalDays == 0
        } else if let activeDays = routine.activeDays, !activeDays.isEmpty {
            // Weekday-based: specific days of the week
            let weekday = calendar.component(.weekday, from: date)
            return activeDays.contains(weekday)
        }
        
        return false
    }
    
    // MARK: - Helper Methods
    
    /// Check if date is in a specific week of the month
    private func isWeekOfMonth(date: Date, week: Int, weekdays: [Int]) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        // Check if it's the correct weekday
        guard weekdays.contains(weekday) else {
            return false
        }
        
        // Get the week of month
        if week == -1 {
            // Last occurrence of this weekday in the month
            return isLastWeekdayOfMonth(date: date, weekday: weekday)
        } else {
            // Specific week (1st, 2nd, 3rd, 4th)
            let weekOfMonth = calendar.component(.weekOfMonth, from: date)
            return weekOfMonth == week
        }
    }
    
    /// Check if this is the last occurrence of a weekday in the month
    private func isLastWeekdayOfMonth(date: Date, weekday: Int) -> Bool {
        let calendar = Calendar.current
        
        // Get the next week's date
        guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: date) else {
            return false
        }
        
        // If next week is in a different month, this is the last occurrence
        let currentMonth = calendar.component(.month, from: date)
        let nextMonth = calendar.component(.month, from: nextWeek)
        
        return currentMonth != nextMonth
    }
    
    // MARK: - Instance Modifications
    
    /// Skip a specific instance of a recurring routine
    func skipInstance(date: Date, routine: Routine, reason: String? = nil) {
        let key = dateKey(date)
        var modifications = routine.instanceModifications
        modifications[key] = InstanceModification(
            instanceDate: date,
            isSkipped: true,
            reason: reason
        )
        routine.instanceModifications = modifications
    }
    
    /// Reschedule a specific instance to a new date
    func rescheduleInstance(from originalDate: Date, to newDate: Date, routine: Routine, reason: String? = nil) {
        let key = dateKey(originalDate)
        var modifications = routine.instanceModifications
        modifications[key] = InstanceModification(
            instanceDate: originalDate,
            newDate: newDate,
            reason: reason
        )
        routine.instanceModifications = modifications
    }
    
    /// Remove a modification (restore to original schedule)
    func removeModification(date: Date, routine: Routine) {
        let key = dateKey(date)
        var modifications = routine.instanceModifications
        modifications.removeValue(forKey: key)
        routine.instanceModifications = modifications
    }
    
    /// Add a date to exceptions list
    func addException(date: Date, routine: Routine) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        if !routine.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: startOfDay) }) {
            routine.exceptions.append(startOfDay)
        }
    }
    
    /// Remove a date from exceptions list
    func removeException(date: Date, routine: Routine) {
        let calendar = Calendar.current
        routine.exceptions.removeAll { calendar.isDate($0, inSameDayAs: date) }
    }
    
    // MARK: - Utilities
    
    /// Generate a unique key for a date (YYYY-MM-DD format)
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    /// Get a user-friendly description of the recurrence pattern
    func recurrenceDescription(for routine: Routine) -> String {
        switch routine.frequency {
        case .daily:
            if let days = routine.customIntervalDays, days > 1 {
                return "Every \(days) days"
            } else if routine.weekdaysOnly {
                return "Every weekday"
            } else {
                return "Every day"
            }
            
        case .weekly:
            let weekText = (routine.weekInterval ?? 1) > 1 ? "Every \(routine.weekInterval ?? 1) weeks" : "Every week"
            if let days = routine.activeDays, !days.isEmpty {
                let dayNames = days.map { dayName(for: $0) }.joined(separator: ", ")
                return "\(weekText) on \(dayNames)"
            }
            return weekText
            
        case .monthly:
            let monthText = (routine.monthInterval ?? 1) > 1 ? "Every \(routine.monthInterval ?? 1) months" : "Every month"
            
            if let week = routine.monthWeek, let days = routine.activeDays, !days.isEmpty {
                let weekText = weekOfMonthText(week)
                let dayNames = days.map { dayName(for: $0) }.joined(separator: ", ")
                return "\(monthText) on the \(weekText) \(dayNames)"
            } else if let days = routine.activeDays, !days.isEmpty {
                let dayNumbers = days.map { "\($0)" }.joined(separator: ", ")
                return "\(monthText) on day \(dayNumbers)"
            }
            return monthText
            
        case .custom:
            if let days = routine.customIntervalDays, days > 1 {
                return "Every \(days) days"
            } else if let activeDays = routine.activeDays, !activeDays.isEmpty {
                let dayNames = activeDays.map { dayName(for: $0) }.joined(separator: ", ")
                return "On \(dayNames)"
            }
            return "Custom schedule"
        }
    }
    
    private func dayName(for weekday: Int) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let index = (weekday - 1) % 7
        return names[index]
    }
    
    private func weekOfMonthText(_ week: Int) -> String {
        switch week {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        case 4: return "4th"
        case -1: return "last"
        default: return "\(week)th"
        }
    }
}
