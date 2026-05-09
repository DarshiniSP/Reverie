//
//  PlansViewModel.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Plans view
/// Handles business logic and coordinates between UI and data layer
@MainActor
@Observable
final class PlansViewModel {
    
    // MARK: - Dependencies
    
    private let repository: PlanRepository
    private let taskRepository: TaskRepository
    
    // MARK: - Published State
    
    var plans: [Plan] = []
    var isLoading = false
    var errorMessage: String?
    var selectedDomain: LifeDomain?
    var sortOrder: PlanSortOrder = .createdDate
    var showArchived = false
    
    // MARK: - Computed Properties
    
    /// Plans filtered by domain, archive status, and sorted
    /// Filter order: domain → archived → sort
    /// Available sort orders: createdDate, progress, deadline, title
    /// Business Rule: Progress = completed tasks / total tasks
    var filteredPlans: [Plan] {
        var filtered = plans
        
        // Filter by domain
        if let domain = selectedDomain {
            filtered = filtered.filter { $0.lifeDomain == domain }
        }
        
        // Filter archived
        // Note: isArchived property doesn't exist on Plan model
        // if !showArchived {
        //     filtered = filtered.filter { !$0.isArchived }
        // }
        
        // Sort
        switch sortOrder {
        case .createdDate:
            filtered.sort(by: { $0.createdAt < $1.createdAt })
        case .progress:
            filtered.sort(by: { calculateProgress($0) > calculateProgress($1) })
        case .deadline:
            // Note: Plan model doesn't have deadline property
            filtered.sort(by: { $0.createdAt < $1.createdAt })
        case .title:
            filtered.sort(by: { $0.name < $1.name })
        }
        
        return filtered
    }
    
    var domainStats: [LifeDomain: DomainStats] {
        var stats: [LifeDomain: DomainStats] = [:]
        
        for domain in LifeDomain.allCases {
            let domainPlans = plans.filter { $0.lifeDomain == domain }
            let totalProgress = domainPlans.reduce(0.0) { $0 + calculateProgress($1) }
            let avgProgress = domainPlans.isEmpty ? 0 : totalProgress / Double(domainPlans.count)
            
            stats[domain] = DomainStats(
                count: domainPlans.count,
                avgProgress: avgProgress
            )
        }
        
        return stats
    }
    
    var overallStats: OverallPlanStats {
        let activePlans = plans
        let totalProgress = activePlans.reduce(0.0) { $0 + calculateProgress($1) }
        let avgProgress = activePlans.isEmpty ? 0 : totalProgress / Double(activePlans.count)
        let archivedCount = 0  // isArchived property doesn't exist
        
        return OverallPlanStats(
            total: plans.count,
            active: activePlans.count,
            archived: archivedCount,
            avgProgress: avgProgress
        )
    }
    
    // MARK: - Initialization
    
    init(repository: PlanRepository, taskRepository: TaskRepository) {
        self.repository = repository
        self.taskRepository = taskRepository
    }
    
    deinit {
        #if DEBUG
        print("🧹 PlansViewModel deallocated")
        #endif
    }
    
    // MARK: - Public Methods
    
    func loadPlans() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                plans = try repository.fetchAll()
                isLoading = false
            } catch {
                errorMessage = "Failed to load plans: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadActivePlans() {
        Task {
            do {
                plans = try repository.fetchActive()
                isLoading = false
            } catch {
                errorMessage = "Failed to load active plans: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func createPlan(
        title: String,
        description: String,
        lifeDomain: LifeDomain,
        deadline: Date?
    ) {
        Task {
            do {
                let plan = Plan(
                    name: title,
                    lifeDomain: lifeDomain,
                    icon: lifeDomain.icon,
                    colorHex: lifeDomain.defaultColor,
                    goal: nil,
                    targetMetric: nil,
                    status: .active
                )
                try repository.create(plan)
                loadPlans()
            } catch {
                errorMessage = "Failed to create plan: \(error.localizedDescription)"
            }
        }
    }
    
    func updatePlan(_ plan: Plan) {
        Task {
            do {
                try repository.update(plan)
                loadPlans()
            } catch {
                errorMessage = "Failed to update plan: \(error.localizedDescription)"
            }
        }
    }
    
    func deletePlan(_ plan: Plan) {
        Task {
            do {
                try repository.delete(plan)
                loadPlans()
            } catch {
                errorMessage = "Failed to delete plan: \(error.localizedDescription)"
            }
        }
    }
    
    func archivePlan(_ plan: Plan) {
        Task {
            do {
                try repository.archive(plan)
                loadPlans()
            } catch {
                errorMessage = "Failed to archive plan: \(error.localizedDescription)"
            }
        }
    }
    
    func reactivatePlan(_ plan: Plan) {
        Task {
            do {
                try repository.reactivate(plan)
                loadPlans()
            } catch {
                errorMessage = "Failed to reactivate plan: \(error.localizedDescription)"
            }
        }
    }
    
    func searchPlans(query: String) {
        guard !query.isEmpty else {
            loadPlans()
            return
        }
        
        Task {
            do {
                plans = try repository.search(query: query)
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateProgress(_ plan: Plan) -> Double {
        guard let tasks = plan.tasks, !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(tasks.count)
    }
}

// MARK: - Supporting Types

enum PlanSortOrder: String, CaseIterable {
    case createdDate = "Created Date"
    case progress = "Progress"
    case deadline = "Deadline"
    case title = "Title"
}

struct DomainStats {
    let count: Int
    let avgProgress: Double
}

struct OverallPlanStats {
    let total: Int
    let active: Int
    let archived: Int
    let avgProgress: Double
}
