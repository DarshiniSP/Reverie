//
//  PlanRepository.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData

/// Repository for Plan entity with domain-specific queries
final class PlanRepository: BaseRepository<Plan> {
    
    // MARK: - Plan-Specific Queries
    
    /// Fetch active plans
    func fetchActive() throws -> [Plan] {
        let allPlans = try fetchAll()
        return allPlans.filter { $0.status == .active }
    }
    
    /// Fetch completed plans
    func fetchCompleted() throws -> [Plan] {
        let allPlans = try fetchAll()
        return allPlans.filter { $0.status == .archived }
    }
    
    /// Fetch plans by life domain
    func fetch(byLifeDomain domain: LifeDomain) throws -> [Plan] {
        let allPlans = try fetchAll()
        return allPlans.filter { $0.lifeDomain == domain }
    }
    
    /// Fetch plans with incomplete tasks
    func fetchWithIncompleteTasks() throws -> [Plan] {
        let activePlans = try fetchActive()
        return activePlans.filter { plan in
            plan.tasks?.contains { $0.completedAt == nil } ?? false
        }
    }
    
    /// Fetch plans sorted by progress
    func fetchSortedByProgress() throws -> [Plan] {
        let activePlans = try fetchActive()
        return activePlans.sorted(by: { $0.completionRate > $1.completionRate })
    }
    
    /// Search plans by name or goal
    func search(query: String) throws -> [Plan] {
        guard !query.isEmpty else { return [] }
        
        let allPlans = try fetchAll()
        let lowercasedQuery = query.lowercased()
        
        return allPlans.filter { plan in
            plan.name.lowercased().contains(lowercasedQuery) ||
            (plan.goal?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }
    
    // MARK: - Statistics
    
    /// Count active plans
    func countActive() throws -> Int {
        return try fetchActive().count
    }
    
    /// Count completed plans
    func countCompleted() throws -> Int {
        return try fetchCompleted().count
    }
    
    /// Get average progress across all active plans
    func getAverageProgress() throws -> Double {
        let activePlans = try fetchActive()
        guard !activePlans.isEmpty else { return 0 }
        
        let totalProgress = activePlans.reduce(into: 0.0) { $0 += $1.completionRate }
        return totalProgress / Double(activePlans.count)
    }
    
    /// Get plan with highest progress
    func getTopPerformer() throws -> Plan? {
        return try fetchSortedByProgress().first
    }
    
    // MARK: - Bulk Operations
    
    /// Archive plan and its tasks
    func archive(_ plan: Plan) throws {
        plan.status = .archived
        // Note: TaskWork model doesn't have isArchived property
        try save()
    }
    
    /// Reactivate an archived plan by setting its status back to `.active`.
    /// Use Case: Seasonal goals, recurring projects
    func reactivate(_ plan: Plan) throws {
        plan.status = .active
        try save()
    }
    
    /// Update plan progress (recalculates based on tasks)
    func updateProgress(_ plan: Plan) throws {
        // Progress is a computed property, so just save
        try update(plan)
    }
}
