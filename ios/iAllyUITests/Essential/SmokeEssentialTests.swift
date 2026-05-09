//
//  SmokeEssentialTests.swift
//  iAllyUITests
//
//  Essential Smoke Tests - Optimized Suite
//  Consolidates 5+ smoke tests into 1 focused test
//  Created: January 16, 2026
//

import XCTest

class SmokeEssentialTests: XCTestCase {
    
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
    
    // MARK: - Essential Test: App Launch and Basic Flow
    func testAppLaunchAndBasicFlow() throws {
        print("\n🧪 ESSENTIAL TEST: App Launch and Basic Flow")
        print("===========================================")
        
        // Verify app launched successfully
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
        
        // Verify main UI elements exist
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist after launch")
        
        // Verify all 5 tabs are present
        let todayTab = tabBar.buttons["Today"]
        let plansTab = tabBar.buttons["Plans"]
        let journeysTab = tabBar.buttons["Journeys"]
        let luminaTab = tabBar.buttons["Lumina"]
        let moreTab = tabBar.buttons["More"]

        XCTAssertTrue(todayTab.exists, "Today tab should exist")
        XCTAssertTrue(plansTab.exists, "Plans tab should exist")
        XCTAssertTrue(journeysTab.exists, "Journeys tab should exist")
        XCTAssertTrue(luminaTab.exists, "Lumina tab should exist")
        XCTAssertTrue(moreTab.exists, "More tab should exist")

        // Test basic navigation flow
        todayTab.tap()
        XCTAssertTrue(app.navigationBars["Today"].exists || app.staticTexts["Today"].exists, "Today view should load")

        plansTab.tap()
        XCTAssertTrue(app.navigationBars["Plans"].exists || app.staticTexts["Plans"].exists, "Plans view should load")

        journeysTab.tap()
        XCTAssertTrue(app.navigationBars["Journeys"].exists || app.staticTexts["Journeys"].exists, "Journeys view should load")

        luminaTab.tap()
        XCTAssertTrue(app.navigationBars["Lumina"].exists || app.staticTexts["Lumina"].exists, "Lumina view should load")

        moreTab.tap()
        XCTAssertTrue(app.navigationBars["More"].exists || app.staticTexts["More"].exists, "More view should load")
        
        // Test basic task creation flow
        todayTab.tap()
        
        let addButton = app.buttons["addTaskButton"]
        if addButton.exists {
            addButton.tap()
            
            let titleField = app.textFields["taskTitleField"]
            XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Task creation view should open")
            
            titleField.tap()
            titleField.typeText("Smoke Test Task")
            
            let saveButton = app.buttons["saveTaskButton"]
            if saveButton.exists {
                saveButton.tap()

                // Task created from Today segment gets defaultDueDate = Date() (today),
                // so it lands in the Today segment — no segment switch needed.
                let taskCell = app.buttons["taskCell_Smoke Test Task"]
                XCTAssertTrue(taskCell.waitForExistence(timeout: 10), "Created task should appear")
            }
        }
        
        // Test app doesn't crash during basic operations
        XCTAssertTrue(app.state == .runningForeground, "App should still be running after basic operations")
        
        // Test memory pressure handling
        for _ in 1...3 {
            todayTab.tap()
            plansTab.tap()
            journeysTab.tap()
            luminaTab.tap()
            moreTab.tap()
        }
        
        XCTAssertTrue(app.state == .runningForeground, "App should handle rapid navigation without crashing")
        
        print("✅ App launch and basic flow completed successfully")
    }
}
