//
//  AccessibilityIdentifiers.swift
//  iAllyUITests
//
//  Centralized Accessibility Identifiers for Reliable Element Selection
//  Created: January 9, 2026
//

import Foundation

// MARK: - Accessibility Identifiers

struct AccessibilityIdentifiers {
    
    // MARK: - Navigation & Tabs
    
    struct Navigation {
        static let todayTab = "todayTab"
        static let plansTab = "plansTab"
        static let journeysTab = "journeysTab"
        static let routinesTab = "routinesTab"
        static let moreTab = "moreTab"
        
        static let backButton = "backButton"
        static let closeButton = "closeButton"
        static let doneButton = "doneButton"
        static let cancelButton = "cancelButton"
    }
    
    // MARK: - Task Management
    
    struct Tasks {
        static let addTaskButton = "addTaskButton"
        static let saveTaskButton = "saveTaskButton"
        static let deleteTaskButton = "deleteTaskButton"
        static let editTaskButton = "editTaskButton"
        
        static let taskTitleField = "taskTitleField"
        static let taskDetailField = "taskDetailField"
        static let taskNotesField = "taskNotesField"
        
        static let completeTaskButton = "completeTaskButton"
        static let taskCheckbox = "taskCheckbox"
        
        // Task Size Selection
        static let taskSizeSmall = "taskSizeButton_Small"
        static let taskSizeMedium = "taskSizeButton_Medium"
        static let taskSizeLarge = "taskSizeButton_Large"
        
        // Priority Selection
        static let priorityLow = "priorityButton_Low"
        static let priorityMedium = "priorityButton_Medium"
        static let priorityHigh = "priorityButton_High"
        static let priorityCritical = "priorityButton_Critical"
        
        // Energy Level Selection
        static let energyLow = "energyButton_Low"
        static let energyMedium = "energyButton_Medium"
        static let energyHigh = "energyButton_High"
    }
    
    // MARK: - Date & Time Pickers
    
    struct DateTimePickers {
        static let dueDatePicker = "dueDatePicker"
        static let timePicker = "timePicker"
        static let setDueDateButton = "setDueDateButton"
        static let removeDueDateButton = "removeDueDateButton"
        
        static let datePickerWheel = "datePickerWheel"
        static let timePickerWheel = "timePickerWheel"
    }
    
    // MARK: - Plan Management
    
    struct Plans {
        static let addPlanButton = "addPlanButton"
        static let planNameField = "planNameField"
        static let planDescriptionField = "planDescriptionField"
        
        // Life Domain Selection
        static let lifeDomainPicker = "lifeDomainPicker"
        static let lifeDomainHealth = "lifeDomain_Health"
        static let lifeDomainCareer = "lifeDomain_Career"
        static let lifeDomainLearning = "lifeDomain_Learning"
        static let lifeDomainRelationships = "lifeDomain_Relationships"
        static let lifeDomainCreativity = "lifeDomain_Creativity"
        static let lifeDomainFinance = "lifeDomain_Finance"
        static let lifeDomainHome = "lifeDomain_Home"
        static let lifeDomainPersonal = "lifeDomain_Personal"
        
        static let planProgressBar = "planProgressBar"
        static let planStatsView = "planStatsView"
    }
    
    // MARK: - Journey Management
    
    struct Journeys {
        static let addJourneyButton = "addJourneyButton"
        static let journeyTitleField = "journeyTitleField"
        static let journeyVisionField = "journeyVisionField"
        static let journeyTargetDatePicker = "journeyTargetDatePicker"
        
        static let addMilestoneButton = "addMilestoneButton"
        static let milestoneNameField = "milestoneNameField"
        static let milestoneDatePicker = "milestoneDatePicker"
        
        static let journeyProgressView = "journeyProgressView"
        static let journeyTimelineView = "journeyTimelineView"
    }
    
    // MARK: - Tag Management
    
    struct Tags {
        static let tagSelectionView = "tagSelectionView"
        static let addTagButton = "addTagButton"
        static let tagNameField = "tagNameField"
        static let tagColorPicker = "tagColorPicker"
        
        static let selectedTagsView = "selectedTagsView"
        static let availableTagsView = "availableTagsView"
        
