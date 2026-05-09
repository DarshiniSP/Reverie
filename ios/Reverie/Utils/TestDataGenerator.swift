//
//  TestDataGenerator.swift
//  iAlly
//
//  Created by Irigam Developer on 8/12/25.
//

import Foundation
import SwiftData

class TestDataGenerator {
    
    static func generateTestData(context: ModelContext) {
        // Clear existing data first
        clearAllData(context: context)
        
        // Generate Plans (5 plans across different domains)
        let plans = generatePlans(context: context)
        
        // Generate Routines (5 repeating routines)
        _ = generateRoutines(context: context)
        
        // Generate Journeys (3 journeys with milestones)
        let journeys = generateJourneys(context: context)
        
        // Generate Tasks (30+ tasks)
        generateTasks(context: context, plans: plans, journeys: journeys)
        
        // Save everything
        do {
            try context.save()
            
            // Generate routine tasks asynchronously after save
            _Concurrency.Task {
                await RoutineManager.shared.generateTasksFromRoutines(context: context)
            }
        } catch {
            // Silently fail - test data generation is not critical
        }
    }
    
    private static func clearAllData(context: ModelContext) {
        // Delete all tasks
        let taskDescriptor = FetchDescriptor<TaskWork>()
        if let tasks = try? context.fetch(taskDescriptor) {
            tasks.forEach { context.delete($0) }
        }
        
        // Delete all milestones
        let milestoneDescriptor = FetchDescriptor<Milestone>()
        if let milestones = try? context.fetch(milestoneDescriptor) {
            milestones.forEach { context.delete($0) }
        }
        
        // Delete all journeys
        let journeyDescriptor = FetchDescriptor<Journey>()
        if let journeys = try? context.fetch(journeyDescriptor) {
            journeys.forEach { context.delete($0) }
        }
        
        // Delete all routines
        let routineDescriptor = FetchDescriptor<Routine>()
        if let routines = try? context.fetch(routineDescriptor) {
            routines.forEach { context.delete($0) }
        }
        
        // Delete all plans
        let planDescriptor = FetchDescriptor<Plan>()
        if let plans = try? context.fetch(planDescriptor) {
            plans.forEach { context.delete($0) }
        }
        
        try? context.save()
    }
    
    private static func generatePlans(context: ModelContext) -> [Plan] {
        var plans: [Plan] = []
        
        // 1. Health Plan
        let healthPlan = Plan(
            name: "Fitness & Wellness",
            lifeDomain: .health,
            icon: "heart.fill",
            colorHex: "#FF6B6B",
            goal: "Maintain 70kg weight and exercise 4x/week",
            targetMetric: "Complete 80% of weekly health tasks",
            status: .active
        )
        context.insert(healthPlan)
        plans.append(healthPlan)
        
        // 2. Career Plan
        let careerPlan = Plan(
            name: "Career Growth 2025",
            lifeDomain: .career,
            icon: "briefcase.fill",
            colorHex: "#4C8BF5",
            goal: "Get promoted to Senior Developer",
            targetMetric: "Complete 3 major projects, learn 2 new technologies",
            status: .active
        )
        context.insert(careerPlan)
        plans.append(careerPlan)
        
        // 3. Personal Development Plan
        let personalPlan = Plan(
            name: "Learning & Growth",
            lifeDomain: .personal,
            icon: "book.fill",
            colorHex: "#FFA500",
            goal: "Read 24 books and learn Spanish",
            targetMetric: "2 books per month, 30 min daily Spanish practice",
            status: .active
        )
        context.insert(personalPlan)
        plans.append(personalPlan)
        
        // 4. Relationships Plan
        let familyPlan = Plan(
            name: "Family Time",
            lifeDomain: .relationships,
            icon: "house.fill",
            colorHex: "#FF69B4",
            goal: "Strengthen family bonds",
            targetMetric: "Weekly family dinner, monthly outing",
            status: .active
        )
        context.insert(familyPlan)
        plans.append(familyPlan)
        
        // 5. Finance Plan (On Hold)
        let financePlan = Plan(
            name: "Financial Independence",
            lifeDomain: .finance,
            icon: "dollarsign.circle.fill",
            colorHex: "#2ECC71",
            goal: "Save $50,000 and invest wisely",
            targetMetric: "Save 30% of income monthly",
            status: .onHold
        )
        context.insert(financePlan)
        plans.append(financePlan)
        
        return plans
    }
    
