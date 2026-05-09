//
//  TagManager.swift
//  iAlly
//
//  Created by Irigam Developer on 11/12/25.
//

import Foundation
import SwiftData

/// Manages Tag CRUD operations and provides helper methods
class TagManager {
    static let shared = TagManager()
    
    private init() {}
    
    // MARK: - Create
    
    /// Create a new tag
    func createTag(name: String, colorHex: String, icon: String, in modelContext: ModelContext) -> Tag {
        let tag = Tag(name: name, colorHex: colorHex, icon: icon)
        modelContext.insert(tag)
        try? modelContext.save()
        return tag
    }
    
    // MARK: - Read
    
    /// Fetch all tags sorted by name
    func fetchAllTags(from modelContext: ModelContext) -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch tags with tasks
    func fetchTagsWithTasks(from modelContext: ModelContext) -> [Tag] {
        let allTags = fetchAllTags(from: modelContext)
        return allTags.filter { ($0.taskCount) > 0 }
    }
    
    /// Search tags by name
    func searchTags(query: String, in modelContext: ModelContext) -> [Tag] {
        let allTags = fetchAllTags(from: modelContext)
        if query.isEmpty {
            return allTags
        }
        return allTags.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    // MARK: - Update
    
    /// Update tag properties
    func updateTag(_ tag: Tag, name: String?, colorHex: String?, icon: String?, in modelContext: ModelContext) {
        if let name = name {
            tag.name = name
        }
        if let colorHex = colorHex {
            tag.colorHex = colorHex
        }
        if let icon = icon {
            tag.icon = icon
        }
        try? modelContext.save()
    }
    
    // MARK: - Delete
    
    /// Delete a tag (removes tag from all tasks)
    func deleteTag(_ tag: Tag, from modelContext: ModelContext) {
        // Remove tag from all tasks
        if let tasks = tag.tasks {
            for task in tasks {
                task.tags?.removeAll { $0.id == tag.id }
            }
        }
        
        modelContext.delete(tag)
        try? modelContext.save()
    }
    
    // MARK: - Task-Tag Operations
    
    /// Add tag to task
    func addTag(_ tag: Tag, to task: TaskWork, in modelContext: ModelContext) {
        if task.tags == nil {
            task.tags = []
        }
        
        // Check if tag already exists
        guard !(task.tags?.contains { $0.id == tag.id } ?? false) else { return }
        
        task.tags?.append(tag)
        try? modelContext.save()
    }
    
    /// Remove tag from task
    func removeTag(_ tag: Tag, from task: TaskWork, in modelContext: ModelContext) {
        task.tags?.removeAll { $0.id == tag.id }
        try? modelContext.save()
    }
    
    /// Toggle tag on task (add if not present, remove if present)
    func toggleTag(_ tag: Tag, on task: TaskWork, in modelContext: ModelContext) {
        if task.tags?.contains(where: { $0.id == tag.id }) ?? false {
            removeTag(tag, from: task, in: modelContext)
        } else {
            addTag(tag, to: task, in: modelContext)
        }
    }
    
    // MARK: - Predefined Tags
    
    /// Create default tags for new users
    func createDefaultTags(in modelContext: ModelContext) {
        for (name, color, icon) in Defaults.defaultTags {
            _ = createTag(name: name, colorHex: color, icon: icon, in: modelContext)
        }
    }
}
