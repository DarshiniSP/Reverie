//
//  SearchService.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import Foundation
import SwiftData

/// Advanced search service for tasks, journeys, plans, and routines
class SearchService {
    static let shared = SearchService()
    
    private init() {}
    
    // MARK: - Search
    
    /// Full-text search across all searchable content
    func search(query: String, in scope: SearchScope, context: ModelContext) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        let lowercasedQuery = query.lowercased()
        
        switch scope {
        case .all:
            results.append(contentsOf: searchTasks(query: lowercasedQuery, context: context))
            results.append(contentsOf: searchKnowledge(query: lowercasedQuery, context: context))
            results.append(contentsOf: searchJourneys(query: lowercasedQuery, context: context))
            results.append(contentsOf: searchPlans(query: lowercasedQuery, context: context))

        case .tasks:
            results = searchTasks(query: lowercasedQuery, context: context)

        case .knowledge:
            results = searchKnowledge(query: lowercasedQuery, context: context)

        case .journeys:
            results = searchJourneys(query: lowercasedQuery, context: context)

        case .plans:
            results = searchPlans(query: lowercasedQuery, context: context)

        case .memories:
            // PAI memory search is async — handled by SearchView directly.
            break
        }
        
        return results
    }
    
    /// Advanced search with filters
    func advancedSearch(filters: SearchFilters, context: ModelContext) -> [TaskWork] {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let tasks = try? context.fetch(descriptor) else { return [] }
        
        return tasks.filter { task in
            // Text query
            if let query = filters.textQuery, !query.isEmpty {
                let matchesTitle = task.title.localizedCaseInsensitiveContains(query)
                let matchesDetail = task.detail?.localizedCaseInsensitiveContains(query) ?? false
                if !matchesTitle && !matchesDetail {
                    return false
                }
            }
            
            // Date range
            if let dateRange = filters.dateRange, let dueDate = task.dueDate {
                if dueDate < dateRange.start || dueDate > dateRange.end {
                    return false
                }
            }
            
            // Tags
            if !filters.tags.isEmpty {
                let taskTags = Set(task.tags?.map { $0.id } ?? [])
                let filterTags = Set(filters.tags.map { $0.id })
                if taskTags.isDisjoint(with: filterTags) {
                    return false
                }
            }
            
            // Size
            if let size = filters.size, task.size != size {
                return false
            }
            
            // Energy
            if let energy = filters.energy, task.energy != energy {
                return false
            }
            
            // Completed status
            if let completed = filters.completed {
                let isCompleted = task.completedAt != nil
                if isCompleted != completed {
                    return false
                }
            }
            
            // Overdue
            if let overdue = filters.overdue, overdue {
                if !task.isOverdue {
                    return false
                }
            }
            
            return true
        }
    }
    
    // MARK: - Recent Searches
    
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 10
    
    /// Save a search query to recent searches
    func saveRecentSearch(_ query: String) {
        guard !query.isEmpty else { return }
        
        var recent = getRecentSearches()
        
        // Remove if already exists
        recent.removeAll { $0 == query }
        
        // Add to beginning
        recent.insert(query, at: 0)
        
        // Limit to max
        if recent.count > maxRecentSearches {
            recent = Array(recent.prefix(maxRecentSearches))
        }
        
        UserDefaults.standard.set(recent, forKey: recentSearchesKey)
    }
    
    /// Get recent searches
    func getRecentSearches() -> [String] {
        return UserDefaults.standard.stringArray(forKey: recentSearchesKey) ?? []
    }
    
    /// Clear all recent searches
    func clearRecentSearches() {
        UserDefaults.standard.removeObject(forKey: recentSearchesKey)
    }
    
    // MARK: - Private Search Methods
    
    private func searchTasks(query: String, context: ModelContext) -> [SearchResult] {
        let descriptor = FetchDescriptor<TaskWork>()
        guard let tasks = try? context.fetch(descriptor) else { return [] }
        
        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(query) ||
            (task.detail?.localizedCaseInsensitiveContains(query) ?? false)
        }.map { task in
            SearchResult(
                id: task.id,
                type: .task,
                title: task.title,
                subtitle: task.detail,
                icon: "checkmark.circle",
                colorHex: "#4C8BF5",
                relevantObject: task
            )
        }
    }
    
    private func searchJourneys(query: String, context: ModelContext) -> [SearchResult] {
        let descriptor = FetchDescriptor<Journey>()
        guard let journeys = try? context.fetch(descriptor) else { return [] }
        
        return journeys.filter { journey in
            journey.title.localizedCaseInsensitiveContains(query) ||
            (journey.vision?.localizedCaseInsensitiveContains(query) ?? false)
        }.map { journey in
            SearchResult(
                id: journey.id,
                type: .journey,
                title: journey.title,
                subtitle: journey.vision,
                icon: journey.icon,
                colorHex: journey.colorHex,
                relevantObject: journey
            )
        }
    }
    
    private func searchPlans(query: String, context: ModelContext) -> [SearchResult] {
        let descriptor = FetchDescriptor<Plan>()
        guard let plans = try? context.fetch(descriptor) else { return [] }
        
        return plans.filter { plan in
            plan.lifeDomain.rawValue.localizedCaseInsensitiveContains(query)
        }.map { plan in
            SearchResult(
                id: plan.id,
                type: .plan,
                title: plan.lifeDomain.rawValue,
                subtitle: "Life Domain Plan",
                icon: plan.lifeDomain.icon,
                colorHex: plan.colorHex,
                relevantObject: plan
            )
        }
    }
    
    private func searchRoutines(query: String, context: ModelContext) -> [SearchResult] {
        let descriptor = FetchDescriptor<Routine>()
        guard let routines = try? context.fetch(descriptor) else { return [] }

        return routines.filter { routine in
            routine.title.localizedCaseInsensitiveContains(query)
        }.map { routine in
            SearchResult(
                id: routine.id,
                type: .routine,
                title: routine.title,
                subtitle: routine.frequency.rawValue,
                icon: routine.icon,
                colorHex: routine.colorHex,
                relevantObject: routine
            )
        }
    }

    private func searchKnowledge(query: String, context: ModelContext) -> [SearchResult] {
        let descriptor = FetchDescriptor<Knowledge>()
        guard let items = try? context.fetch(descriptor) else { return [] }

        return items.filter { item in
            item.title.localizedCaseInsensitiveContains(query)
                || item.content.localizedCaseInsensitiveContains(query)
                || item.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }.map { item in
            SearchResult(
                id: item.id,
                type: .knowledge,
                title: item.title,
                subtitle: item.content.isEmpty ? nil : item.content,
                icon: item.itemType.icon,
                colorHex: item.itemType.colorHex,
                relevantObject: item
            )
        }
    }
}

