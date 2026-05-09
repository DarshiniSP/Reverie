//
//  AddTaskView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    @Query private var journeys: [Journey]
    @Query private var plans: [Plan]
    @Query private var routines: [Routine]

    var preselectedJourney: Journey?
    var preselectedPlan: Plan?
    var preselectedMilestone: Milestone?

    /// When provided, the due date field is pre-filled (e.g. today when opened from the Today tab).
    /// `defaultIsInbox: true` marks the task as inbox-originated so it stays visible in Inbox
    /// even after a due date is assigned, until the due date arrives.
    init(defaultDueDate: Date? = nil,
         defaultIsInbox: Bool = false,
         preselectedJourney: Journey? = nil,
         preselectedPlan: Plan? = nil,
         preselectedMilestone: Milestone? = nil) {
        _dueDate   = State(initialValue: defaultDueDate)
        _isInbox   = State(initialValue: defaultIsInbox)
        self.preselectedJourney  = preselectedJourney
        self.preselectedPlan     = preselectedPlan
        self.preselectedMilestone = preselectedMilestone
    }

    // Task type selection
    @State private var taskType: TaskType = .quick
    
    @State private var title = ""
    @State private var detail = ""
    @State private var size = TaskSize.medium
    @State private var selectedPriority: Priority? = nil
    @State private var dueDate: Date?
    @State private var showDueDatePicker = false
    @State private var isInbox: Bool = false

    // Attachments (Pre-generated ID)
    @State private var taskId = UUID()
    
    // Natural language parsing
    @State private var showNLPSuggestion = false
    @State private var parsedTask: ParsedTask?
    @State private var nlpPAITask: Task<Void, Never>?  // cancellable PAI enrichment task
    
    // For one-time goal tasks
    @State private var selectedJourney: Journey?
    @State private var selectedMilestone: Milestone?
    
    // For routine/plan tasks
    @State private var selectedPlan: Plan?
    
    // For repeating routine tasks
    @State private var selectedRoutine: Routine?
    @State private var frequency: RecurrenceFrequency = .daily
    @State private var selectedDays: Set<Int> = []
    @State private var timeOfDay: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    
    enum TaskType: String, CaseIterable {
        case quick = "One-time Task"
        case focus = "Focus Sprint"
        case routine = "Repeating Routine"
        // Note: .goal is kept internally so milestone pre-selection still works
        // but it is not shown in the main picker
        case goal = "Goal"

        // Only show these in the picker — Goal is set programmatically via preselectedJourney
        static var visibleCases: [TaskType] { [.quick, .focus, .routine] }

        var icon: String {
            switch self {
            case .quick:   return "checkmark.circle.fill"
            case .focus:   return "bolt.circle.fill"
            case .routine: return "repeat.circle.fill"
            case .goal:    return "flag.fill"
            }
        }

        var description: String {
            switch self {
            case .quick:   return "A single task — do it once and done"
            case .focus:   return "One focused session. Block distractions and get it done"
            case .routine: return "Repeats daily, weekly, or monthly"
            case .goal:    return "Linked to a long-term goal with milestones"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Task Title") {
                    TextField("What needs to be done?", text: $title)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("taskTitleField")
                        .onChange(of: title) { oldValue, newValue in
                            parseNaturalLanguage(newValue)
                        }
                    
                    // Show NLP suggestion banner
                    if showNLPSuggestion, let parsed = parsedTask {
                        nlpSuggestionBanner(parsed: parsed)
                    }
                }
                
                Section("Details") {
                    TextField("Add details (optional)", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityIdentifier("taskDetailField")
                }
                
                // Goal link section — only shown when launched from the Goals tab
                // (preselectedJourney is set by JourneyDetailView)
                if taskType == .goal {
                    goalSection
                } else {
                    quickTaskSection
                }
                
                // Common sections
                taskAttributesSection
                dueDateSection

                // Attachments Section
                if taskType != .routine {
                    Section("Attachments") {
                        AttachmentsView(itemId: taskId, itemType: .task)
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTaskWork()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.isEmpty)
                    .accessibilityIdentifier("saveTaskButton")
                }
            }
        }
        .onAppear {
            if let milestone = preselectedMilestone {
                // Milestone pre-selection also sets its parent journey
                selectedMilestone = milestone
                selectedJourney   = milestone.journey ?? preselectedJourney
                taskType = .goal
            } else if let journey = preselectedJourney {
                selectedJourney = journey
                taskType = .goal
            }
            if let plan = preselectedPlan {
                selectedPlan = plan
                taskType = .quick
            }
        }
    }
    
    // MARK: - View Components
    
    private var quickTaskSection: some View {
        Section("Life Domain (Optional)") {
            Picker("Life Domain", selection: $selectedPlan) {
                Text("None").tag(nil as Plan?)
                ForEach(LifeDomain.allCases, id: \.self) { domain in
                    let planForDomain = plans.first { $0.lifeDomain == domain }
                    Text(domain.rawValue).tag(planForDomain as Plan?)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    private var focusSprintSection: some View {
        Section("Focus Sprint") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.circle.fill")
                        .foregroundColor(DSColors.focus)
                    Text("One focused session — no distractions until it's done.")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                }

                Text("Set your due date below to schedule when you want to sprint on this task. It will appear in your Today view so you can start Focus Mode directly.")
                    .font(DSFonts.caption(13))
                    .foregroundColor(DSColors.textTertiary)
                    .lineSpacing(3)
            }
            .padding(.vertical, 4)
        }
    }

    private var goalSection: some View {
        Group {
            Section("Link to Goal") {
                Picker("Goal", selection: $selectedJourney) {
                    Text("Select a goal").tag(nil as Journey?)
                    ForEach(journeys) { journey in
                        Label(journey.title, systemImage: journey.icon)
                            .tag(journey as Journey?)
                    }
                }
                
                if let journey = selectedJourney, let milestones = journey.milestones, !milestones.isEmpty {
                    Picker("Milestone (optional)", selection: $selectedMilestone) {
                        Text("None").tag(nil as Milestone?)
                        ForEach(milestones.sorted(by: { $0.order < $1.order })) { milestone in
                            Text(milestone.title).tag(milestone as Milestone?)
                        }
                    }
                }
            }
        }
    }
    
    private var routineSection: some View {
        Group {
            Section("Recurrence Pattern") {
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                        Label(freq.rawValue, systemImage: freq.icon)
                            .tag(freq)
                    }
                }
                .pickerStyle(.segmented)
                
                if frequency == .weekly || frequency == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Days")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { day in
                                DayButton(
                                    day: day,
                                    isSelected: selectedDays.contains(day)
                                ) {
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                }
                            }
                        }
                    }
                }
                
                DatePicker("Time of Day", selection: $timeOfDay, displayedComponents: .hourAndMinute)
            }
            
            Section("Life Domain") {
                Picker("Life Domain", selection: $selectedPlan) {
                    Text("Select domain").tag(nil as Plan?)
                    ForEach(LifeDomain.allCases, id: \.self) { domain in
                        let planForDomain = plans.first { $0.lifeDomain == domain }
                        Label(domain.rawValue, systemImage: domain.icon)
                            .tag(planForDomain as Plan?)
                    }
                }
            }
        }
    }
    
    private var taskAttributesSection: some View {
        Section("Task Attributes") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Task Size")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                
                HStack(spacing: 12) {
                    ForEach(TaskSize.allCases, id: \.self) { taskSize in
                        Button {
                            size = taskSize
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: taskSize.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(size == taskSize ? DSColors.onAccent : DSColors.textPrimary)
                                Text(taskSize.rawValue)
                                    .font(DSFonts.body(14))
                                    .foregroundColor(size == taskSize ? DSColors.onAccent : DSColors.textPrimary)
                                Text(taskSize.timeDescription)
                                    .font(DSFonts.caption())
                                    .foregroundColor(size == taskSize ? DSColors.onAccent.opacity(0.8) : DSColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(size == taskSize ? DSColors.accentPrimary : DSColors.canvasSecondary)
                            .cornerRadius(UIConstants.CornerRadius.large)
                        }
                        .accessibilityIdentifier("taskSizeButton_\(taskSize.rawValue)")
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dueDateSection: some View {
        Section("Due Date") {
            HStack {
                Text("Due Date")
                    .font(DSFonts.body())
                Spacer()
                if let due = dueDate {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { due },
                            set: { dueDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    
                    Button {
                        dueDate = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DSColors.textSecondary)
                    }
                } else {
                    Button("Set due date") {
                        dueDate = Date()  // Current time
                    }
                    .foregroundColor(DSColors.accentPrimary)
                }
            }
        }
    }
    
    private func saveTaskWork() {
        if false {
            // Routines are created via Quick Add — this branch is no longer reachable
            createRoutine()
        } else {
            // Create regular task (quick or goal)
            let task = TaskWork(
                id: taskId,  // Use the ID we generated for attachments
                title: title,
                detail: detail.isEmpty ? nil : detail,
                dueDate: dueDate,
                energy: nil,  // No longer set upfront - captured at completion
                size: size,
                isRecurring: false
            )
            
            // Mark inbox origin before assigning relationships
            task.isInbox = isInbox

            if taskType == .goal {
                task.journey = selectedJourney
                task.milestone = selectedMilestone
            } else {
                task.plan = selectedPlan
            }

            task.priority = selectedPriority

            modelContext.insert(task)
            
            do {
                try modelContext.save()
                
                // Schedule notification if task has due date
                if let dueDate = dueDate {
                    _Concurrency.Task {
                        await notificationManager.scheduleTaskDueNotification(
                            taskId: task.id.uuidString,
                            taskTitle: title,
                            dueDate: dueDate
                        )
                    }
                }

                // Sync to system calendar (if calendar integration is enabled).
                if task.dueDate != nil {
                    let _ = CalendarManager.shared.createEvent(from: task)
                }

                // Record to PAI episodic memory
                PAIMemoryBridge.shared.recordTaskCreated(task)

                // Refresh widgets so task counts update immediately.
                WidgetHelper.shared.reloadAllWidgets()
            } catch {
                // Silently fail - error handling can be improved with user feedback
            }
        }
        
        dismiss()
    }
    
    private func createRoutine() {
        let routine = Routine(
            title: title,
            lifeDomain: selectedPlan?.lifeDomain ?? .personal,
            icon: selectedPlan?.lifeDomain.icon ?? "leaf",
            colorHex: selectedPlan?.colorHex ?? "#007AFF",
            frequency: frequency,
            activeDays: frequency == .daily ? nil : Array(selectedDays).sorted(),
            timeOfDay: timeOfDay,
            autoGenerateDays: 7, // Generate tasks 7 days in advance
            isActive: true
        )
        
        modelContext.insert(routine)
        
        do {
            try modelContext.save()
            
            // Generate initial tasks
            _Concurrency.Task {
                await RoutineManager.shared.generateTasksForRoutine(routine, context: modelContext)
                try? modelContext.save()
            }
        } catch {
            // Silently fail - error handling can be improved with user feedback
        }
    }

}

// MARK: - Helper Views

struct TaskTypeRow: View {
    let type: AddTaskView.TaskType
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(DSFonts.headline())
                .foregroundColor(isSelected ? DSColors.onAccent : DSColors.accentPrimary)
                .frame(width: 40, height: 40)
                .background(isSelected ? DSColors.accentPrimary : DSColors.accentPrimary.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.rawValue)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DSColors.accentPrimary)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DayButton: View {
    let day: Int
    let isSelected: Bool
    let action: () -> Void
    
    private var dayLabel: String {
        ["M", "T", "W", "T", "F", "S", "S"][day - 1]
    }
    
    var body: some View {
        Button(action: action) {
            Text(dayLabel)
                .font(DSFonts.body(14).weight(.medium))
                .foregroundColor(isSelected ? DSColors.onAccent : DSColors.textPrimary)
                .frame(width: 36, height: 36)
                .background(isSelected ? DSColors.accentPrimary : DSColors.canvasSecondary)
                .cornerRadius(18)
        }
    }
}

struct AttributeButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(DSFonts.headline())
                    .foregroundColor(isSelected ? DSColors.onAccent : DSColors.accentPrimary)
                
                Text(label)
                    .font(DSFonts.body(12))
                    .foregroundColor(isSelected ? DSColors.onAccent : DSColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? DSColors.accentPrimary : DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.medium)
        }
    }
}

