//  Created by Irigam Developer on 11/12/25.
//

import Intents
import os.log

class IntentHandler: INExtension, AddTaskIntentIntentHandling {
    
    private let log = OSLog(subsystem: "com.irigam.iAlly.iAllyIntents", category: "IntentHandler")
    
    override func handler(for intent: INIntent) -> Any {
        return self
    }
    
    // MARK: - Title Resolution
    
    func resolveTitle(for intent: AddTaskIntentIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        guard let title = intent.title, !title.isEmpty else {
            completion(.needsValue())
            return
        }
        completion(.success(with: title))
    }
    
    // MARK: - Task Size Resolution
    
    func resolveTaskSize(for intent: AddTaskIntentIntent, with completion: @escaping (EnumResolutionResult) -> Void) {
        let size = intent.taskSize
        if size != .unknown {
            completion(.success(with: size))
        } else {
            completion(.success(with: .medium))
        }
    }
    
    // MARK: - Due Date Resolution
    
    func resolveDueDate(for intent: AddTaskIntentIntent, with completion: @escaping (INDateComponentsResolutionResult) -> Void) {
        if let dueDate = intent.dueDate {
            completion(.success(with: dueDate))
        } else {
            completion(.notRequired())
        }
    }
    
    // MARK: - Task Detail Resolution
    
    func resolveTaskDetail(for intent: AddTaskIntentIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let detail = intent.taskDetail {
            completion(.success(with: detail))
        } else {
            completion(.notRequired())
        }
    }
    
    // MARK: - Confirmation
    
    func confirm(intent: AddTaskIntentIntent, completion: @escaping (AddTaskIntentIntentResponse) -> Void) {
        guard let title = intent.title, !title.isEmpty else {
            completion(AddTaskIntentIntentResponse(code: .failure, userActivity: nil))
            return
        }
        completion(AddTaskIntentIntentResponse(code: .ready, userActivity: nil))
    }
    
    // MARK: - Handle Intent
    
    func handle(intent: AddTaskIntentIntent, completion: @escaping (AddTaskIntentIntentResponse) -> Void) {
        os_log("🎯 IntentHandler.handle called with title: %@", log: log, type: .info, intent.title ?? "nil")
        
        guard let title = intent.title, !title.isEmpty else {
            os_log("❌ Title is empty or nil", log: log, type: .error)
            completion(AddTaskIntentIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Convert intent parameters to task data
        let taskData = ShortcutTaskData(
            title: title,
            detail: intent.taskDetail,
            dueDate: intent.dueDate?.date,
            size: mapTaskSize(intent.taskSize)
        )
        
        os_log("📝 Created task data: title=%@, detail=%@, size=%@", 
               log: log, type: .info,
               taskData.title,
               taskData.detail ?? "nil",
               taskData.size.rawValue)
        
        // Store in App Groups for main app to process
        if let encoded = try? JSONEncoder().encode(taskData),
           let defaults = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly") {
            
            defaults.set(encoded, forKey: "pendingShortcutTask")
            defaults.synchronize()
            
            os_log("✅ Successfully saved to App Groups UserDefaults", log: log, type: .info)
            
            // Create user activity to open the app
            let userActivity = NSUserActivity(activityType: "AddTaskIntent")
            userActivity.userInfo = ["source": "shortcut"]
            if let url = URL(string: "iAlly://task/created") {
                userActivity.webpageURL = url
            }
            
            let response = AddTaskIntentIntentResponse(code: .success, userActivity: userActivity)
            response.userActivity = userActivity
            completion(response)
        } else {
            os_log("❌ Failed to encode or access App Groups", log: log, type: .error)
            completion(AddTaskIntentIntentResponse(code: .failure, userActivity: nil))
        }
    }
    
    // MARK: - Helper
    
    private func mapTaskSize(_ size: Enum) -> TaskSize {
        switch size {
        case .small:
            return .small
        case .large:
            return .large
        case .medium, .unknown:
            return .medium
        @unknown default:
            return .medium
        }
    }
}

// MARK: - Task Size Enum (Mirror from main app)
enum TaskSize: String, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
}

// MARK: - Shortcut Task Data
struct ShortcutTaskData: Codable {
    let title: String
    let detail: String?
    let dueDate: Date?
    let size: TaskSize
}
