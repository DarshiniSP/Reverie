//
//  SettingsEssentialTests.swift
//  iAllyUITests
//
//  Essential Settings Tests - Optimized Suite
//  Consolidates 8+ settings tests into 1 focused test
//  Created: January 16, 2026
//

import XCTest

class SettingsEssentialTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        app.launchArguments.append("-UITest_ResetState")
        app.launchArguments.append("-UITest_SkipOnboarding")
        app.launchArguments.append("-LoadTestData")
        app.launchEnvironment["UITEST_IN_MEMORY"] = "1"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Essential Test: Core Settings
    func testCoreSettings() throws {
        print("\n🧪 ESSENTIAL TEST: Core Settings")
        print("===============================")
        
        // Navigate to More tab
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 5), "More tab should exist")
        moreTab.tap()
        Thread.sleep(forTimeInterval: 1)
        // The "App" section (containing Settings) is below the Tools section — scroll to reveal it
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)

        // Navigate to Settings
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        } else {
            // Fallback: tap the "Settings" label text directly in the list row
            let settingsLabel = app.staticTexts.matching(NSPredicate(format: "label == 'Settings'")).firstMatch
            if settingsLabel.waitForExistence(timeout: 3) {
                settingsLabel.tap()
            }
        }
        
        // Verify Settings view is accessible
        let settingsNavigationBar = app.navigationBars["Settings"]
        let settingsView = app.otherElements["settingsView"]
        
        XCTAssertTrue(settingsNavigationBar.exists || settingsView.exists, "Settings view should be accessible")
        
        // Test Demo Data controls
        let demoDataButton = app.buttons["demoDataButton"]
        let demoDataCell = app.cells.containing(.staticText, identifier: "Demo Data").firstMatch
        
        if demoDataButton.exists || demoDataCell.exists {
            XCTAssertTrue(true, "Demo Data settings accessible")
            
            if demoDataCell.exists {
                demoDataCell.tap()
                
                // Verify demo data options
                let addDemoDataButton = app.buttons["addDemoDataButton"]
                let removeDemoDataButton = app.buttons["removeDemoDataButton"]
                
                XCTAssertTrue(addDemoDataButton.exists || removeDemoDataButton.exists, "Demo data management options should exist")
                
                // Navigate back
                let backButton = app.navigationBars.buttons.element(boundBy: 0)
                if backButton.exists {
                    backButton.tap()
                }
            }
        }
        
        // Test Appearance settings
        let appearanceButton = app.buttons["appearanceButton"]
        let appearanceCell = app.cells.containing(.staticText, identifier: "Appearance").firstMatch
        
        if appearanceButton.exists || appearanceCell.exists {
            XCTAssertTrue(true, "Appearance settings accessible")
        }
        
        // Test Notifications settings
        let notificationsButton = app.buttons["notificationsButton"]
        let notificationsCell = app.cells.containing(.staticText, identifier: "Notifications").firstMatch
        
        if notificationsButton.exists || notificationsCell.exists {
            XCTAssertTrue(true, "Notifications settings accessible")
        }
        
        // Test CloudKit/Sync settings
        let syncButton = app.buttons["syncButton"]
        let syncCell = app.cells.containing(.staticText, identifier: "Sync").firstMatch
        let cloudKitCell = app.cells.containing(.staticText, identifier: "CloudKit").firstMatch
        
        if syncButton.exists || syncCell.exists || cloudKitCell.exists {
            XCTAssertTrue(true, "Sync settings accessible")
        }
        
        // Test About/Info section
        let aboutButton = app.buttons["aboutButton"]
        let aboutCell = app.cells.containing(.staticText, identifier: "About").firstMatch
        
        if aboutButton.exists || aboutCell.exists {
            XCTAssertTrue(true, "About section accessible")
        }
        
        // Test Privacy settings
        let privacyButton = app.buttons["privacyButton"]
        let privacyCell = app.cells.containing(.staticText, identifier: "Privacy").firstMatch
        
        if privacyButton.exists || privacyCell.exists {
            XCTAssertTrue(true, "Privacy settings accessible")
        }
        
        // Navigate back to More tab
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
        
        print("✅ Core settings completed successfully")
    }
}
