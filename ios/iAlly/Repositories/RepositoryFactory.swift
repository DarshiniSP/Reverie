//
//  RepositoryFactory.swift
//  iAlly
//
//  Created by Irigam Developer on 13/12/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Factory for creating repository instances
/// Provides centralized dependency injection for repositories
final class RepositoryFactory {
    
    private let context: ModelContext
    
    /// Initialize factory with model context
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Repository Creation
    
    /// Create or get TaskRepository instance
    func makeTaskRepository() -> TaskRepository {
        return TaskRepository(context: context)
    }
    
    /// Create or get PlanRepository instance
    func makePlanRepository() -> PlanRepository {
        return PlanRepository(context: context)
    }
    
    /// Create or get JourneyRepository instance
    func makeJourneyRepository() -> JourneyRepository {
        return JourneyRepository(context: context)
    }
    
    /// Create or get RoutineRepository instance
    func makeRoutineRepository() -> RoutineRepository {
        return RoutineRepository(context: context)
    }
    
    // MARK: - Convenience Methods
    
    /// Create all repositories at once
    func makeAllRepositories() -> Repositories {
        return Repositories(
            tasks: makeTaskRepository(),
            plans: makePlanRepository(),
            journeys: makeJourneyRepository(),
            routines: makeRoutineRepository()
        )
    }
}

/// Container for all repository instances
struct Repositories {
    let tasks: TaskRepository
    let plans: PlanRepository
    let journeys: JourneyRepository
    let routines: RoutineRepository
}

/// SwiftUI Environment key for RepositoryFactory
struct RepositoryFactoryKey: EnvironmentKey {
    static let defaultValue: RepositoryFactory? = nil
}

extension EnvironmentValues {
    var repositoryFactory: RepositoryFactory? {
        get { self[RepositoryFactoryKey.self] }
        set { self[RepositoryFactoryKey.self] = newValue }
    }
}

/// Convenience extension for easy repository access in Views
extension View {
    func repositoryFactory(_ factory: RepositoryFactory) -> some View {
        environment(\.repositoryFactory, factory)
    }
}
