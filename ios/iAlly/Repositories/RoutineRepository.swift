//
//  RoutineRepository.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

typealias RoutineFrequency = RecurrenceFrequency

/// Repository for Routine entity with domain-specific queries
final class RoutineRepository: BaseRepository<Routine> {
    
    // MARK: - Routine-Specific Queries
    
    /// Fetch active routines
    func fetchActive() throws -> [Routine] {
        let allRoutines = try fetchAll()
        return allRoutines.filter { $0.isActive }
    }
    
    /// Fetch routines by frequency
    func fetch(byFrequency frequency: RoutineFrequency) throws -> [Routine] {
        let allRoutines = try fetchAll()
        return allRoutines.filter { $0.frequency == frequency }
    }
    
    /// Fetch routines with active streaks
    func fetchWithActiveStreaks() throws -> [Routine] {
        let activeRoutines = try fetchActive()
        return activeRoutines.filter { $0.currentStreak > 0 }
    }
    
    /// Fetch routines sorted by streak (highest first)
    func fetchSortedByStreak() throws -> [Routine] {
        let activeRoutines = try fetchActive()
        return activeRoutines.sorted { $0.currentStreak > $1.currentStreak }
    }
    
    /// Fetch routines sorted by best streak
    func fetchSortedByBestStreak() throws -> [Routine] {
        let activeRoutines = try fetchActive()
        return activeRoutines.sorted(by: { $0.longestStreak > $1.longestStreak })
    }
    
    /// Search routines by title
    func search(query: String) throws -> [Routine] {
        guard !query.isEmpty else { return [] }
        
        let allRoutines = try fetchAll()
        let lowercasedQuery = query.lowercased()
        
        return allRoutines.filter { routine in
            routine.title.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Statistics
    
    /// Count active routines
    func countActive() throws -> Int {
        return try fetchActive().count
    }
    
    /// Get total completion rate across all routines
    func getTotalCompletionRate() throws -> Double {
        let allRoutines = try fetchAll()
        guard !allRoutines.isEmpty else { return 0 }
        
        let totalRate = allRoutines.reduce(0.0) { $0 + $1.completionRate }
        return totalRate / Double(allRoutines.count)
    }
    
    /// Get average current streak
    func getAverageStreak() throws -> Double {
        let activeRoutines = try fetchActive()
        guard !activeRoutines.isEmpty else { return 0 }
        
        let totalStreak = activeRoutines.reduce(0) { $0 + $1.currentStreak }
        return Double(totalStreak) / Double(activeRoutines.count)
    }
    
    /// Get routine with longest current streak
    func getTopStreakRoutine() throws -> Routine? {
        return try fetchSortedByStreak().first
    }
    
    /// Get routine with best all-time streak
    func getBestStreakRoutine() throws -> Routine? {
        return try fetchSortedByBestStreak().first
    }
    
    /// Get completion statistics for a date range
    func getCompletionStats(from startDate: Date, to endDate: Date) throws -> RoutineCompletionStats {
        let allRoutines = try fetchAll()
        var totalChecked = 0
        var totalPossible = 0
        
        for routine in allRoutines {
            let completions = routine.completionDates.filter { completion in
                completion >= startDate && completion <= endDate
            }
            totalChecked += completions.count
            
            // Calculate possible completions based on frequency
            let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            switch routine.frequency {
            case .daily:
                totalPossible += days
            case .weekly:
                totalPossible += days / 7
            case .monthly:
                totalPossible += days / 30
            case .custom:
                // For custom, assume weekly
                totalPossible += days / 7
            }
        }
        
        let rate = totalPossible > 0 ? Double(totalChecked) / Double(totalPossible) * 100 : 0
        
        return RoutineCompletionStats(
            totalChecked: totalChecked,
            totalPossible: totalPossible,
            completionRate: rate
        )
    }
    
    // MARK: - Bulk Operations
    
    /// Pause routine
    /// Business Rule: Sets currentStreak = 0, preserves longestStreak
    /// Use Case: User missed multiple days and wants fresh start
    /// Note: Does NOT modify lastCompletedDate
    func resetStreak(_ routine: Routine) throws {
        routine.currentStreak = 0
        try save()
    }
    
    /// Deactivate routine
    func deactivate(_ routine: Routine) throws {
        routine.isActive = false
        try save()
    }
    
    /// Reactivate routine
    func reactivate(_ routine: Routine) throws {
        routine.isActive = true
        try save()
    }
    
    /// Archive old completions (cleanup)
    func archiveCompletions(olderThan date: Date) throws {
        let allRoutines = try fetchAll()
        
        for routine in allRoutines {
            routine.completionDates = routine.completionDates.filter { $0 >= date }
        }
        
        try save()
    }
}

// MARK: - Supporting Models

struct RoutineCompletionStats {
    let totalChecked: Int
    let totalPossible: Int
    let completionRate: Double
}