    private static func generateRoutines(context: ModelContext) -> [Routine] {
        var routines: [Routine] = []
        let calendar = Calendar.current
        let morning8am = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let evening6pm = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        let night9pm = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date())!
        
        // 1. Daily Morning Exercise
        let morningExercise = Routine(
            title: "Morning Exercise",
            lifeDomain: .health,
            icon: "figure.run",
            colorHex: "#FF6B6B",
            frequency: .daily,
            activeDays: nil,
            timeOfDay: morning8am,
            autoGenerateDays: 7,
            isActive: true,
            currentStreak: 12,
            longestStreak: 18,
            totalCompletions: 45,
            lastCompletedDate: Date().addingTimeInterval(-86400),
            lastGeneratedDate: nil,
            completionDates: generateRecentCompletionDates(count: 25, frequency: .daily, daysBack: 30)
        )
        context.insert(morningExercise)
        routines.append(morningExercise)
        
        // 2. Weekly Team Meeting (Every Monday)
        let weeklyMeeting = Routine(
            title: "Team Standup",
            lifeDomain: .career,
            icon: "person.3.fill",
            colorHex: "#4C8BF5",
            frequency: .weekly,
            activeDays: [1], // Monday
            timeOfDay: noon,
            autoGenerateDays: 14,
            isActive: true,
            currentStreak: 8,
            longestStreak: 15,
            totalCompletions: 32,
            lastCompletedDate: Date().addingTimeInterval(-7 * 86400),
            lastGeneratedDate: nil,
            completionDates: generateRecentCompletionDates(count: 4, frequency: .weekly, daysBack: 30)
        )
        context.insert(weeklyMeeting)
        routines.append(weeklyMeeting)
        
        // 3. Weekly Planning (Every Sunday evening)
        let weeklyPlanning = Routine(
            title: "Weekly Planning",
            lifeDomain: .personal,
            icon: "calendar.badge.checkmark",
            colorHex: "#FFA500",
            frequency: .weekly,
            activeDays: [7], // Sunday
            timeOfDay: evening6pm,
            autoGenerateDays: 7,
            isActive: true,
            currentStreak: 5,
            longestStreak: 10,
            totalCompletions: 24,
            lastCompletedDate: Date().addingTimeInterval(-7 * 86400),
            lastGeneratedDate: nil,
            completionDates: generateRecentCompletionDates(count: 4, frequency: .weekly, daysBack: 30)
        )
        context.insert(weeklyPlanning)
        routines.append(weeklyPlanning)
        
        // 4. Bi-weekly Family Dinner (Wednesday & Saturday)
        let familyDinner = Routine(
            title: "Family Dinner",
            lifeDomain: .relationships,
            icon: "fork.knife",
            colorHex: "#FF69B4",
            frequency: .custom,
            activeDays: [3, 6], // Wednesday & Saturday
            timeOfDay: evening6pm,
            autoGenerateDays: 7,
            isActive: true,
            currentStreak: 6,
            longestStreak: 12,
            totalCompletions: 28,
            lastCompletedDate: Date().addingTimeInterval(-3 * 86400),
            lastGeneratedDate: nil,
            completionDates: generateRecentCompletionDates(count: 7, frequency: .custom, daysBack: 30)
        )
        context.insert(familyDinner)
        routines.append(familyDinner)
        