        // Tag Colors
        static let tagColorRed = "tagColor_Red"
        static let tagColorBlue = "tagColor_Blue"
        static let tagColorGreen = "tagColor_Green"
        static let tagColorYellow = "tagColor_Yellow"
        static let tagColorPurple = "tagColor_Purple"
        static let tagColorOrange = "tagColor_Orange"
    }
    
    // MARK: - Picker Components
    
    struct Pickers {
        static let planPicker = "planPicker"
        static let journeyPicker = "journeyPicker"
        static let routinePicker = "routinePicker"
        
        static let pickerDoneButton = "pickerDoneButton"
        static let pickerCancelButton = "pickerCancelButton"
        
        // Picker Options (will be dynamically generated)
        static func planPickerOption(_ planName: String) -> String {
            return "planPickerOption_\(planName.replacingOccurrences(of: " ", with: "_"))"
        }
        
        static func journeyPickerOption(_ journeyName: String) -> String {
            return "journeyPickerOption_\(journeyName.replacingOccurrences(of: " ", with: "_"))"
        }
    }
    
    // MARK: - Today View Segments
    
    struct TodayView {
        static let todaySegment = "todaySegment"
        static let upcomingSegment = "upcomingSegment"
        static let inboxSegment = "inboxSegment"
        
        static let segmentedControl = "todaySegmentedControl"
        
        static let taskListView = "taskListView"
        static let emptyStateView = "emptyStateView"
    }
    
    // MARK: - Settings & Configuration
    
    struct Settings {
        static let settingsView = "settingsView"
        
        // Demo Data Management
        static let demoDataSection = "demoDataSection"
        static let addDemoDataButton = "addDemoDataButton"
        static let removeDemoDataButton = "removeDemoDataButton"
        static let resetDemoDataButton = "resetDemoDataButton"
        
        // Notification Settings
        static let notificationSection = "notificationSection"
        static let enableNotificationsToggle = "enableNotificationsToggle"
        static let notificationTimeField = "notificationTimeField"
        
        // Theme Settings
        static let themeSection = "themeSection"
        static let lightThemeButton = "lightThemeButton"
        static let darkThemeButton = "darkThemeButton"
        static let systemThemeButton = "systemThemeButton"
        
        // Data Management
        static let dataSection = "dataSection"
        static let exportDataButton = "exportDataButton"
        static let importDataButton = "importDataButton"
        static let clearDataButton = "clearDataButton"
    }
    
    // MARK: - Alerts & Dialogs
    
    struct Alerts {
        static let confirmationAlert = "confirmationAlert"
        static let errorAlert = "errorAlert"
        static let successAlert = "successAlert"
        
        static let alertTitle = "alertTitle"
        static let alertMessage = "alertMessage"
        
        static let confirmButton = "confirmButton"
        static let cancelAlertButton = "cancelAlertButton"
        static let okButton = "okButton"
        static let deleteConfirmButton = "deleteConfirmButton"
    }
    
    // MARK: - Onboarding
    
    struct Onboarding {
        static let onboardingView = "onboardingView"
        static let nextButton = "nextButton"
        static let skipButton = "skipButton"
        static let getStartedButton = "getStartedButton"
        
        static let privacyPage = "onboardingPrivacyPage"
        static let lifeDomainPage = "onboardingLifeDomainPage"
        static let habitsPage = "onboardingHabitsPage"
        static let journeysPage = "onboardingJourneysPage"
        static let focusPage = "onboardingFocusPage"
    }
    
    // MARK: - Form Elements
    
    struct Forms {
        static let textField = "textField"
        static let textView = "textView"
        static let switchControl = "switchControl"
        static let slider = "slider"
        static let stepper = "stepper"
        
        static let formSaveButton = "formSaveButton"
        static let formCancelButton = "formCancelButton"
        static let formResetButton = "formResetButton"
    }
    
    // MARK: - List & Collection Views
    
    struct Lists {
        static let taskList = "taskList"
        static let planList = "planList"
        static let journeyList = "journeyList"
        static let routineList = "routineList"
        
        static let listCell = "listCell"
        static let listHeader = "listHeader"
        static let listFooter = "listFooter"
        
        // Dynamic cell identifiers
        static func taskCell(_ taskTitle: String) -> String {
            return "taskCell_\(taskTitle.replacingOccurrences(of: " ", with: "_"))"
        }
        
