//
//  WidgetHelper.swift
//  iAlly
//
//  Created on 12/11/2025.
//

import Foundation
import WidgetKit

/// Helper class to manage widget updates
class WidgetHelper {
    static let shared = WidgetHelper()
    
    private init() {}
    
    /// Reload all widgets
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    /// Reload specific widget
    func reloadWidget(kind: String = "iAllyWidget") {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
    
    /// Get current widget configurations
    func getCurrentConfigurations(completion: @escaping ([WidgetInfo]) -> Void) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let infos):
                completion(infos)
            case .failure:
                completion([])
            }
        }
    }
}