        // 5. Monthly Budget Review (1st of month)
        let budgetReview = Routine(
            title: "Monthly Budget Review",
            lifeDomain: .finance,
            icon: "chart.bar.doc.horizontal",
            colorHex: "#2ECC71",
            frequency: .monthly,
            activeDays: [1], // 1st day of month
            timeOfDay: night9pm,
            autoGenerateDays: 30,
            isActive: true,
            currentStreak: 3,
            longestStreak: 5,
            totalCompletions: 8,
            lastCompletedDate: Date().addingTimeInterval(-30 * 86400),
            lastGeneratedDate: nil,
            completionDates: generateRecentCompletionDates(count: 1, frequency: .monthly, daysBack: 30)
        )
        context.insert(budgetReview)
        routines.append(budgetReview)
        
        // 6. Daily Reading (Inactive - paused)
        let dailyReading = Routine(
            title: "Evening Reading",
            lifeDomain: .personal,
            icon: "book.fill",
            colorHex: "#9B59B6",
            frequency: .daily,
            activeDays: nil,
            timeOfDay: night9pm,
            autoGenerateDays: 7,
            isActive: false,
            currentStreak: 0,
            longestStreak: 21,
            totalCompletions: 60,
            lastCompletedDate: Date().addingTimeInterval(-14 * 86400),
            lastGeneratedDate: nil,
            completionDates: [] // Paused, no recent completions
        )
        context.insert(dailyReading)
        routines.append(dailyReading)
        