// MARK: - AddTaskView NLP Extension

extension AddTaskView {
    // MARK: - Natural Language Parsing
    
    private func parseNaturalLanguage(_ input: String) {
        // Only parse if input is substantial
        guard input.count > 5 else {
            showNLPSuggestion = false
            return
        }

        // Step 1: instant local regex parse (always runs, works offline)
        let parsed = NaturalLanguageParser.shared.parse(input)
        let hasExtractedData = parsed.dueDate != nil || parsed.size != nil || parsed.isRecurring

        if hasExtractedData {
            parsedTask = parsed
            showNLPSuggestion = true
        } else {
            showNLPSuggestion = false
        }

        // Step 2: PAI enrichment — runs async with 500ms debounce, upgrades the result
        nlpPAITask?.cancel()
        nlpPAITask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms debounce
            guard !Task.isCancelled, input.count > 8 else { return }
            let enriched = await NaturalLanguageParser.shared.parseWithAI(input)
            guard !Task.isCancelled else { return }
            // Only update if PAI found something new
            let enrichedHasData = enriched.dueDate != nil || enriched.size != nil
                || enriched.isRecurring || enriched.priority != nil || enriched.suggestedContext != nil
            if enrichedHasData {
                parsedTask = enriched
                showNLPSuggestion = true
            }
        }
    }
    
    private func applySuggestions() {
        guard let parsed = parsedTask else { return }

        // Apply cleaned title
        if let cleanedTitle = parsed.cleanedTitle, !cleanedTitle.isEmpty {
            title = cleanedTitle
        }

        // Apply due date
        if let date = parsed.dueDate {
            dueDate = date
        }

        // Apply task size
        if let taskSize = parsed.size {
            size = taskSize
        }

        // Apply PAI-extracted priority
        if let p = parsed.priority {
            selectedPriority = p
        }

        // Handle recurrence
        if parsed.isRecurring {
            taskType = .routine
        }

        // Dismiss suggestion banner and cancel any pending PAI enrichment
        nlpPAITask?.cancel()
        showNLPSuggestion = false
        parsedTask = nil
    }
    
    @ViewBuilder
    private func nlpSuggestionBanner(parsed: ParsedTask) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(DSColors.accentPrimary)
                
                Text("Smart Suggestions")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
                
                Spacer()
                
                Button {
                    showNLPSuggestion = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DSColors.textSecondary)
                        .font(DSFonts.body())
                }
            }
            
            // Show what was detected
            VStack(alignment: .leading, spacing: 6) {
                if let cleanedTitle = parsed.cleanedTitle, cleanedTitle != title {
                    suggestionRow(icon: "text.alignleft", label: "Title", value: cleanedTitle)
                }
                
                if let date = parsed.dueDate {
                    suggestionRow(icon: "calendar", label: "Due Date", value: formatDate(date))
                }
                
                if let taskSize = parsed.size {
                    suggestionRow(icon: taskSize.icon, label: "Size", value: taskSize.rawValue)
                }
                
                if parsed.isRecurring, let pattern = parsed.recurrencePattern {
                    suggestionRow(icon: "repeat", label: "Recurrence", value: pattern.capitalized)
                }
            }
            
            Button {
                applySuggestions()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Apply Suggestions")
                        .font(DSFonts.body().weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(DSColors.accentPrimary)
                .foregroundColor(DSColors.onAccent)
                .cornerRadius(UIConstants.CornerRadius.standard)
            }
        }
        .padding(12)
        .background(DSColors.accentPrimary.opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.large)
    }
    
    private func suggestionRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 16)
            
            Text("\(label):")
                .font(DSFonts.body(13))
                .foregroundColor(DSColors.textSecondary)
            
            Text(value)
                .font(DSFonts.body(13).weight(.medium))
                .foregroundColor(DSColors.textPrimary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

#Preview {
    AddTaskView()
        .modelContainer(for: [TaskWork.self], inMemory: true)
}
