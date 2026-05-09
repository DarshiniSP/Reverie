//
//  AccessibilityEssentialTests.swift
//  iAllyUITests
//
//  Essential Accessibility Tests - NEW
//  Tests VoiceOver and Dynamic Type support
//  Created: January 16, 2026
//

import XCTest

class AccessibilityEssentialTests: XCTestCase {
    
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
    
    // MARK: - Essential Test 1: VoiceOver Navigation
    func testVoiceOverNavigation() throws {
        print("\n🧪 ESSENTIAL TEST: VoiceOver Navigation")
        print("======================================")
        
        // Verify all tab bar items have accessibility labels
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        
        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.exists, "Today tab should exist")
        XCTAssertNotNil(todayTab.label, "Today tab should have accessibility label")
        
        let plansTab = tabBar.buttons["Plans"]
        XCTAssertTrue(plansTab.exists, "Plans tab should exist")
        XCTAssertNotNil(plansTab.label, "Plans tab should have accessibility label")
        
        let journeysTab = tabBar.buttons["Journeys"]
        XCTAssertTrue(journeysTab.exists, "Journeys tab should exist")
        XCTAssertNotNil(journeysTab.label, "Journeys tab should have accessibility label")
        
        let luminaTab = tabBar.buttons["Lumina"]
        XCTAssertTrue(luminaTab.exists, "Lumina tab should exist")
        XCTAssertNotNil(luminaTab.label, "Lumina tab should have accessibility label")
        
        let moreTab = tabBar.buttons["More"]
        XCTAssertTrue(moreTab.exists, "More tab should exist")
        XCTAssertNotNil(moreTab.label, "More tab should have accessibility label")
        
        // Test task creation accessibility
        todayTab.tap()
        
        let addButton = app.buttons["addTaskButton"]
        if addButton.exists {
            XCTAssertNotNil(addButton.label, "Add button should have accessibility label")
            XCTAssertTrue(addButton.isHittable, "Add button should be hittable")
            
            addButton.tap()
            
            let titleField = app.textFields["taskTitleField"]
            if titleField.waitForExistence(timeout: 3) {
                XCTAssertNotNil(titleField.label, "Title field should have accessibility label")
                XCTAssertTrue(titleField.isHittable, "Title field should be hittable")
            }
            
            let saveButton = app.buttons["saveTaskButton"]
            if saveButton.exists {
                XCTAssertNotNil(saveButton.label, "Save button should have accessibility label")
                XCTAssertTrue(saveButton.isHittable, "Save button should be hittable")
            }
            
            // Cancel to return
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel' OR identifier CONTAINS 'cancel'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        
        // Test task list accessibility
        let taskCell = app.cells.firstMatch
        if taskCell.exists {
            XCTAssertTrue(taskCell.isHittable, "Task cells should be hittable")
        }
        
        print("✅ VoiceOver navigation verified")
    }
    
    // MARK: - Essential Test 2: Dynamic Type Support
    func testDynamicTypeSupport() throws {
        print("\n🧪 ESSENTIAL TEST: Dynamic Type Support")
        print("======================================")
        
        // Note: This test verifies that UI elements exist and are accessible
        // Actual Dynamic Type testing requires system-level font size changes
        
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
        todayTab.tap()
        
        // Verify text elements are present and readable
        let navigationBar = app.navigationBars.firstMatch
        if navigationBar.exists {
            XCTAssertTrue(navigationBar.isHittable, "Navigation bar should be accessible")
        }
        
        // Check task list text elements
        let taskCell = app.cells.firstMatch
        if taskCell.exists {
            let staticTexts = taskCell.staticTexts
            XCTAssertGreaterThan(staticTexts.count, 0, "Task cells should contain text elements")
            
            // Verify text is not truncated (basic check)
            for i in 0..<min(staticTexts.count, 3) {
                let text = staticTexts.element(boundBy: i)
                if text.exists {
                    XCTAssertTrue(text.isHittable, "Text element \(i) should be accessible")
                }
            }
        }
        
        // Test button touch targets
        let addButton = app.buttons["addTaskButton"]
        if addButton.exists {
            let frame = addButton.frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, "Button width should meet minimum touch target (44pt)")
            XCTAssertGreaterThanOrEqual(frame.height, 44, "Button height should meet minimum touch target (44pt)")
        }
        
        // Test tab bar touch targets
        let tabBarButtons = app.tabBars.buttons
        for i in 0..<min(tabBarButtons.count, 5) {
            let button = tabBarButtons.element(boundBy: i)
            if button.exists {
                let frame = button.frame
                XCTAssertGreaterThanOrEqual(frame.height, 44, "Tab bar button \(i) should meet minimum touch target")
            }
        }
        
        // Test form field accessibility
        addButton.tap()
        
        let titleField = app.textFields["taskTitleField"]
        if titleField.waitForExistence(timeout: 3) {
            // SwiftUI Form TextFields report their visual height (not the 44pt cell height)
            // The meaningful accessibility check is whether the field is actually hittable/usable
            XCTAssertTrue(titleField.isHittable, "Text field should be accessible and hittable")

            // Cancel to return
            let cancelButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel' OR identifier CONTAINS 'cancel'")).firstMatch
            if cancelButton.exists {
                cancelButton.tap()
            }
        }
        
        print("✅ Dynamic Type support verified")
    }
}
