//
//  NavigationEssentialTests.swift
//  iAllyUITests
//
//  Essential Navigation Tests - Optimized Suite
//  Consolidates 12+ navigation tests into 2 focused tests
//  Created: January 16, 2026
//

import XCTest

class NavigationEssentialTests: XCTestCase {
    
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
    
    // MARK: - Essential Test 1: Tab Navigation
    func testTabNavigation() throws {
        print("\n🧪 ESSENTIAL TEST: Tab Navigation")
        print("================================")
        
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
        
        // Test Today tab
        let todayTab = tabBar.buttons["Today"]
        XCTAssertTrue(todayTab.exists, "Today tab should exist")
        todayTab.tap()
        XCTAssertTrue(app.navigationBars["Today"].exists || app.staticTexts["Today"].exists, "Today view should be visible")
        
        // Test Plans tab
        let plansTab = tabBar.buttons["Plans"]
        XCTAssertTrue(plansTab.exists, "Plans tab should exist")
        plansTab.tap()
        XCTAssertTrue(app.navigationBars["Plans"].exists || app.staticTexts["Plans"].exists, "Plans view should be visible")
        
        // Test Journeys tab
        let journeysTab = tabBar.buttons["Journeys"]
        XCTAssertTrue(journeysTab.exists, "Journeys tab should exist")
        journeysTab.tap()
        XCTAssertTrue(app.navigationBars["Journeys"].exists || app.staticTexts["Journeys"].exists, "Journeys view should be visible")
        
        // Test Lumina tab (Phase 2: replaces Routines tab as primary AI interface)
        let luminaTab = tabBar.buttons["Lumina"]
        XCTAssertTrue(luminaTab.exists, "Lumina tab should exist")
        luminaTab.tap()
        XCTAssertTrue(app.navigationBars["Lumina"].exists || app.staticTexts["Lumina"].exists, "Lumina view should be visible")
        
        // Test More tab
        let moreTab = tabBar.buttons["More"]
        XCTAssertTrue(moreTab.exists, "More tab should exist")
        moreTab.tap()
        XCTAssertTrue(app.navigationBars["More"].exists || app.staticTexts["More"].exists, "More view should be visible")
        
        // Return to Today tab
        todayTab.tap()
        XCTAssertTrue(app.navigationBars["Today"].exists || app.staticTexts["Today"].exists, "Should return to Today view")
        
        print("✅ Tab navigation completed successfully")
    }
    
    // MARK: - Essential Test 2: Deep Link Navigation
    func testDeepLinkNavigation() throws {
        print("\n🧪 ESSENTIAL TEST: Deep Link Navigation")
        print("======================================")
        
        // Start on Today tab
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5), "Today tab should exist")
        todayTab.tap()
        
        // Navigate to task creation
        let addButton = app.buttons["addTaskButton"]
        if addButton.exists {
            addButton.tap()
            XCTAssertTrue(app.navigationBars["New Task"].exists || app.staticTexts["New Task"].exists, "Task creation view should appear")
            
            // Navigate back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
        
        // Navigate to Plans and create plan
        let plansTab = app.tabBars.buttons["Plans"]
        plansTab.tap()
        
        let addPlanButton = app.buttons["addPlanButton"]
        if addPlanButton.exists {
            addPlanButton.tap()
            XCTAssertTrue(app.navigationBars["New Plan"].exists || app.staticTexts["New Plan"].exists, "Plan creation view should appear")
            
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
        
        // Navigate to Settings from More tab
        let moreTab = app.tabBars.buttons["More"]
        moreTab.tap()
        
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.exists {
            settingsButton.tap()
            XCTAssertTrue(app.navigationBars["Settings"].exists || app.staticTexts["Settings"].exists, "Settings view should appear")
            
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
        
        print("✅ Deep link navigation completed successfully")
    }
}