        return routines
    }
    
    private static func generateJourneys(context: ModelContext) -> [(Journey, [Milestone])] {
        var journeys: [(Journey, [Milestone])] = []
        
        // 1. App Launch Journey
        let appJourney = Journey(
            title: "Launch iAlly App",
            vision: "Build and launch a productivity app that helps people achieve their goals",
            startDate: Date().addingTimeInterval(-60 * 86400), // Started 60 days ago
            targetDate: Date().addingTimeInterval(30 * 86400), // 30 days from now
            colorHex: "#9B59B6",
            icon: "app.badge",
            status: .inProgress
        )
        context.insert(appJourney)
        
        let m1 = Milestone(title: "Research & Planning", targetDate: Date().addingTimeInterval(-45 * 86400), order: 0)
        m1.completedAt = Date().addingTimeInterval(-40 * 86400)
        m1.journey = appJourney
        context.insert(m1)
        
        let m2 = Milestone(title: "Core Features Development", targetDate: Date().addingTimeInterval(-15 * 86400), order: 1)
        m2.completedAt = Date().addingTimeInterval(-10 * 86400)
        m2.journey = appJourney
        context.insert(m2)
        
        let m3 = Milestone(title: "Testing & Polish", targetDate: Date().addingTimeInterval(7 * 86400), order: 2)
        m3.journey = appJourney
        context.insert(m3)
        
        let m4 = Milestone(title: "Marketing & Launch", targetDate: Date().addingTimeInterval(30 * 86400), order: 3)
        m4.journey = appJourney
        context.insert(m4)
        
        journeys.append((appJourney, [m1, m2, m3, m4]))
        
        // 2. Marathon Training Journey
        let marathonJourney = Journey(
            title: "Run First Marathon",
            vision: "Complete a full marathon in under 4 hours by building endurance systematically",
            startDate: Date().addingTimeInterval(-30 * 86400),
            targetDate: Date().addingTimeInterval(120 * 86400), // 4 months from now
            colorHex: "#E74C3C",
            icon: "figure.run",
            status: .inProgress
        )
        context.insert(marathonJourney)
        
        let m5 = Milestone(title: "Base Building (0-5K)", targetDate: Date().addingTimeInterval(-15 * 86400), order: 0)
        m5.completedAt = Date().addingTimeInterval(-10 * 86400)
        m5.journey = marathonJourney
        context.insert(m5)
        
        let m6 = Milestone(title: "Increase Distance (10K)", targetDate: Date().addingTimeInterval(15 * 86400), order: 1)
        m6.journey = marathonJourney
        context.insert(m6)
        
        let m7 = Milestone(title: "Half Marathon Ready", targetDate: Date().addingTimeInterval(60 * 86400), order: 2)
        m7.journey = marathonJourney
        context.insert(m7)
        
        let m8 = Milestone(title: "Full Marathon Prep", targetDate: Date().addingTimeInterval(120 * 86400), order: 3)
        m8.journey = marathonJourney
        context.insert(m8)
        
        journeys.append((marathonJourney, [m5, m6, m7, m8]))
        
        // 3. Home Renovation Journey (Not Started)
        let renovationJourney = Journey(
            title: "Home Office Renovation",
            vision: "Create the perfect productive workspace at home with proper lighting, desk setup, and organization",
            startDate: Date().addingTimeInterval(14 * 86400), // Starts in 2 weeks
            targetDate: Date().addingTimeInterval(90 * 86400),
            colorHex: "#F39C12",
            icon: "house.and.flag.fill",
            status: .notStarted
        )
        context.insert(renovationJourney)
        
        let m9 = Milestone(title: "Design & Planning", targetDate: Date().addingTimeInterval(21 * 86400), order: 0)
        m9.journey = renovationJourney
        context.insert(m9)
        
        let m10 = Milestone(title: "Purchase Furniture & Equipment", targetDate: Date().addingTimeInterval(45 * 86400), order: 1)
        m10.journey = renovationJourney
        context.insert(m10)
        
        let m11 = Milestone(title: "Setup & Organization", targetDate: Date().addingTimeInterval(90 * 86400), order: 2)
        m11.journey = renovationJourney
        context.insert(m11)
        
        journeys.append((renovationJourney, [m9, m10, m11]))
        
        return journeys
    }
    
    private static func generateTasks(context: ModelContext, plans: [Plan], journeys: [(Journey, [Milestone])]) {
        let calendar = Calendar.current
        let today = Date()
        
        // Tasks for Health Plan (Fitness & Wellness)
        if let healthPlan = plans.first(where: { $0.lifeDomain == .health }) {
            createTask(context: context, title: "Morning run 5K", detail: "Run at the park, track time and distance", energy: .high, size: .medium, dueDate: calendar.date(byAdding: .day, value: 0, to: today), plan: healthPlan)
            
            createTask(context: context, title: "Meal prep for the week", detail: "Prepare healthy meals for next 5 days", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 1, to: today), plan: healthPlan)
            
            createTask(context: context, title: "Yoga session", detail: "30-minute evening yoga for flexibility", energy: .medium, size: .small, dueDate: calendar.date(byAdding: .day, value: 2, to: today), plan: healthPlan)
            
            createTask(context: context, title: "Schedule annual checkup", detail: "Book appointment with doctor", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 5, to: today), plan: healthPlan)
            
            createTask(context: context, title: "Strength training - upper body", detail: "Focus on arms and shoulders", energy: .high, size: .medium, dueDate: calendar.date(byAdding: .day, value: 3, to: today), plan: healthPlan, completed: true)
        }
        
        // Tasks for Career Plan
        if let careerPlan = plans.first(where: { $0.lifeDomain == .career }) {
            createTask(context: context, title: "Complete SwiftUI course module 5", detail: "Advanced animations and gestures", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 2, to: today), plan: careerPlan)
            
            createTask(context: context, title: "Update portfolio website", detail: "Add latest projects and testimonials", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 7, to: today), plan: careerPlan)
            
            createTask(context: context, title: "Prepare presentation for team meeting", detail: "Slides on new architecture proposal", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 1, to: today), plan: careerPlan)
            
            createTask(context: context, title: "1-on-1 with manager", detail: "Discuss Q1 goals and promotion path", energy: .medium, size: .small, dueDate: calendar.date(byAdding: .day, value: 3, to: today), plan: careerPlan)
            
            createTask(context: context, title: "Code review for PR #234", detail: "Review authentication refactor", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 0, to: today), plan: careerPlan, completed: true)
        }
        
        // Tasks for Personal Development Plan
        if let personalPlan = plans.first(where: { $0.lifeDomain == .personal }) {
            createTask(context: context, title: "Read 'Atomic Habits' chapter 3-5", detail: "Focus on habit stacking concepts", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 1, to: today), plan: personalPlan)
            
            createTask(context: context, title: "Duolingo Spanish lesson", detail: "Complete daily 15-minute practice", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 0, to: today), plan: personalPlan)
            
            createTask(context: context, title: "Watch TED talk on productivity", detail: "Take notes on key insights", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 4, to: today), plan: personalPlan)
            
            createTask(context: context, title: "Journal - weekly reflection", detail: "Reflect on wins and learnings", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 6, to: today), plan: personalPlan, completed: true)
        }
        
        // Tasks for Relationships Plan
        if let familyPlan = plans.first(where: { $0.lifeDomain == .relationships }) {
            createTask(context: context, title: "Plan weekend family outing", detail: "Research hiking trails or museums", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 2, to: today), plan: familyPlan)
            
            createTask(context: context, title: "Call mom", detail: "Weekly catch-up call", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 1, to: today), plan: familyPlan)
            
            createTask(context: context, title: "Buy birthday gift for sister", detail: "She mentioned wanting a new book", energy: .medium, size: .small, dueDate: calendar.date(byAdding: .day, value: 10, to: today), plan: familyPlan)
        }
        
        // Tasks for App Launch Journey
        if let (appJourney, milestones) = journeys.first(where: { $0.0.title == "Launch iAlly App" }) {
            // Testing & Polish milestone tasks
            if let testingMilestone = milestones.first(where: { $0.title == "Testing & Polish" }) {
                createTask(context: context, title: "Write unit tests for Plan model", detail: "Test all computed properties and relationships", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 2, to: today), journey: appJourney, milestone: testingMilestone)
                
                createTask(context: context, title: "Fix UI bugs from testing", detail: "Address layout issues on iPad", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 4, to: today), journey: appJourney, milestone: testingMilestone)
                
                createTask(context: context, title: "Performance optimization", detail: "Improve SwiftData query performance", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 5, to: today), journey: appJourney, milestone: testingMilestone)
            }
            
            // Marketing & Launch milestone tasks
            if let marketingMilestone = milestones.first(where: { $0.title == "Marketing & Launch" }) {
                createTask(context: context, title: "Create App Store screenshots", detail: "Design compelling screenshots for all devices", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 15, to: today), journey: appJourney, milestone: marketingMilestone)
                
                createTask(context: context, title: "Write app description", detail: "Craft compelling copy for App Store", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 20, to: today), journey: appJourney, milestone: marketingMilestone)
                
                createTask(context: context, title: "Submit to App Store", detail: "Final submission and review", energy: .high, size: .small, dueDate: calendar.date(byAdding: .day, value: 28, to: today), journey: appJourney, milestone: marketingMilestone)
            }
            
            // Unassigned tasks to the journey
            createTask(context: context, title: "Research analytics tools", detail: "Compare Firebase vs Mixpanel", energy: .medium, size: .small, dueDate: calendar.date(byAdding: .day, value: 8, to: today), journey: appJourney, milestone: nil)
        }
        
        // Tasks for Marathon Journey
        if let (marathonJourney, milestones) = journeys.first(where: { $0.0.title == "Run First Marathon" }) {
            // Increase Distance milestone tasks
            if let distanceMilestone = milestones.first(where: { $0.title == "Increase Distance (10K)" }) {
                createTask(context: context, title: "8K long run", detail: "Steady pace, focus on endurance", energy: .high, size: .large, dueDate: calendar.date(byAdding: .day, value: 3, to: today), journey: marathonJourney, milestone: distanceMilestone)
                
                createTask(context: context, title: "Speed intervals training", detail: "400m repeats x 8", energy: .high, size: .medium, dueDate: calendar.date(byAdding: .day, value: 5, to: today), journey: marathonJourney, milestone: distanceMilestone)
            }
            
            // Unassigned
            createTask(context: context, title: "Buy new running shoes", detail: "Visit running store for gait analysis", energy: .medium, size: .small, dueDate: calendar.date(byAdding: .day, value: 7, to: today), journey: marathonJourney, milestone: nil)
        }
        
        // Inbox tasks (no plan or journey)
        createTask(context: context, title: "Quick idea: grocery shopping", detail: "Milk, eggs, bread, vegetables", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: 1, to: today), plan: nil, journey: nil)
        
        createTask(context: context, title: "Research vacation destinations", detail: "Looking for beach resorts in Thailand", energy: .low, size: .medium, dueDate: calendar.date(byAdding: .day, value: 14, to: today), plan: nil, journey: nil)
        
        createTask(context: context, title: "Fix leaky faucet", detail: "Watch YouTube tutorial and get tools", energy: .medium, size: .medium, dueDate: calendar.date(byAdding: .day, value: 3, to: today), plan: nil, journey: nil)
        
        createTask(context: context, title: "Call dentist for appointment", detail: "Overdue cleaning", energy: .low, size: .small, dueDate: calendar.date(byAdding: .day, value: -2, to: today), plan: nil, journey: nil) // Overdue!
        
        createTask(context: context, title: "Random thought: learn piano", detail: "Research online courses", energy: .low, size: .small, dueDate: nil, plan: nil, journey: nil)
    }
    
    private static func createTask(
        context: ModelContext,
        title: String,
        detail: String,
        energy: TaskEnergy,
        size: TaskSize,
        dueDate: Date?,
        plan: Plan? = nil,
        journey: Journey? = nil,
        milestone: Milestone? = nil,
        completed: Bool = false
    ) {
        let task = TaskWork(
            title: title,
            detail: detail,
            dueDate: dueDate,
            energy: energy,
            size: size
        )
        
        task.plan = plan
        task.journey = journey
        task.milestone = milestone
        
        if completed {
            task.completedAt = Date().addingTimeInterval(-Double.random(in: 3600...86400))
        }
        
        context.insert(task)
    }
    
    // MARK: - Helper Functions
    
    /// Generate realistic completion dates for test routines
    private static func generateRecentCompletionDates(count: Int, frequency: RecurrenceFrequency, daysBack: Int) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        let today = Date()
        
        switch frequency {
        case .daily:
            // Generate roughly 80-90% completion rate for daily routines
            let totalDays = min(daysBack, count + 5)
            var currentDate = calendar.date(byAdding: .day, value: -totalDays, to: today)!
            
            for _ in 0..<count {
                // Skip some days randomly (10-20% miss rate)
                let daysToAdd = Double.random(in: 0...1) < 0.85 ? 1 : 2
                currentDate = calendar.date(byAdding: .day, value: daysToAdd, to: currentDate)!
                if currentDate <= today {
                    dates.append(currentDate)
                }
            }
            
        case .weekly:
            // Generate weekly completions (roughly one per week)
            for weekOffset in (0..<count).reversed() {
                if let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today) {
                    dates.append(date)
                }
            }
            
        case .monthly:
            // Generate monthly completions
            for monthOffset in (0..<count).reversed() {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    dates.append(date)
                }
            }
            
        case .custom:
            // Generate custom frequency (e.g., 2x per week)
            let completionsPerWeek = count / 4 // Roughly 2 per week for 4 weeks
            for weekOffset in 0..<4 {
                for dayInWeek in 0..<completionsPerWeek {
                    let totalDaysBack = (weekOffset * 7) + (dayInWeek * 3)
                    if let date = calendar.date(byAdding: .day, value: -totalDaysBack, to: today) {
                        dates.append(date)
                    }
                }
            }
        }
        
        return dates.sorted()
    }
}
