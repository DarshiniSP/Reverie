//
//  OptimizedOnboardingHelper.swift
//  iAllyUITests
//
//  Created by QA Engineer Agent on 2026-01-08
//  Optimized onboarding flow with better error handling and timing
//

import XCTest

class OptimizedOnboardingHelper {
    let app: XCUIApplication
    
    init(app: XCUIApplication) {
        self.app = app
    }
    
    // MARK: - Onboarding Flow
    
    func completeOnboardingFlow() -> Bool {
        print("📱 Executing Optimized Onboarding Flow...")
        
        // Define onboarding screens in order
        let onboardingScreens: [(title: String, buttonText: String)] = [
            ("Your Private Ally", "Next"),
            ("Balance Your Life", "Next"),
            ("Build Lasting Habits", "Next"),
            ("Achieve Big Goals", "Next"),
            ("Master Your Time", "Get Started")
        ]
        
        // Process each onboarding screen
        for (index, screen) in onboardingScreens.enumerated() {
            if !processOnboardingScreen(
                screenTitle: screen.title,
                buttonText: screen.buttonText,
                screenNumber: index + 1,
                totalScreens: onboardingScreens.count
            ) {
                print("❌ Failed to process onboarding screen: \(screen.title)")
                return false
            }
        }
        
        // Handle iOS notification permission prompt
        if !handleNotificationPermission() {
            print("⚠️ Notification permission handling failed")
            // Don't fail the test for this - it's optional
        }
        
        // Verify we reach the main app
        return verifyMainAppReached()
    }
    
    // MARK: - Private Helper Methods
    
    private func processOnboardingScreen(
        screenTitle: String,
        buttonText: String,
        screenNumber: Int,
        totalScreens: Int
    ) -> Bool {
        print("📄 Processing screen \(screenNumber)/\(totalScreens): \(screenTitle)")
        
        // Wait for screen title to appear
        let titleElement = app.staticTexts[screenTitle]
        guard titleElement.waitForExistence(timeout: 10) else {
            print("❌ Screen title not found: \(screenTitle)")
            return false
        }
        
        // Wait for button to appear
        let button = app.buttons[buttonText]
        guard button.waitForExistence(timeout: 5) else {
            print("❌ Button not found: \(buttonText)")
            return false
        }
        
        // Tap the button
        button.tap()
        
        // Brief wait for transition
        Thread.sleep(forTimeInterval: 0.5)
        
        print("✅ Successfully processed: \(screenTitle)")
        return true
    }
    
    private func handleNotificationPermission() -> Bool {
        print("🔔 Checking for notification permission prompt...")
        
        let allowButton = app.buttons["Allow"]
        let dontAllowButton = app.buttons["Don't Allow"]
        
        // Wait briefly for permission prompt
        if allowButton.waitForExistence(timeout: 5) {
            print("✅ Notification permission prompt appeared - allowing")
            allowButton.tap()
            return true
        } else if dontAllowButton.waitForExistence(timeout: 2) {
            print("ℹ️ Notification permission prompt appeared - declining")
            dontAllowButton.tap()
            return true
        } else {
            print("ℹ️ No notification permission prompt appeared")
            return true // Not an error
        }
    }
    
    private func verifyMainAppReached() -> Bool {
        print("🏠 Verifying main app is reached...")
        
        // Check for tab bar (primary indicator)
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 10) {
            print("✅ Tab bar found - main app reached")
            return true
        }
        
        // Fallback: Check for Today button
        let todayButton = app.buttons["Today"]
        if todayButton.waitForExistence(timeout: 5) {
            print("✅ Today button found - main app reached")
            return true
        }
        
        // Fallback: Check for add task button
        let addTaskButton = app.buttons["addTaskButton"]
        if addTaskButton.waitForExistence(timeout: 5) {
            print("✅ Add task button found - main app reached")
            return true
        }
        
        print("❌ Main app not reached - no expected elements found")
        return false
    }
    
    // MARK: - Skip Onboarding (for tests that don't need it)
    
    func skipOnboardingIfPresent() -> Bool {
        print("⏭️ Attempting to skip onboarding if present...")
        
        // Check if we're already in the main app
        if app.tabBars.firstMatch.exists {
            print("ℹ️ Already in main app - no onboarding needed")
            return true
        }
        
        // Check for skip button first (fastest method)
        let skipButton = app.buttons["skipOnboardingButton"]
        if skipButton.waitForExistence(timeout: 3) {
            print("✅ Skip button found - using skip functionality")
            skipButton.tap()
            
            // Wait for main app to appear
            if app.tabBars.firstMatch.waitForExistence(timeout: 10) {
                print("✅ Successfully skipped onboarding - main app reached")
                return true
            }
        }
        
        // Fallback: If onboarding is present but no skip button, complete it normally
        let firstOnboardingScreen = app.staticTexts["Your Private Ally"]
        if firstOnboardingScreen.waitForExistence(timeout: 3) {
            print("📱 Onboarding detected without skip button - completing flow")
            return completeOnboardingFlow()
        }
        
        print("ℹ️ No onboarding detected")
        return true
    }
    
    // MARK: - Validation Methods
    
    func isOnboardingComplete() -> Bool {
        return app.tabBars.firstMatch.exists || 
               app.buttons["Today"].exists ||
               app.buttons["addTaskButton"].exists
    }
    
    func getCurrentOnboardingScreen() -> String? {
        let onboardingTitles = [
            "Your Private Ally",
            "Balance Your Life", 
            "Build Lasting Habits",
            "Achieve Big Goals",
            "Master Your Time"
        ]
        
        for title in onboardingTitles {
            if app.staticTexts[title].exists {
                return title
            }
        }
        
        return nil
    }
}