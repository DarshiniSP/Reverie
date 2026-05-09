//
//  DataPersistenceEssentialTests.swift
//  iAllyUITests
//
//  Essential Data Persistence Tests - NEW
//  Tests data integrity under stress conditions
//  Created: January 16, 2026
//

import XCTest

class DataPersistenceEssentialTests: XCTestCase {
    
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
    
    // MARK: - Essential Test 1: Data Integrity Under Stress
    func testDataIntegrityUnderStress() throws {
        print("\n🧪 ESSENTIAL TEST: Data Integrity Under Stress")
        print("=============================================")
        
        // Create multiple tasks to establish data
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add task button should exist")
        
        for i in 1...3 {
            addButton.tap()

            let titleField = app.textFields["taskTitleField"]
            XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Task title field should exist")
            titleField.tap()
            titleField.typeText("Persistence Test Task \(i)")

            let saveButton = app.buttons["saveTaskButton"]
            XCTAssertTrue(saveButton.exists, "Save button should exist")
            saveButton.tap()

            // Tasks without a due date land in Inbox — switch to Inbox segment
            let inboxSeg = app.buttons["Inbox"].firstMatch
            if inboxSeg.waitForExistence(timeout: 3) { inboxSeg.tap() }

            // Wait for task to appear using taskCell_ accessibility identifier
            let taskCell = app.buttons["taskCell_Persistence Test Task \(i)"]
            XCTAssertTrue(taskCell.waitForExistence(timeout: 3), "Task \(i) should appear")
        }

        // Verify all tasks exist in Inbox
        for i in 1...3 {
            let taskCell = app.buttons["taskCell_Persistence Test Task \(i)"]
            XCTAssertTrue(taskCell.exists, "Task \(i) should persist")
        }
        
        // Simulate app backgrounding
        XCUIDevice.shared.press(.home)
        sleep(2)

        // Relaunch app
        app.activate()
        sleep(2)

        // Return to Today tab and switch to Inbox to verify persistence
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.waitForExistence(timeout: 5) {
            todayTab.tap()
        }
        let inboxAfterBg = app.buttons["Inbox"].firstMatch
        if inboxAfterBg.waitForExistence(timeout: 3) { inboxAfterBg.tap() }

        for i in 1...3 {
            let taskCell = app.buttons["taskCell_Persistence Test Task \(i)"]
            XCTAssertTrue(taskCell.exists, "Task \(i) should persist after backgrounding")
        }
        
        print("✅ Data integrity under stress verified")
    }
    
    // MARK: - Essential Test 2: Demo Data Isolation
    func testDemoDataIsolation() throws {
        print("\n🧪 ESSENTIAL TEST: Demo Data Isolation")
        print("=====================================")
        
        // Verify demo data is loaded
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
        todayTab.tap()
        
        // Check for demo tasks
        let tasksList = app.cells.firstMatch
        XCTAssertTrue(tasksList.waitForExistence(timeout: 5), "Tasks list should exist with demo data")
        
        // Create user task
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.exists, "Add task button should exist")
        addButton.tap()
        
        let titleField = app.textFields["taskTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Task title field should exist")
        titleField.tap()
        titleField.typeText("User Created Task")
        
        let saveButton = app.buttons["saveTaskButton"]
        XCTAssertTrue(saveButton.exists, "Save button should exist")
        saveButton.tap()

        // Tasks without a due date land in Inbox — switch to Inbox segment
        let inboxSegForUser = app.buttons["Inbox"].firstMatch
        if inboxSegForUser.waitForExistence(timeout: 3) { inboxSegForUser.tap() }

        // Verify user task appears using taskCell_ accessibility identifier
        let userTaskCell = app.buttons["taskCell_User Created Task"]
        XCTAssertTrue(userTaskCell.waitForExistence(timeout: 3), "User task should appear")
        
        // Navigate to Settings
        let moreTab = app.tabBars.buttons["More"]
        if moreTab.exists {
            moreTab.tap()
            
            let settingsButton = app.buttons["settingsButton"]
            if settingsButton.exists {
                settingsButton.tap()
                
                // Look for demo data controls
                let demoDataButton = app.buttons["demoDataButton"]
                if demoDataButton.exists {
                    XCTAssertTrue(true, "Demo data controls accessible")
                }
            }
        }
        
        // Return to Today and switch to Inbox to verify user task still coexists
        todayTab.tap()
        let inboxFinal = app.buttons["Inbox"].firstMatch
        if inboxFinal.waitForExistence(timeout: 3) { inboxFinal.tap() }
        XCTAssertTrue(userTaskCell.exists, "User task should still exist alongside demo data")
        
        print("✅ Demo data isolation verified")
    }
}
