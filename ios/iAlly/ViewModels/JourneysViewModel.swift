//
//  JourneysViewModel.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftUI
import SwiftData

/// ViewModel for Journeys view
/// Handles business logic and coordinates between UI and data layer
@MainActor
@Observable
final class JourneysViewModel {
    
    // MARK: - Dependencies
    
    private let repository: JourneyRepository
    private let taskRepository: TaskRepository
    
    // MARK: - Published State
    
    var journeys: [Journey] = []
    var isLoading = false
    var errorMessage: String?
    var filterStatus: JourneyFilterStatus = .all
    var showStats = true
    
    // MARK: - Computed Properties
    
    var filteredJourneys: [Journey] {
        switch filterStatus {
        case .all:
            return journeys
        case .active:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
                let completed = milestones.filter { $0.isCompleted }.count
                return completed > 0 && completed < milestones.count
            }
        case .completed:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
                return milestones.allSatisfy { $0.isCompleted }
            }
        case .notStarted:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return true }
                return milestones.allSatisfy { !$0.isCompleted }
            }
        }
    }
    
    /// Aggregate statistics for all journeys
    /// Calculations:
    /// - Active: Has some completed milestones but not all
    /// - Completed: All milestones are completed
    /// - Avg Progress: Sum of individual journey progress / total journeys
    /// Business Rule: Empty milestones array counts as not started
    var stats: JourneyStats {
        var active = 0
        var completed = 0
        var totalProgress = 0.0
        
        for journey in journeys {
            guard let milestones = journey.milestones, !milestones.isEmpty else { continue }
            let completedCount = milestones.filter { $0.isCompleted }.count
            let progress = Double(completedCount) / Double(milestones.count)
            totalProgress += progress
            
            if completedCount == milestones.count {
                completed += 1
            } else if completedCount > 0 {
                active += 1
            }
        }
        
        let avgProgress = journeys.isEmpty ? 0 : totalProgress / Double(journeys.count)
        
        return JourneyStats(
            total: journeys.count,
            active: active,
            completed: completed,
            avgProgress: avgProgress
        )
    }
    
    // MARK: - Initialization
    
    init(repository: JourneyRepository, taskRepository: TaskRepository) {
        self.repository = repository
        self.taskRepository = taskRepository
    }
    
    deinit {
        #if DEBUG
        print("🧹 JourneysViewModel deallocated")
        #endif
    }
    
    // MARK: - Public Methods
    
    func loadJourneys() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                journeys = try repository.fetchAll()
                    .sorted { $0.startDate > $1.startDate }
                isLoading = false
            } catch {
                errorMessage = "Failed to load journeys: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func createJourney(title: String, vision: String, targetDate: Date) {
        Task {
            do {
                let journey = Journey(
                    title: title,
                    vision: vision,
                    targetDate: targetDate
                )
                try repository.create(journey)
                loadJourneys()
            } catch {
                errorMessage = "Failed to create journey: \(error.localizedDescription)"
            }
        }
    }
    
    func updateJourney(_ journey: Journey) {
        Task {
            do {
                try repository.update(journey)
                loadJourneys()
            } catch {
                errorMessage = "Failed to update journey: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteJourney(_ journey: Journey) {
        Task {
            do {
                try repository.delete(journey)
                loadJourneys()
            } catch {
                errorMessage = "Failed to delete journey: \(error.localizedDescription)"
            }
        }
    }
    
    func completeJourney(_ journey: Journey) {
        Task {
            do {
                try repository.complete(journey)
                loadJourneys()
            } catch {
                errorMessage = "Failed to complete journey: \(error.localizedDescription)"
            }
        }
    }
    
    func archiveJourney(_ journey: Journey) {
        Task {
            do {
                try repository.archive(journey)
                loadJourneys()
            } catch {
                errorMessage = "Failed to archive journey: \(error.localizedDescription)"
            }
        }
    }
    
    func searchJourneys(query: String) {
        guard !query.isEmpty else {
            loadJourneys()
            return
        }
        
        Task {
            do {
                journeys = try repository.search(query: query)
                    .sorted { $0.startDate > $1.startDate }
            } catch {
                errorMessage = "Search failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Types

enum JourneyFilterStatus: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
    case notStarted = "Not Started"
}

struct JourneyStats {
    let total: Int
    let active: Int
    let completed: Int
    let avgProgress: Double
}
