//
//  TestConfiguration.swift
//  iAllyUITests
//
//  Enhanced Test Configuration with Comprehensive Settings
//  Created: January 9, 2026
//

import XCTest
import Foundation

// MARK: - Enhanced Test Configuration

class EnhancedTestConfiguration {
    
    static let shared = EnhancedTestConfiguration()
    
    // MARK: - Configuration Properties
    
    let performanceTargets = PerformanceTargets()
    let qualityGates = QualityGates()
    let deviceConfigurations = DeviceConfigurations()
    let accessibilitySettings = AccessibilitySettings()
    let testDataSettings = TestDataSettings()
    
    private init() {}
    
    // MARK: - Test Environment Setup
    
    func configureTestEnvironment(for app: XCUIApplication) {
        // Core test environment
        app.launchEnvironment["UITEST_IN_MEMORY"] = "1"
        app.launchEnvironment["XCTestConfigurationFilePath"] = "1"
        
        // Test state management
        app.launchArguments += ["-UITest_ResetState"]
        app.launchArguments += ["-UITest_DisableAnimations"]
        app.launchArguments += ["-UITest_FastMode"]
        app.launchArguments += ["-UITest_SkipOnboarding"]
        
        // Accessibility testing
        app.launchArguments += ["-UITest_EnableAccessibilityTesting"]
        
        // Performance testing
        app.launchArguments += ["-UITest_PerformanceMode"]
        
        // Demo data management
        if testDataSettings.useCleanState {
            app.launchArguments += ["-UITest_CleanState"]
        }
        
        if testDataSettings.loadDemoData {
            app.launchArguments += ["-LoadTestData"]
        }
    }
    
    // MARK: - Test Isolation
    
    func setupTestIsolation() -> TestIsolationContext {
        return TestIsolationContext(
            testId: UUID().uuidString,
            startTime: Date(),
            configuration: self
        )
    }
}

// MARK: - Performance Targets

struct PerformanceTargets {
    let maxExecutionTime: TimeInterval = 15 * 60 // 15 minutes
    let maxTestExecutionTime: TimeInterval = 2 * 60 // 2 minutes per test
    let maxSetupTime: TimeInterval = 30 // 30 seconds
    let maxTeardownTime: TimeInterval = 10 // 10 seconds
    
    let minPassRate: Double = 95.0 // 95%
    let maxFlakiness: Double = 2.0 // 2%
    let minReliability: Double = 98.0 // 98%
    
    let maxRetryAttempts: Int = 3
    let retryDelay: TimeInterval = 1.0
    
    let elementWaitTimeout: TimeInterval = 10.0
    let appLaunchTimeout: TimeInterval = 30.0
    let navigationTimeout: TimeInterval = 5.0
}

// MARK: - Quality Gates

struct QualityGates {
    let minTestCoverage: Double = 100.0 // 100%
    let minUIConsistency: Double = 90.0 // 90%
    let maxVisualRegression: Double = 5.0 // 5%
    let wcagComplianceLevel: String = "AA" // WCAG AA compliance level
    
    let blockOnTestFailure: Bool = true
    let blockOnCoverageFailure: Bool = true
    let blockOnUIInconsistency: Bool = true
    let blockOnAccessibilityViolation: Bool = true
    
    let criticalViolationThreshold: Int = 0
    let majorViolationThreshold: Int = 5
    let minorViolationThreshold: Int = 20
}

// MARK: - Device Configurations

struct DeviceConfigurations {
    let primaryDeviceName: String = "iPhone 16 Pro"
    let primaryScreenSize: CGSize = CGSize(width: 393, height: 852)
    
    let supportedDeviceNames: [String] = [
        "iPhone 16 Pro",
        "iPhone 16"
    ]
    
    let supportedAppearanceModes: [String] = ["light", "dark"]
    let supportedOrientations: [UIDeviceOrientation] = [.portrait, .landscapeLeft]
}

// MARK: - Accessibility Settings

struct AccessibilitySettings {
    let enableVoiceOverTesting: Bool = true
    let enableColorContrastTesting: Bool = true
    let enableTouchTargetTesting: Bool = true
    let enableNavigationOrderTesting: Bool = true
    
