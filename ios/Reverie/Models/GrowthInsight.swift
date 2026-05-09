//
//  GrowthInsight.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import Foundation
import SwiftData

@Model
final class GrowthInsight {
    var id: UUID = UUID()
    var insightText: String = ""
    var confidenceScore: Double = 0.0 // 0.0 to 1.0
    var insightType: InsightType = InsightType.motivational
    var generatedDate: Date = Date()
    var isRead: Bool = false
    
    // Demo data flag
    var isDemo: Bool = false // True if this is demo data that can be removed
    
    // Relationships - CloudKit requires inverse relationships
    @Relationship(deleteRule: .nullify, inverse: \MindsetEvent.relatedInsights) var relatedEvents: [MindsetEvent]?
    
    init(
        id: UUID = UUID(),
        insightText: String,
        confidenceScore: Double,
        insightType: InsightType,
        generatedDate: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.insightText = insightText
        self.confidenceScore = confidenceScore
        self.insightType = insightType
        self.generatedDate = generatedDate
        self.isRead = isRead
    }
}

// MARK: - Insight Type
enum InsightType: String, Codable, CaseIterable {
    case timePattern = "Time Pattern"
    case energyPattern = "Energy Pattern"
    case sizePattern = "Size Pattern"
    case recoveryPattern = "Recovery Pattern"
    case streakPattern = "Streak Pattern"
    case domainPattern = "Domain Pattern"
    case motivational = "Motivational"
    case warning = "Warning"
    
    var icon: String {
        switch self {
        case .timePattern: return "clock.fill"
        case .energyPattern: return "bolt.fill"
        case .sizePattern: return "square.stack.fill"
        case .recoveryPattern: return "arrow.uturn.forward.circle.fill"
        case .streakPattern: return "flame.fill"
        case .domainPattern: return "square.grid.2x2"
        case .motivational: return "star.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .timePattern, .energyPattern, .sizePattern: return "blue"
        case .recoveryPattern, .streakPattern: return "green"
        case .domainPattern: return "purple"
        case .motivational: return "yellow"
        case .warning: return "orange"
        }
    }
}