// MARK: - Models

enum SearchScope: String, CaseIterable {
    case all = "All"
    case tasks = "Tasks"
    case knowledge = "Knowledge"
    case journeys = "Journeys"
    case plans = "Plans"
    case memories = "Memories"
}

struct SearchFilters {
    var textQuery: String?
    var dateRange: DateRange?
    var tags: [Tag]
    var size: TaskSize?
    var energy: TaskEnergy?
    var completed: Bool?
    var overdue: Bool?
    
    init(
        textQuery: String? = nil,
        dateRange: DateRange? = nil,
        tags: [Tag] = [],
        size: TaskSize? = nil,
        energy: TaskEnergy? = nil,
        completed: Bool? = nil,
        overdue: Bool? = nil
    ) {
        self.textQuery = textQuery
        self.dateRange = dateRange
        self.tags = tags
        self.size = size
        self.energy = energy
        self.completed = completed
        self.overdue = overdue
    }
    
    var hasActiveFilters: Bool {
        dateRange != nil || !tags.isEmpty || size != nil || 
        energy != nil || completed != nil || overdue != nil
    }
}

struct DateRange {
    let start: Date
    let end: Date
}

struct SearchResult: Identifiable {
    let id: UUID
    let type: SearchResultType
    let title: String
    let subtitle: String?
    let icon: String
    let colorHex: String
    let relevantObject: Any
}

enum SearchResultType {
    case task
    case journey
    case plan
    case routine
    case knowledge
    case memory
}
