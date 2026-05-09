//
//  KnowledgeRepository.swift
//  iAlly
//
//  Phase 2: Capture & Knowledge Layer
//  CRUD for the Knowledge SwiftData model.  Every insert also fires a
//  fire-and-forget PAI semantic memory write via PAIMemoryBridge.
//

import Foundation
import SwiftData

final class KnowledgeRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    @discardableResult
    func create(
        title: String,
        content: String,
        type: KnowledgeItemType,
        tags: [String] = [],
        source: String? = nil
    ) throws -> Knowledge {
        let item = Knowledge(title: title, content: content, type: type, tags: tags, source: source)
        context.insert(item)
        try context.save()

        // Record knowledge in local memory for Lumina context
        PAIMemoryBridge.shared.recordKnowledge(
            content: "\(title): \(content)",
            type: KnowledgeType(rawValue: type.rawValue) ?? .insight,
            tags: tags
        )

        return item
    }

    // MARK: - Read

    func fetchAll(sortBy: KnowledgeSortOption = .newest) throws -> [Knowledge] {
        var descriptor = FetchDescriptor<Knowledge>()
        switch sortBy {
        case .newest:
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        case .oldest:
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .forward)]
        case .title:
            descriptor.sortBy = [SortDescriptor(\.title)]
        }
        return try context.fetch(descriptor)
    }

    func fetch(type: KnowledgeItemType) throws -> [Knowledge] {
        let raw = type.rawValue
        let descriptor = FetchDescriptor<Knowledge>(
            predicate: #Predicate { $0.typeRaw == raw },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func search(query: String) throws -> [Knowledge] {
        let lowered = query.lowercased()
        let all = try fetchAll()
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(lowered)
            || $0.content.localizedCaseInsensitiveContains(lowered)
            || $0.tags.contains { $0.localizedCaseInsensitiveContains(lowered) }
        }
    }

    // MARK: - Update

    func update(_ item: Knowledge, title: String? = nil, content: String? = nil, tags: [String]? = nil) throws {
        if let title { item.title = title }
        if let content { item.content = content }
        if let tags { item.tags = tags }
        item.updatedAt = Date()
        try context.save()
    }

    // MARK: - Delete

    func delete(_ item: Knowledge) throws {
        context.delete(item)
        try context.save()
    }
}

// MARK: - Sort option

enum KnowledgeSortOption: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case title  = "Title"
}
