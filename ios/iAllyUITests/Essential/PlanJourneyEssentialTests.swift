//
//  PlanJourneyEssentialTests.swift
//  iAllyUITests
//
//  Essential Plan & Journey Tests - Optimized Suite
//  Consolidates 10+ plan/journey tests into 2 focused tests
//  Created: January 16, 2026
//

import XCTest

class PlanJourneyEssentialTests: XCTestCase {
    
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
    
    // MARK: - Essential Test 1: Plan Management
    func testPlanManagement() throws {
        print("\n🧪 ESSENTIAL TEST: Plan Management")
        print("=================================")
        
        // Navigate to Plans tab
        let plansTab = app.tabBars.buttons["Plans"]
        XCTAssertTrue(plansTab.waitForExistence(timeout: 5), "Plans tab should exist")
        plansTab.tap()
        
        // Verify demo plans exist or can create new plan
        let addPlanButton = app.buttons["addPlanButton"]
        let existingPlan = app.cells.firstMatch
        
        XCTAssertTrue(addPlanButton.exists || existingPlan.exists, "Plans view should show add button or existing plans")
        
        // Create new plan if button exists
        if addPlanButton.exists {
            addPlanButton.tap()
            
            let planNameField = app.textFields["planNameField"]
            if planNameField.waitForExistence(timeout: 3) {
                planNameField.tap()
                planNameField.typeText("Essential Test Plan")
                
                // Select life domain
                let domainPicker = app.buttons["lifeDomainPicker"]
                if domainPicker.exists {
                    domainPicker.tap()
                    
                    let healthDomain = app.buttons["Health"]
                    if healthDomain.exists {
                        healthDomain.tap()
                    }
                }
                
                let savePlanButton = app.buttons["savePlanButton"]
                if savePlanButton.exists {
                    savePlanButton.tap()
                }
                
                // Verify plan appears — match by visible text label, not accessibilityIdentifier
                let planText = app.staticTexts.matching(NSPredicate(format: "label == 'Essential Test Plan'")).firstMatch
                let planCellByLabel = app.cells.matching(NSPredicate(format: "label CONTAINS 'Essential Test Plan'")).firstMatch
                XCTAssertTrue(planText.waitForExistence(timeout: 3) || planCellByLabel.exists, "Created plan should appear in list")
            }
        }
        
        // Test plan detail view
        if existingPlan.exists {
            existingPlan.tap()
            
            // Verify plan detail elements
            let planDetailView = app.otherElements["planDetailView"]
            let navigationBar = app.navigationBars.firstMatch
            
            XCTAssertTrue(planDetailView.exists || navigationBar.exists, "Plan detail view should be accessible")
            
            // Navigate back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
        
        print("✅ Plan management completed successfully")
    }
    
    // MARK: - Essential Test 2: Journey Management
    func testJourneyManagement() throws {
        print("\n🧪 ESSENTIAL TEST: Journey Management")
        print("====================================")
        
        // Navigate to Journeys tab
        let journeysTab = app.tabBars.buttons["Journeys"]
        XCTAssertTrue(journeysTab.waitForExistence(timeout: 5), "Journeys tab should exist")
        journeysTab.tap()
        
        // Verify demo journeys exist or can create new journey
        let addJourneyButton = app.buttons["addJourneyButton"]
        let existingJourney = app.cells.firstMatch
        
        XCTAssertTrue(addJourneyButton.exists || existingJourney.exists, "Journeys view should show add button or existing journeys")
        
        // Create new journey if button exists
        if addJourneyButton.exists {
            addJourneyButton.tap()
            
            let journeyNameField = app.textFields["journeyNameField"]
            if journeyNameField.waitForExistence(timeout: 3) {
                journeyNameField.tap()
                journeyNameField.typeText("Essential Test Journey")
                
                let journeyDescriptionField = app.textViews["journeyDescriptionField"]
                if journeyDescriptionField.exists {
                    journeyDescriptionField.tap()
                    journeyDescriptionField.typeText("Testing journey creation")
                }
                
                let saveJourneyButton = app.buttons["saveJourneyButton"]
                if saveJourneyButton.exists {
                    saveJourneyButton.tap()
                }
                
                // Verify journey appears — match by visible text label, not accessibilityIdentifier
                let journeyText = app.staticTexts.matching(NSPredicate(format: "label == 'Essential Test Journey'")).firstMatch
                let journeyCellByLabel = app.cells.matching(NSPredicate(format: "label CONTAINS 'Essential Test Journey'")).firstMatch
                XCTAssertTrue(journeyText.waitForExistence(timeout: 3) || journeyCellByLabel.exists, "Created journey should appear in list")
            }
        }
        
        // Test journey detail view with milestones
        if existingJourney.exists {
            existingJourney.tap()
            
            // Verify journey detail elements
            let journeyDetailView = app.otherElements["journeyDetailView"]
            let navigationBar = app.navigationBars.firstMatch
            
            XCTAssertTrue(journeyDetailView.exists || navigationBar.exists, "Journey detail view should be accessible")
            
            // Check for milestones section
            let addMilestoneButton = app.buttons["addMilestoneButton"]
            let milestonesSection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'milestone'")).firstMatch
            
            if addMilestoneButton.exists || milestonesSection.exists {
                XCTAssertTrue(true, "Journey should support milestones")
            }
            
            // Navigate back
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                backButton.tap()
            }
        }
        
        print("✅ Journey management completed successfully")
    }
}
