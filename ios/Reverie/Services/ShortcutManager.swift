//
//  ShortcutManager.swift
//  iAlly
//
//  Created by Irigam Developer on 11/12/25.
//

import Foundation
import Intents
import SwiftData

/// Manages Siri Shortcuts integration and donation
class ShortcutManager {
    static let shared = ShortcutManager()
    
    private init() {}
    
    // MARK: - Shortcut Donation
    
    /// Donate task creation shortcut to Siri for learning user patterns
    /// Note: Requires proper Intent definition file to work
    func donateTaskCreationShortcut(title: String, size: TaskSize? = nil) {
        // This would create and donate an INShortcut
        // Requires .intentdefinition file with AddTaskIntent
        
        let userActivity = NSUserActivity(activityType: "com.irigam.iAlly.addTask")
        userActivity.title = "Add Task: \(title)"
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPrediction = true
        userActivity.persistentIdentifier = "addTask-\(title)"
        
        userActivity.suggestedInvocationPhrase = "Add \(title) to iAlly"
        
        // Donate to system
        userActivity.becomeCurrent()
    }
    
    /// Donate frequently used task patterns
    func donateCommonTaskShortcuts() {
        let commonTasks = [
            ("Buy groceries", TaskSize.medium),
            ("Call someone", TaskSize.small),
            ("Review daily goals", TaskSize.small),
            ("Exercise", TaskSize.medium)
        ]
        
        for (title, size) in commonTasks {
            donateTaskCreationShortcut(title: title, size: size)
        }
    }
    
    // MARK: - Process Pending Shortcut Task
    
    /// Check for pending task from Siri Shortcut and create it
    func processPendingShortcutTaskWork(in modelContext: ModelContext) -> TaskWork? {
        if FeatureFlags.debugMode {
        print("🔍 ShortcutManager: Checking for pending shortcut task...")
        }
        
        guard let defaults = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly") else {
            if FeatureFlags.debugMode {
            print("❌ ShortcutManager: Failed to access App Groups UserDefaults")
            }
            return nil
        }
        
        guard let data = defaults.data(forKey: "pendingShortcutTask") else {
            if FeatureFlags.debugMode {
            print("ℹ️ ShortcutManager: No pending shortcut task found")
            }
            return nil
        }
        
        if FeatureFlags.debugMode {
        print("✅ ShortcutManager: Found pending task data, size: \(data.count) bytes")
        }
        
        guard let taskData = try? JSONDecoder().decode(ShortcutTaskData.self, from: data) else {
            if FeatureFlags.debugMode {
            print("❌ ShortcutManager: Failed to decode task data")
            }
            return nil
        }
        
        if FeatureFlags.debugMode {
        print("📝 ShortcutManager: Decoded task - title: \(taskData.title), size: \(taskData.size)")
        }
        
        // Create task
        let task = TaskWork(
            title: taskData.title,
            detail: taskData.detail,
            dueDate: taskData.dueDate,
            energy: nil,
            size: taskData.size
        )
        
        modelContext.insert(task)
        
        do {
            try modelContext.save()
            if FeatureFlags.debugMode {
            print("✅ ShortcutManager: Successfully saved task to SwiftData")
            }
            
            // Clear pending task
            defaults.removeObject(forKey: "pendingShortcutTask")
            defaults.synchronize()
            if FeatureFlags.debugMode {
            print("🧹 ShortcutManager: Cleared pending task from UserDefaults")
            }
            
            return task
        } catch {
            if FeatureFlags.debugMode {
            print("❌ ShortcutManager: Failed to save task: \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Suggested Shortcuts
    
    /// Get relevant shortcuts based on user context
    func getSuggestedShortcuts() -> [INVoiceShortcut] {
        // This would return personalized shortcuts based on user's most common tasks
        return []
    }
}

// MARK: - Shortcut Task Data Model

struct ShortcutTaskData: Codable {
    let title: String
    let detail: String?
    let dueDate: Date?
    let size: TaskSize
}

