//
//  AddRoutineView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct AddRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    var routine: Routine? // Optional routine for edit mode
    
    @State private var title = ""
    @State private var lifeDomain = LifeDomain.health
    @State private var frequency = RecurrenceFrequency.daily
    @State private var selectedDays: Set<Int> = []
    @State private var activeDays: [Int]? = nil
    @State private var weekInterval: Int? = nil
    @State private var monthInterval: Int? = nil
    @State private var monthWeek: Int? = nil
    @State private var customIntervalDays: Int? = nil
    @State private var weekdaysOnly = false
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var timeOfDay: Date?
    @State private var useTimeOfDay = false
    @State private var selectedIcon = "repeat.circle.fill"
    @State private var selectedColor = LifeDomain.health.defaultColor
    @State private var hasManuallySelectedIcon = false
    
    let iconOptions = ["repeat.circle.fill", "flame.fill", "heart.fill", "figure.run", "book.fill", "brain.head.profile", "bed.double.fill", "leaf.fill"]
    let colorOptions = ["#4C8BF5", "#5856D6", "#AF52DE", "#FF9500", "#FF3B30", "#34C759", "#00C7BE", "#FF2D55"]
    
    let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    // Routine Templates
    struct RoutineTemplate {
        let name: String
        let icon: String
        let domain: LifeDomain
        let frequency: RecurrenceFrequency
        let activeDays: Set<Int>?
        let timeOfDay: Date?
        let color: String
    }
    
    let templates = [
        RoutineTemplate(
            name: "Morning School Routine",
            icon: "backpack.fill",
            domain: .learning,
            frequency: .custom,
            activeDays: [1, 2, 3, 4, 5], // Mon-Fri
            timeOfDay: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)),
            color: "#AF52DE"
        ),
        RoutineTemplate(
            name: "Morning Run",
            icon: "figure.run",
            domain: .health,
            frequency: .custom,
            activeDays: [1, 3, 5], // Mon, Wed, Fri
            timeOfDay: Calendar.current.date(from: DateComponents(hour: 6, minute: 30)),
            color: "#FF3B30"
        ),
        RoutineTemplate(
            name: "Evening Meditation",
            icon: "brain.head.profile",
            domain: .personal,
            frequency: .daily,
            activeDays: nil,
            timeOfDay: Calendar.current.date(from: DateComponents(hour: 20, minute: 0)),
            color: "#5856D6"
        )
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                // Hide templates when editing
                if routine == nil {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<templates.count, id: \.self) { index in
                                TemplateCard(template: templates[index]) {
                                    applyTemplate(templates[index])
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Quick Start Templates")
                } footer: {
                    Text("Tap a template to quickly create a common routine")
                        .font(DSFonts.caption())
                }
                }
                
                Section {
                    TextField("Enter routine name", text: $title)
                } header: {
                    Text("Routine Name")
                } footer: {
                    Text("Choose a name that describes the habit you want to build")
                        .font(DSFonts.caption())
                }
                
                Section {
                    Picker("Domain", selection: $lifeDomain) {
                        ForEach(LifeDomain.allCases, id: \.self) { domain in
                            Label(domain.rawValue, systemImage: domain.icon)
                                .tag(domain)
                        }
                    }
                    .onChange(of: lifeDomain) { oldValue, newValue in
                        selectedColor = newValue.defaultColor
                        // Only auto-set icon if user hasn't manually selected one
                        if !hasManuallySelectedIcon {
                            selectedIcon = newValue.icon
                        }
                    }
                } header: {
                    Text("Life Domain")
                } footer: {
                    Text("Which area of your life does this routine support?")
                        .font(DSFonts.caption())
                }
                
                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newValue in
                            // Ensure end date is always after start date
                            if endDate <= newValue {
                                endDate = Calendar.current.date(byAdding: .day, value: 14, to: newValue) ?? newValue
                            }
                        }
                    
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    
                    RecurrencePickerView(
                        frequency: $frequency,
                        activeDays: $activeDays,
                        weekInterval: $weekInterval,
                        monthInterval: $monthInterval,
                        monthWeek: $monthWeek,
                        customIntervalDays: $customIntervalDays,
                        weekdaysOnly: $weekdaysOnly,
                        startDate: $startDate,
                        endDate: $endDate
                    )
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("Select dates first, then configure how often this routine should occur")
                        .font(DSFonts.caption())
                }
                
                Section {
                    Toggle("Set Preferred Time", isOn: $useTimeOfDay)
                    
                    if useTimeOfDay {
                        DatePicker("Time", selection: Binding(
                            get: { timeOfDay ?? Date() },
                            set: { timeOfDay = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Time of Day (Optional)")
                } footer: {
                    Text("Set a specific time to receive reminders for this routine")
                        .font(DSFonts.caption())
                }
                
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(Array(iconOptions.enumerated()), id: \.element) { index, icon in
                            IconSelectionButton(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                action: {
                                    selectedIcon = icon
                                    hasManuallySelectedIcon = true
                                }
                            )
                        }
                    }
                } header: {
                    Text("Icon")
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadRoutineData()
            }
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
                        saveRoutine()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.isEmpty || !isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        if frequency == .weekly || frequency == .custom {
            return !(activeDays ?? []).isEmpty
        }
        return true
    }
    
    private var frequencyFooterText: String {
        switch frequency {
        case .daily:
            return "This routine will repeat every day"
        case .weekly:
            return "Select which days of the week to repeat this routine"
        case .monthly:
            return "This routine will repeat once per month"
        case .custom:
            return "Select specific days for this routine"
        }
    }
    
    private func saveRoutine() {
        if let existingRoutine = routine {
            // Check if critical recurrence settings changed
            let frequencyChanged = existingRoutine.frequency != frequency
            let daysChanged = existingRoutine.activeDays != activeDays
            
            // Compare dates (handling optionals for backward compatibility)
            let oldStartDate = Calendar.current.startOfDay(for: existingRoutine.startDate ?? existingRoutine.createdAt)
            let newStartDate = Calendar.current.startOfDay(for: startDate)
            let startDateChanged = oldStartDate != newStartDate
            
            let oldEndDate = existingRoutine.endDate.map { Calendar.current.startOfDay(for: $0) }
            let newEndDate = Calendar.current.startOfDay(for: endDate)
            let endDateChanged = oldEndDate != newEndDate
            
            let intervalsChanged = existingRoutine.weekInterval != weekInterval || 
                                 existingRoutine.monthInterval != monthInterval ||
                                 existingRoutine.customIntervalDays != customIntervalDays
            
            let recurrenceChanged = frequencyChanged || daysChanged || startDateChanged || endDateChanged || intervalsChanged
            
            // Update existing routine
            existingRoutine.title = title
            existingRoutine.lifeDomain = lifeDomain
            existingRoutine.icon = selectedIcon
            existingRoutine.colorHex = selectedColor
            existingRoutine.frequency = frequency
            existingRoutine.activeDays = activeDays
            existingRoutine.weekInterval = weekInterval
            existingRoutine.monthInterval = monthInterval
            existingRoutine.monthWeek = monthWeek
            existingRoutine.customIntervalDays = customIntervalDays
            existingRoutine.weekdaysOnly = weekdaysOnly
            existingRoutine.timeOfDay = useTimeOfDay ? timeOfDay : nil
            existingRoutine.startDate = startDate
            existingRoutine.endDate = endDate
            
            // If recurrence settings changed, clean up future tasks and regenerate
            if recurrenceChanged {
                cleanupAndRegenerateTasks(for: existingRoutine)
            }
        } else {
            // Create new routine
            let newRoutine = Routine(
                title: title,
                lifeDomain: lifeDomain,
                icon: selectedIcon,
                colorHex: selectedColor,
                frequency: frequency,
                activeDays: activeDays,
                timeOfDay: useTimeOfDay ? timeOfDay : nil,
                endDate: endDate
            )
            newRoutine.startDate = startDate
            newRoutine.weekInterval = weekInterval
            newRoutine.monthInterval = monthInterval
            newRoutine.monthWeek = monthWeek
            newRoutine.customIntervalDays = customIntervalDays
            newRoutine.weekdaysOnly = weekdaysOnly
            modelContext.insert(newRoutine)
            
            // Generate tasks immediately for the new routine
            Task {
                await RoutineManager.shared.generateTasksForRoutine(newRoutine, context: modelContext)
            }
        }
        try? modelContext.save()
        dismiss()
    }
    
    private func loadRoutineData() {
        guard let routine = routine else { return }
        title = routine.title
        lifeDomain = routine.lifeDomain
        frequency = routine.frequency
        activeDays = routine.activeDays
        weekInterval = routine.weekInterval
        monthInterval = routine.monthInterval
        monthWeek = routine.monthWeek
        customIntervalDays = routine.customIntervalDays
        weekdaysOnly = routine.weekdaysOnly
        selectedDays = Set(routine.activeDays ?? [])
        timeOfDay = routine.timeOfDay
        useTimeOfDay = routine.timeOfDay != nil
        startDate = routine.startDate ?? Date()
        endDate = routine.endDate ?? Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        selectedIcon = routine.icon
        selectedColor = routine.colorHex
        hasManuallySelectedIcon = true
    }
    
    private func applyTemplate(_ template: RoutineTemplate) {
        title = template.name
        hasManuallySelectedIcon = true  // Set BEFORE changing domain
        lifeDomain = template.domain
        frequency = template.frequency
        selectedIcon = template.icon
        selectedColor = template.color
        
        if let days = template.activeDays {
            selectedDays = days
            activeDays = Array(days).sorted()
        } else {
            selectedDays = []
            activeDays = nil
        }
        
        if let time = template.timeOfDay {
            useTimeOfDay = true
            timeOfDay = time
        }
    }
    
    /// Clean up future tasks and regenerate when recurrence settings change
    private func cleanupAndRegenerateTasks(for routine: Routine) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Delete all incomplete future tasks generated from this routine
        if let tasks = routine.generatedTasks {
            for task in tasks where !task.isCompleted {
                if let taskDueDate = task.dueDate, calendar.startOfDay(for: taskDueDate) >= today {
                    modelContext.delete(task)
                }
            }
        }
        
        // Reset last generated date to force regeneration
        routine.lastGeneratedDate = nil
        
        // Save changes
        try? modelContext.save()
        
        // Note: RoutineManager will regenerate tasks on next app launch or when explicitly called
    }
}

// MARK: - Icon Selection Button
struct IconSelectionButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(DSFonts.title())
                .foregroundColor(isSelected ? DSColors.accentPrimary : DSColors.textSecondary)
                .frame(width: 60, height: 60)
                .background(isSelected ? DSColors.accentPrimary.opacity(0.1) : DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Card
struct TemplateCard: View {
    let template: AddRoutineView.RoutineTemplate
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.icon)
                    .font(DSFonts.headline())
                    .foregroundColor(Color(hex: template.color))
                    .frame(width: 40, height: 40)
                    .background(Color(hex: template.color).opacity(0.15))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                
                Text(template.name)
                    .font(DSFonts.label(13))
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 4) {
                    Image(systemName: template.domain.icon)
                        .font(DSFonts.caption())
                    Text(template.domain.rawValue)
                        .font(DSFonts.caption())
                }
                .foregroundColor(DSColors.textSecondary)
            }
            .frame(width: 120)
            .padding(12)
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AddRoutineView()
        .modelContainer(for: [Routine.self], inMemory: true)
        .onAppear {
            // Load data when editing
            // loadRoutineData() will be called automatically
        }
}
