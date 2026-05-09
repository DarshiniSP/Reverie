//
//  JourneyRepository.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Repository for Journey entity with domain-specific queries
final class JourneyRepository: BaseRepository<Journey> {
    
    // MARK: - Journey-Specific Queries
    
    /// Fetch active journeys
    func fetchActive() throws -> [Journey] {
        let allJourneys = try fetchAll()
        return allJourneys.filter { $0.status == .inProgress }
    }
    
    /// Fetch completed journeys
    func fetchCompleted() throws -> [Journey] {
        let allJourneys = try fetchAll()
        return allJourneys.filter { $0.status == .completed }
    }
    
    /// Fetch journeys approaching target date
    func fetchApproachingDeadline(within days: Int = 30) throws -> [Journey] {
        let activeJourneys = try fetchActive()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: Date())!
        
        return activeJourneys.filter { journey in
            guard let targetDate = journey.targetDate else { return false }
            return targetDate <= futureDate
        }
    }
    
    /// Fetch journeys with incomplete milestones
    func fetchWithIncompleteMilestones() throws -> [Journey] {
        let activeJourneys = try fetchActive()
        return activeJourneys.filter { journey in
            journey.milestones?.contains { !$0.isCompleted } ?? false
        }
    }
    
    /// Fetch journeys sorted by progress
    func fetchSortedByProgress() throws -> [Journey] {
        let activeJourneys = try fetchActive()
        return activeJourneys.sorted { $0.progress > $1.progress }
    }
    
    /// Fetch journeys sorted by target date
    func fetchSortedByTargetDate() throws -> [Journey] {
        let activeJourneys = try fetchActive()
        return activeJourneys.sorted { 
            guard let date1 = $0.targetDate, let date2 = $1.targetDate else { return false }
            return date1 < date2
        }
    }
    
    /// Search journeys by title or vision
    func search(query: String) throws -> [Journey] {
        guard !query.isEmpty else { return [] }
        
        let allJourneys = try fetchAll()
        let lowercasedQuery = query.lowercased()
        
        return allJourneys.filter { journey in
            journey.title.lowercased().contains(lowercasedQuery) ||
            (journey.vision?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    // MARK: - Statistics
    
    /// Count active journeys
    func countActive() throws -> Int {
        return try fetchActive().count
    }
    
    /// Count completed journeys
    func countCompleted() throws -> Int {
        return try fetchCompleted().count
    }
    
    /// Get average progress across all active journeys
    func getAverageProgress() throws -> Double {
        let activeJourneys = try fetchActive()
        guard !activeJourneys.isEmpty else { return 0 }
        
        let totalProgress = activeJourneys.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(activeJourneys.count)
    }
    
    /// Get journey with highest progress
    func getTopPerformer() throws -> Journey? {
        return try fetchSortedByProgress().first
    }
    
    /// Count total milestones across all journeys
    func countTotalMilestones() throws -> Int {
        let allJourneys = try fetchAll()
        return allJourneys.reduce(0) { $0 + ($1.milestones?.count ?? 0) }
    }
    
    /// Count completed milestones across all journeys
    func countCompletedMilestones() throws -> Int {
        let allJourneys = try fetchAll()
        return allJourneys.reduce(0) { count, journey in
            count + (journey.milestones?.filter { $0.isCompleted }.count ?? 0)
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Complete journey and all its milestones
    func complete(_ journey: Journey) throws {
        journey.status = .completed
        if let milestones = journey.milestones {
            for milestone in milestones where !milestone.isCompleted {
                milestone.completedAt = Date()
            }
        }
        try save()
    }
    
    /// Reactivate completed journey
    func reactivate(_ journey: Journey) throws {
        journey.status = .inProgress
        try save()
    }
    
    /// Archive journey and its tasks
    func archive(_ journey: Journey) throws {
        journey.status = .completed
        // Note: TaskWork model doesn't have isArchived property
        try save()
    }
}
