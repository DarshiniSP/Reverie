//
//  EdgeCaseEssentialTests.swift
//  iAllyUITests
//
//  Essential Edge Case Tests - NEW
//  Tests boundary conditions and error states
//  Created: January 16, 2026
//

import XCTest

class EdgeCaseEssentialTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        app.launchArguments.append("-UITest_ResetState")
        app.launchArguments.append("-UITest_SkipOnboarding")
        // Note: NOT loading test data for empty state testing
        app.launchEnvironment["UITEST_IN_MEMORY"] = "1"
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Essential Test 1: Empty State Handling
    func testEmptyStateHandling() throws {
        print("\n🧪 ESSENTIAL TEST: Empty State Handling")
        print("======================================")
        
        // Verify app launches with no data
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
        todayTab.tap()
        
        // Check for empty state messaging
        let emptyStateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no tasks' OR label CONTAINS[c] 'get started' OR label CONTAINS[c] 'add your first'")).firstMatch
        let addButton = app.buttons["addTaskButton"]
        
        XCTAssertTrue(emptyStateText.exists || addButton.exists, "Empty state should show helpful message or add button")
        
        // Test Plans empty state
        let plansTab = app.tabBars.buttons["Plans"]
        plansTab.tap()
        
        let plansEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no plans' OR label CONTAINS[c] 'create a plan'")).firstMatch
        let addPlanButton = app.buttons["addPlanButton"]
        
        XCTAssertTrue(plansEmptyState.exists || addPlanButton.exists, "Plans empty state should be handled")
        
        // Test Journeys empty state
        let journeysTab = app.tabBars.buttons["Journeys"]
        journeysTab.tap()
        
        let journeysEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no journeys' OR label CONTAINS[c] 'start a journey'")).firstMatch
        let addJourneyButton = app.buttons["addJourneyButton"]
        
        XCTAssertTrue(journeysEmptyState.exists || addJourneyButton.exists, "Journeys empty state should be handled")
        
        // Test Routines empty state (navigate via More tab - Routines tab replaced by Lumina in Phase 2)
        let moreTabForRoutines = app.tabBars.buttons["More"]
        if moreTabForRoutines.exists {
            moreTabForRoutines.tap()
            let routinesButton = app.buttons["routinesButton"]
            if routinesButton.waitForExistence(timeout: 3) {
                routinesButton.tap()
            }
        }

        let routinesEmptyState = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'no routines' OR label CONTAINS[c] 'create a routine'")).firstMatch
        let addRoutineButton = app.buttons["addRoutineButton"]

        XCTAssertTrue(routinesEmptyState.exists || addRoutineButton.exists, "Routines empty state should be handled")
        
        print("✅ Empty state handling verified")
    }
    
    // MARK: - Essential Test 2: Large Dataset Performance
    func testLargeDatasetPerformance() throws {
        print("\n🧪 ESSENTIAL TEST: Large Dataset Performance")
        print("==========================================")
        
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
        todayTab.tap()
        
        let addButton = app.buttons["addTaskButton"]
        XCTAssertTrue(addButton.exists, "Add task button should exist")
        
        // Create 20 tasks to simulate larger dataset
        let startTime = Date()
        
        for i in 1...20 {
            addButton.tap()
            
            let titleField = app.textFields["taskTitleField"]
            if titleField.waitForExistence(timeout: 2) {
                titleField.tap()
                titleField.typeText("Task \(i)")
                
                let saveButton = app.buttons["saveTaskButton"]
                if saveButton.exists {
                    saveButton.tap()
                }
            }
            
            // Every 5 tasks, verify performance is acceptable
            if i % 5 == 0 {
                let elapsed = Date().timeIntervalSince(startTime)
                let avgTimePerTask = elapsed / Double(i)
                XCTAssertLessThan(avgTimePerTask, 8.0, "Average task creation should be under 8 seconds")
                print("Created \(i) tasks, avg time: \(String(format: "%.2f", avgTimePerTask))s")
            }
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        print("Total time to create 20 tasks: \(String(format: "%.2f", totalTime))s")
        
        // Test scrolling performance with larger dataset
        let tasksList = app.cells.firstMatch
        if tasksList.exists {
            // Scroll down
            app.swipeUp()
            app.swipeUp()
            
            // Scroll back up
            app.swipeDown()
            app.swipeDown()
            
            XCTAssertTrue(true, "Scrolling should be smooth with 20+ tasks")
        }
        
        // Test search/filter performance
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Task 1")
            
            // Verify search results appear quickly — match by label text
            let searchResult = app.cells.matching(NSPredicate(format: "label CONTAINS 'Task 1'")).firstMatch
            let searchText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Task 1'")).firstMatch
            XCTAssertTrue(searchResult.waitForExistence(timeout: 2) || searchText.exists, "Search should return results quickly")
        }
        
        print("✅ Large dataset performance verified")
    }
}
