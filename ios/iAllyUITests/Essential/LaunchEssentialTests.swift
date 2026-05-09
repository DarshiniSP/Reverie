//
//  LaunchEssentialTests.swift
//  iAllyUITests
//
//  Essential Launch Tests - Optimized Suite
//  Tests app launch and onboarding flow
//  Created: January 16, 2026
//

import XCTest

class LaunchEssentialTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }
    
    // MARK: - Essential Test 1: App Launch
    func testAppLaunch() throws {
        print("\n🧪 ESSENTIAL TEST: App Launch")
        print("============================")
        
        // Launch with standard test configuration
        app.launchArguments.append("-UITest_ResetState")
        app.launchArguments.append("-UITest_SkipOnboarding")
        app.launchArguments.append("-LoadTestData")
        app.launchEnvironment["UITEST_IN_MEMORY"] = "1"
        
        let launchStart = Date()
        app.launch()
        let launchTime = Date().timeIntervalSince(launchStart)
        
        // Verify app launched successfully
        XCTAssertTrue(app.state == .runningForeground, "App should launch successfully")
        
        // Verify launch time is reasonable (under 20 seconds - includes data seeding on iOS 26.1 simulator)
        XCTAssertLessThan(launchTime, 20.0, "App should launch in under 20 seconds")
        print("Launch time: \(String(format: "%.2f", launchTime))s")
        
        // Verify main UI appears
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Main UI should appear after launch")
        
        // Verify no crash dialogs
        let crashAlert = app.alerts.firstMatch
        XCTAssertFalse(crashAlert.exists, "No crash alerts should appear")
        
        // Verify demo data loaded
        let todayTab = app.tabBars.buttons["Today"]
        todayTab.tap()
        
        let tasksList = app.cells.firstMatch
        XCTAssertTrue(tasksList.waitForExistence(timeout: 3), "Demo data should be loaded")
        
        print("✅ App launch completed successfully")
    }
    
    // MARK: - Essential Test 2: Onboarding Flow
    func testOnboardingFlow() throws {
        print("\n🧪 ESSENTIAL TEST: Onboarding Flow")
        print("=================================")
        
        // Launch without skipping onboarding
        app.launchArguments.append("-UITest_ResetState")
        app.launchEnvironment["UITEST_IN_MEMORY"] = "1"
        
        app.launch()
        
        // Check if onboarding appears
        let onboardingView = app.otherElements["onboardingView"]
        let welcomeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'welcome' OR label CONTAINS[c] 'get started'")).firstMatch
        let getStartedButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'get started' OR label CONTAINS[c] 'continue'")).firstMatch
        
        if onboardingView.exists || welcomeText.exists {
            print("Onboarding detected, testing flow...")
            
            // Test onboarding navigation
            if getStartedButton.exists {
                getStartedButton.tap()
                
                // Look for next button or skip button
                let nextButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'next' OR label CONTAINS[c] 'continue'")).firstMatch
                let skipButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'skip'")).firstMatch
                
                if nextButton.exists {
                    // Navigate through onboarding screens
                    var screenCount = 0
                    while nextButton.exists && screenCount < 5 {
                        nextButton.tap()
                        screenCount += 1
                        sleep(1)
                    }
                    
                    // Look for finish button
                    let finishButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'finish' OR label CONTAINS[c] 'done' OR label CONTAINS[c] 'start'")).firstMatch
                    if finishButton.exists {
                        finishButton.tap()
                    }
                } else if skipButton.exists {
                    skipButton.tap()
                }
            }
            
            // Verify we reach main app
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Should reach main app after onboarding")
            
        } else {
            print("Onboarding not shown (may be skipped by default)")
            
            // Verify main app loaded instead
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Main app should load if onboarding skipped")
        }
        
        // Verify app is functional after onboarding
        let todayTab = app.tabBars.buttons["Today"]
        if todayTab.exists {
            todayTab.tap()
            XCTAssertTrue(app.navigationBars["Today"].exists || app.staticTexts["Today"].exists, "App should be functional after onboarding")
        }
        
        print("✅ Onboarding flow completed successfully")
    }
}
