//
//  DataExportService.swift
//  iAlly
//
//  Created on 16/12/2025.
//

import SwiftUI
import SwiftData

struct DataExportService {
    let context: ModelContext
    
    // MARK: - Export Logic
    
    func export() throws -> URL {
        // Fetch all data
        let tasks = try context.fetch(FetchDescriptor<TaskWork>())
        let journeys = try context.fetch(FetchDescriptor<Journey>())
        let plans = try context.fetch(FetchDescriptor<Plan>())
        let routines = try context.fetch(FetchDescriptor<Routine>())
        
        // Map to DTOs
        let exportData = ExportDataDTO(
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            tasks: tasks.map { TaskExportDTO(from: $0) },
            journeys: journeys.map { JourneyExportDTO(from: $0) },
            plans: plans.map { PlanExportDTO(from: $0) },
            routines: routines.map { RoutineExportDTO(from: $0) }
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(exportData)
        
        // Save to temporary file
        // Use ISO8601 Date Formatter for consistent, safe filenames
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let fileName = "iAlly_Backup_\(dateString).json"
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempUrl)
        
        return tempUrl
    }
}

// MARK: - DTOs

struct ExportDataDTO: Codable {
    let timestamp: Date
    let appVersion: String
    let tasks: [TaskExportDTO]
    let journeys: [JourneyExportDTO]
    let plans: [PlanExportDTO]
    let routines: [RoutineExportDTO]
}

struct TaskExportDTO: Codable {
    let id: UUID
    let title: String
    let detail: String?
    let createdAt: Date
    let dueDate: Date?
    let completedAt: Date?
    let isCompleted: Bool
    let energy: String?
    let size: String
    let priority: String?
    let planName: String?
    let journeyName: String?
    
    init(from task: TaskWork) {
        self.id = task.id
        self.title = task.title
        self.detail = task.detail
        self.createdAt = task.createdAt
        self.dueDate = task.dueDate
        self.completedAt = task.completedAt
        self.isCompleted = task.isCompleted
        self.energy = task.energy?.rawValue
        self.size = task.size.rawValue
        self.priority = task.priority?.rawValue
        self.planName = task.plan?.name
        self.journeyName = task.journey?.title
    }
}

struct JourneyExportDTO: Codable {
    let id: UUID
    let title: String
    let vision: String?
    let status: String?
    let targetDate: Date?
    let milestones: [MilestoneExportDTO]
    
    init(from journey: Journey) {
        self.id = journey.id
        self.title = journey.title
        self.vision = journey.vision
        self.status = journey.status?.rawValue
        self.targetDate = journey.targetDate
        self.milestones = journey.milestones?.map { MilestoneExportDTO(from: $0) } ?? []
    }
}

struct MilestoneExportDTO: Codable {
    let title: String
    let targetDate: Date?
    let isCompleted: Bool
    
    init(from milestone: Milestone) {
        self.title = milestone.title
        self.targetDate = milestone.targetDate
        self.isCompleted = milestone.isCompleted
    }
}

struct PlanExportDTO: Codable {
    let id: UUID
    let name: String
    let lifeDomain: String
    let goal: String?
    let status: String?
    
    init(from plan: Plan) {
        self.id = plan.id
        self.name = plan.name
        self.lifeDomain = plan.lifeDomain.rawValue
        self.goal = plan.goal
        self.status = plan.status?.rawValue
    }
}

struct RoutineExportDTO: Codable {
    let id: UUID
    let title: String
    let frequency: String
    let completionRate: Double
    let currentStreak: Int
    
    init(from routine: Routine) {
        self.id = routine.id
        self.title = routine.title
        self.frequency = routine.frequency.rawValue
        self.completionRate = routine.completionRate
        self.currentStreak = routine.currentStreak
    }
}