    let minimumTouchTargetSize: CGSize = CGSize(width: 44, height: 44)
    let minimumColorContrastRatio: Double = 4.5 // WCAG AA standard
    let preferredColorContrastRatio: Double = 7.0 // WCAG AAA standard
    
    let voiceOverTestingTimeout: TimeInterval = 15.0
    let accessibilityElementTimeout: TimeInterval = 5.0
}

// MARK: - Test Data Settings

struct TestDataSettings {
    let useCleanState: Bool = true
    let loadDemoData: Bool = false
    let preserveUserData: Bool = true
    let resetBetweenTests: Bool = true
    
    let demoDataSets = [
        "minimal": "Minimal test data for basic functionality",
        "comprehensive": "Full demo data for complete testing",
        "edge_cases": "Edge case data for boundary testing",
        "performance": "Large data set for performance testing"
    ]
    
    let defaultDataSet: String = "minimal"
}

// MARK: - Test Isolation Context

struct TestIsolationContext {
    let testId: String
    let startTime: Date
    let configuration: EnhancedTestConfiguration
    var metadata: [String: Any] = [:]
    var testData: [String: Any] = [:]
}

// MARK: - Test Execution Context

class TestExecutionContext {
    
    let testName: String
    let testClass: String
    let startTime: Date
    let configuration: EnhancedTestConfiguration
    
    private var checkpoints: [TestCheckpoint] = []
    private var metrics: TestMetrics
    
    init(testName: String, testClass: String) {
        self.testName = testName
        self.testClass = testClass
        self.startTime = Date()
        self.configuration = EnhancedTestConfiguration.shared
        self.metrics = TestMetrics()
    }
    
    func addCheckpoint(_ name: String, metadata: [String: Any] = [:]) {
        let checkpoint = TestCheckpoint(
            name: name,
            timestamp: Date(),
            metadata: metadata
        )
        checkpoints.append(checkpoint)
    }
    
    func recordMetric(_ name: String, value: Double, unit: String = "") {
        metrics.record(name: name, value: value, unit: unit)
    }
    
    func generateReport() -> TestExecutionReport {
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        return TestExecutionReport(
            testName: testName,
            testClass: testClass,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            checkpoints: checkpoints,
            metrics: metrics,
            meetsPerformanceTargets: duration <= configuration.performanceTargets.maxTestExecutionTime
        )
    }
}

struct TestCheckpoint {
    let name: String
    let timestamp: Date
    let metadata: [String: Any]
}

class TestMetrics {
    private var metrics: [String: MetricValue] = [:]
    
    func record(name: String, value: Double, unit: String = "") {
        metrics[name] = MetricValue(value: value, unit: unit, timestamp: Date())
    }
    
    func get(_ name: String) -> MetricValue? {
        return metrics[name]
    }
    
    func getAllMetrics() -> [String: MetricValue] {
        return metrics
    }
}

struct MetricValue {
    let value: Double
    let unit: String
    let timestamp: Date
}

struct TestExecutionReport {
    let testName: String
    let testClass: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let checkpoints: [TestCheckpoint]
    let metrics: TestMetrics
    let meetsPerformanceTargets: Bool
}

// MARK: - Test Categories

enum TestCategory {
    case smoke
    case regression
    case integration
    case performance
    case accessibility
    case uiConsistency
    case dataSelection
    case endToEnd
    case edgeCase
    
    var priority: TestPriority {
        switch self {
        case .smoke, .regression:
            return .critical
        case .integration, .accessibility:
            return .high
        case .uiConsistency, .dataSelection:
            return .medium
        case .performance, .endToEnd, .edgeCase:
            return .low
        }
    }
    
    var timeout: TimeInterval {
        switch self {
        case .smoke:
            return 30
        case .regression, .integration:
            return 60
        case .performance:
            return 120
        case .endToEnd:
            return 180
        default:
            return 90
        }
    }
}

enum TestPriority {
    case critical
    case high
    case medium
    case low
    
    var executionOrder: Int {
        switch self {
        case .critical: return 1
        case .high: return 2
        case .medium: return 3
        case .low: return 4
        }
    }
}