        static func planCell(_ planName: String) -> String {
            return "planCell_\(planName.replacingOccurrences(of: " ", with: "_"))"
        }
    }
    
    // MARK: - Search & Filter
    
    struct Search {
        static let searchBar = "searchBar"
        static let searchField = "searchField"
        static let searchButton = "searchButton"
        static let clearSearchButton = "clearSearchButton"
        
        static let filterButton = "filterButton"
        static let sortButton = "sortButton"
        
        static let filterView = "filterView"
        static let sortView = "sortView"
    }
    
    // MARK: - Progress & Stats
    
    struct Progress {
        static let progressBar = "progressBar"
        static let progressLabel = "progressLabel"
        static let statsView = "statsView"
        
        static let activeTasksCount = "activeTasksCount"
        static let completedTasksCount = "completedTasksCount"
        static let totalTasksCount = "totalTasksCount"
        
        static let progressPercentage = "progressPercentage"
    }
    
    // MARK: - Accessibility Helpers
    
    /// Generate accessibility identifier for dynamic content
    static func dynamicIdentifier(base: String, suffix: String) -> String {
        let cleanSuffix = suffix.replacingOccurrences(of: " ", with: "_")
                                .replacingOccurrences(of: ".", with: "_")
                                .replacingOccurrences(of: "-", with: "_")
        return "\(base)_\(cleanSuffix)"
    }
    
    /// Generate accessibility identifier for completion buttons
    static func completeTaskIdentifier(for taskTitle: String) -> String {
        return dynamicIdentifier(base: "complete_task", suffix: taskTitle)
    }
    
    /// Generate accessibility identifier for edit buttons
    static func editTaskIdentifier(for taskTitle: String) -> String {
        return dynamicIdentifier(base: "edit_task", suffix: taskTitle)
    }
    
    /// Generate accessibility identifier for delete buttons
    static func deleteTaskIdentifier(for taskTitle: String) -> String {
        return dynamicIdentifier(base: "delete_task", suffix: taskTitle)
    }
}

// MARK: - Accessibility Labels

struct AccessibilityLabels {
    
    struct Tasks {
        static let addTask = "Add new task"
        static let saveTask = "Save task"
        static let deleteTask = "Delete task"
        static let completeTask = "Mark task as complete"
        static let editTask = "Edit task details"
        
        static let taskTitle = "Task title"
        static let taskDetail = "Task description"
        static let taskNotes = "Task notes"
    }
    
    struct Navigation {
        static let todayTab = "Today tasks"
        static let plansTab = "Life plans"
        static let journeysTab = "Long-term journeys"
        static let routinesTab = "Daily routines"
        static let moreTab = "More options"
        
        static let backButton = "Go back"
        static let closeButton = "Close"
        static let doneButton = "Done"
        static let cancelButton = "Cancel"
    }
    
    struct Pickers {
        static let planPicker = "Select a plan"
        static let journeyPicker = "Select a journey"
        static let dueDatePicker = "Select due date"
        static let timePicker = "Select time"
        static let priorityPicker = "Select priority level"
        static let energyPicker = "Select energy level required"
    }
}

// MARK: - Accessibility Traits

struct AccessibilityTraits {
    
    static let button = "button"
    static let textField = "textField"
    static let staticText = "staticText"
    static let picker = "picker"
    static let tabBar = "tabBar"
    static let navigationBar = "navigationBar"
    static let searchField = "searchField"
    static let segmentedControl = "segmentedControl"
    static let progressIndicator = "progressIndicator"
    static let alert = "alert"
    static let dialog = "dialog"
    static let list = "list"
    static let cell = "cell"
    static let header = "header"
    static let footer = "footer"
}

// MARK: - VoiceOver Hints

struct VoiceOverHints {
    
    struct Tasks {
        static let addTask = "Double tap to create a new task"
        static let completeTask = "Double tap to mark this task as complete"
        static let editTask = "Double tap to edit task details"
        static let deleteTask = "Double tap to delete this task"
    }
    
    struct Navigation {
        static let tabButton = "Double tap to switch to this tab"
        static let backButton = "Double tap to go back to the previous screen"
    }
    
    struct Pickers {
        static let picker = "Swipe up or down to change the selection, then double tap to confirm"
        static let datePicker = "Swipe up or down to change the date, then double tap to confirm"
    }
}