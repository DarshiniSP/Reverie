//
//  iAllyWidgetBundle.swift
//  iAlly
//
//  Created on 12/11/2025.
//

import WidgetKit
import SwiftUI

@main
struct iAllyWidgetBundle: WidgetBundle {
    var body: some Widget {
        iAllyWidget()
        // P4-B: Lock screen widget (accessoryCircular / accessoryRectangular / accessoryInline)
        LockScreenWidget()
    }
}