// MARK: - Test Suite Configuration

struct TestSuiteConfiguration {
    let name: String
    let categories: [TestCategory]
    let priority: TestPriority
    let parallelExecution: Bool
    let maxConcurrentTests: Int
    let retryFailedTests: Bool
    let generateDetailedReports: Bool
    
    static let comprehensive = TestSuiteConfiguration(
        name: "Comprehensive Test Suite",
        categories: TestCategory.allCases,
        priority: .critical,
        parallelExecution: false,
        maxConcurrentTests: 1,
        retryFailedTests: true,
        generateDetailedReports: true
    )
    
    static let smoke = TestSuiteConfiguration(
        name: "Smoke Test Suite",
        categories: [.smoke],
        priority: .critical,
        parallelExecution: false,
        maxConcurrentTests: 1,
        retryFailedTests: false,
        generateDetailedReports: false
    )
    
    static let regression = TestSuiteConfiguration(
        name: "Regression Test Suite",
        categories: [.regression, .integration],
        priority: .high,
        parallelExecution: false,
        maxConcurrentTests: 1,
        retryFailedTests: true,
        generateDetailedReports: true
    )
}

// MARK: - Extensions

extension TestCategory: CaseIterable {}

extension EnhancedTestConfiguration {
    
    func shouldRunTest(category: TestCategory, priority: TestPriority) -> Bool {
        // Implementation for test filtering based on configuration
        return true
    }
    
    func getTimeoutForTest(category: TestCategory) -> TimeInterval {
        return category.timeout
    }
}

// MARK: - Test Environment Validation

class TestEnvironmentValidator {
    
    static func validateEnvironment() -> ValidationResult {
        var issues: [String] = []
        
        // Check simulator availability
        if !isSimulatorAvailable() {
            issues.append("iOS Simulator not available")
        }
        
        // Check disk space
        if !hasSufficientDiskSpace() {
            issues.append("Insufficient disk space for test execution")
        }
        
        // Check memory availability
        if !hasSufficientMemory() {
            issues.append("Insufficient memory for test execution")
        }
        
        return ValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    private static func isSimulatorAvailable() -> Bool {
        // Implementation to check simulator availability
        return true
    }
    
    private static func hasSufficientDiskSpace() -> Bool {
        // Implementation to check disk space
        return true
    }
    
    private static func hasSufficientMemory() -> Bool {
        // Implementation to check memory
        return true
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Legacy Test Configuration Support

struct TestConfiguration {
    
    // MARK: - Test Environment Settings
    
    static let defaultTimeout: TimeInterval = 10
    static let shortTimeout: TimeInterval = 3
    static let longTimeout: TimeInterval = 15
    
    static let launchArguments = [
        "-UITest_ResetState",
        "-LoadTestData"
    ]
    
    static let launchEnvironment = [
        "UITEST_IN_MEMORY": "1"
    ]
    
    // MARK: - Accessibility ID Mapping
    
    struct AccessibilityIDs {
        // Task Management
        static let addTaskButton = "addTaskButton"
        static let taskTitleField = "taskTitleField"
        static let taskDetailField = "taskDetailField"
        static let saveTaskButton = "saveTaskButton"
        static let deleteButton = "trash"
        static let confirmDeleteButton = "Delete"
        
        // Task Size Buttons
        static let smallTaskButton = "taskSizeButton_Small"
        static let mediumTaskButton = "taskSizeButton_Medium"
        static let largeTaskButton = "taskSizeButton_Large"
        
        // Navigation
        static let todayButton = "Today"
        static let upcomingButton = "Upcoming"
        static let inboxButton = "Inbox"
        static let plansButton = "Plans"
        static let journeysButton = "Journeys"
        static let routinesButton = "Routines"
        static let moreButton = "More"
        
        // Onboarding
        static let nextButton = "Next"
        static let getStartedButton = "Get Started"
        static let allowButton = "Allow"
        static let dontAllowButton = "Don't Allow"
        static let skipOnboardingButton = "skipOnboardingButton"
        
        // Task Completion
        static func completeTaskButton(for taskTitle: String) -> String {
            return "complete_task_\(taskTitle)"
        }
        
        // Reflection Sheet
        static let taskCompletedTitle = "Task Completed!"
        static let reflectionField = "Any remarks about this task?"
        static let doneButton = "Done"
        static let completeNowButton = "Complete It Now"
    }
    
    // MARK: - Test Data
    
    struct TestData {
        static let sampleTasks = [
            "E2E: Launch Website",
            "Design mockups", 
            "Write content",
            "Review and publish",
            "Test functionality"
        ]
        
        static let sampleDetails = [
            "Detailed description for testing",
            "This is a test task with comprehensive details",
            "Sample task detail for UI testing"
        ]
        
        static let reflectionTexts = [
            "Test reflection completed successfully",
            "Automated test completion",
            "Task completed via UI test"
        ]
        
        static let onboardingScreens = [
            "Your Private Ally",
            "Balance Your Life",
            "Build Lasting Habits", 
            "Achieve Big Goals",
            "Master Your Time"
        ]
    }
    
    // MARK: - Task Size Enum
    
    enum TaskSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
    }
    
    // MARK: - Common Test Patterns
    
    static func configureApp(_ app: XCUIApplication) {
        app.launchArguments.append(contentsOf: launchArguments)
        for (key, value) in launchEnvironment {
            app.launchEnvironment[key] = value
        }
    }
    
    static func waitForElement(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    static func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = defaultTimeout) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
    
    // MARK: - Debugging Helpers
    
    static func printElementHierarchy(_ app: XCUIApplication) {
        print("🔍 Current Element Hierarchy:")
        print(app.debugDescription)
    }
    
    static func printAvailableButtons(_ app: XCUIApplication) {
        print("🔍 Available Buttons:")
        for button in app.buttons.allElementsBoundByIndex {
            if button.exists {
                print("  - \(button.identifier): '\(button.label)'")
            }
        }
    }
    
    static func printAvailableTextFields(_ app: XCUIApplication) {
        print("🔍 Available Text Fields:")
        for textField in app.textFields.allElementsBoundByIndex {
            if textField.exists {
                print("  - \(textField.identifier): '\(textField.label)'")
            }
        }
    }
    
    // MARK: - Error Recovery
    
    static func recoverFromFailedState(_ app: XCUIApplication) -> Bool {
        print("🔄 Attempting to recover from failed state...")
        
        // Try to dismiss any modal sheets
        let closeButtons = ["Close", "Cancel", "Done", "Dismiss"]
        for buttonText in closeButtons {
            let button = app.buttons[buttonText]
            if button.exists && button.isHittable {
                button.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        
        // Try to navigate back to Today view
        let todayButton = app.buttons[AccessibilityIDs.todayButton]
        if todayButton.exists && todayButton.isHittable {
            todayButton.tap()
            return waitForElement(app.tabBars.firstMatch, timeout: shortTimeout)
        }
        
        return false
    }
}

// MARK: - Test Result Tracking

class TestResultTracker {
    static var shared = TestResultTracker()
    
    private var testResults: [String: TestResult] = [:]
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let duration: TimeInterval
        let failureReason: String?
        let timestamp: Date
    }
    
    func recordResult(testName: String, passed: Bool, duration: TimeInterval, failureReason: String? = nil) {
        let result = TestResult(
            testName: testName,
            passed: passed,
            duration: duration,
            failureReason: failureReason,
            timestamp: Date()
        )
        testResults[testName] = result
    }
    
    func generateReport() -> String {
        let totalTests = testResults.count
        let passedTests = testResults.values.filter { $0.passed }.count
        let failedTests = totalTests - passedTests
        let passRate = totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0
        
        var report = """
        📊 Test Execution Report
        ========================
        Total Tests: \(totalTests)
        Passed: \(passedTests)
        Failed: \(failedTests)
        Pass Rate: \(String(format: "%.1f", passRate))%
        
        """
        
        if failedTests > 0 {
            report += "❌ Failed Tests:\n"
            for result in testResults.values.filter({ !$0.passed }) {
                report += "  - \(result.testName): \(result.failureReason ?? "Unknown failure")\n"
            }
        }
        
        return report
    }
}