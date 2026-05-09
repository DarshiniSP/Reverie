//
//  RecurrencePickerView.swift
//  iAlly
//
//  Rewritten on 14/12/2025 for better state management
//

import SwiftUI

struct RecurrencePickerView: View {
    @Binding var frequency: RecurrenceFrequency
    @Binding var activeDays: [Int]?
    @Binding var weekInterval: Int?
    @Binding var monthInterval: Int?
    @Binding var monthWeek: Int?
    @Binding var customIntervalDays: Int?
    @Binding var weekdaysOnly: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    @State private var showingPreview = false
    
    private let weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Frequency picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Frequency")
                    .font(DSFonts.headline())
                
                Picker("Frequency", selection: $frequency) {
                    Text("Daily").tag(RecurrenceFrequency.daily)
                    Text("Weekly").tag(RecurrenceFrequency.weekly)
                    Text("Monthly").tag(RecurrenceFrequency.monthly)
                    Text("Custom").tag(RecurrenceFrequency.custom)
                }
                .pickerStyle(.segmented)
                .onChange(of: frequency) { oldValue, newValue in
                    if oldValue != newValue {
                        resetOptionsForFrequency(newValue)
                    }
                }
            }
            
            // Frequency-specific options
            frequencyOptionsView
            
            // Preview button - only show if configuration is valid
            if isConfigurationValid {
                Button(action: { showingPreview.toggle() }) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                        Text("Preview Next Occurrences")
                        Spacer()
                        Image(systemName: showingPreview ? "chevron.up" : "chevron.down")
                    }
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.accentPrimary)
                }
                
                if showingPreview {
                    previewView
                }
            }
        }
    }
    
    // MARK: - Frequency Options
    
    @ViewBuilder
    private var frequencyOptionsView: some View {
        switch frequency {
        case .daily:
            dailyOptionsView
        case .weekly:
            weeklyOptionsView
        case .monthly:
            monthlyOptionsView
        case .custom:
            customOptionsView
        }
    }
    
    // MARK: - Daily Options
    
    private var dailyOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Weekdays Only", isOn: $weekdaysOnly)
                .onChange(of: weekdaysOnly) { _, newValue in
                    if newValue {
                        customIntervalDays = nil
                    }
                }
            
            if !weekdaysOnly {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat every")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Stepper("\(customIntervalDays ?? 1) days", value: Binding(
                        get: { customIntervalDays ?? 1 },
                        set: { customIntervalDays = $0 > 1 ? $0 : nil }
                    ), in: 1...30)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    // MARK: - Weekly Options
    
    private var weeklyOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat every")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                
                Stepper("\(weekInterval ?? 1) weeks", value: Binding(
                    get: { weekInterval ?? 1 },
                    set: { weekInterval = $0 > 1 ? $0 : nil }
                ), in: 1...12)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("On these days")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { weekday in
                        let isSelected = activeDays?.contains(weekday) ?? false
                        Button(action: {
                            toggleWeekday(weekday)
                        }) {
                            Text(weekdayNames[weekday - 1])
                                .font(DSFonts.caption())
                                .fontWeight(.medium)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? DSColors.accentPrimary : Color(.tertiarySystemBackground))
                                .foregroundColor(isSelected ? DSColors.onAccent : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    // MARK: - Monthly Options
    
    @State private var monthlyMode: MonthlyMode = .dayOfMonth
    @State private var selectedDayOfMonth: Int = 1
    
    enum MonthlyMode {
        case dayOfMonth
        case weekOfMonth
    }
    
    private var monthlyOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Repeat every")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                
                Stepper("\(monthInterval ?? 1) months", value: Binding(
                    get: { monthInterval ?? 1 },
                    set: { monthInterval = $0 > 1 ? $0 : nil }
                ), in: 1...12)
            }
            
            Divider()
            
            Picker("Mode", selection: $monthlyMode) {
                Text("Day of Month").tag(MonthlyMode.dayOfMonth)
                Text("Week of Month").tag(MonthlyMode.weekOfMonth)
            }
            .pickerStyle(.segmented)
            .onChange(of: monthlyMode) { _, newMode in
                if newMode == .weekOfMonth {
                    monthWeek = 1
                    activeDays = activeDays?.isEmpty ?? true ? [1] : activeDays
                } else {
                    monthWeek = nil
                    activeDays = [selectedDayOfMonth]
                }
            }
            
            if monthlyMode == .dayOfMonth {
                VStack(alignment: .leading, spacing: 8) {
                    Text("On day")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    HStack {
                        Stepper("Day \(selectedDayOfMonth)", value: $selectedDayOfMonth, in: 1...31)
                            .onChange(of: selectedDayOfMonth) { _, newValue in
                                activeDays = [newValue]
                            }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Week of month")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Picker("Week", selection: Binding(
                        get: { monthWeek ?? 1 },
                        set: { monthWeek = $0 }
                    )) {
                        Text("First").tag(1)
                        Text("Second").tag(2)
                        Text("Third").tag(3)
                        Text("Fourth").tag(4)
                        Text("Last").tag(-1)
                    }
                    .pickerStyle(.segmented)
                    
                    Text("On day")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isSelected = activeDays?.contains(weekday) ?? false
                            Button(action: {
                                activeDays = [weekday]
                            }) {
                                Text(String(weekdayNames[weekday - 1].prefix(3)))
                                    .font(DSFonts.caption())
                                    .fontWeight(.medium)
                                    .frame(width: 36, height: 36)
                                    .background(isSelected ? DSColors.accentPrimary : Color(.tertiarySystemBackground))
                                    .foregroundColor(isSelected ? DSColors.onAccent : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
        .onAppear {
            // Initialize selectedDayOfMonth from activeDays if available
            if let firstDay = activeDays?.first, monthlyMode == .dayOfMonth {
                selectedDayOfMonth = firstDay
            } else if activeDays == nil || activeDays?.isEmpty == true {
                // Set default day of month to current day
                selectedDayOfMonth = Calendar.current.component(.day, from: Date())
                activeDays = [selectedDayOfMonth]
            }
        }
    }
    
    // MARK: - Custom Options
    
    @State private var customMode: CustomMode = .weekdays
    
    enum CustomMode {
        case weekdays
        case interval
    }
    
    private var customOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Mode", selection: $customMode) {
                Text("Specific Weekdays").tag(CustomMode.weekdays)
                Text("Every N Days").tag(CustomMode.interval)
            }
            .pickerStyle(.segmented)
            .onChange(of: customMode) { _, newMode in
                if newMode == .interval {
                    customIntervalDays = 1
                    activeDays = nil
                } else {
                    customIntervalDays = nil
                    activeDays = nil
                }
            }
            
            if customMode == .weekdays {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select days of the week")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    HStack(spacing: 8) {
                        ForEach(1...7, id: \.self) { weekday in
                            let isSelected = activeDays?.contains(weekday) ?? false
                            Button(action: {
                                toggleWeekday(weekday)
                            }) {
                                Text(weekdayNames[weekday - 1])
                                    .font(DSFonts.caption())
                                    .fontWeight(.medium)
                                    .frame(width: 36, height: 36)
                                    .background(isSelected ? DSColors.accentPrimary : Color(.tertiarySystemBackground))
                                    .foregroundColor(isSelected ? DSColors.onAccent : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Text("Select which days of the week this routine should occur")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat every")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Stepper("\(customIntervalDays ?? 1) days", value: Binding(
                        get: { customIntervalDays ?? 1 },
                        set: { customIntervalDays = $0 }
                    ), in: 1...365)
                    
                    Text("Routine will occur every \(customIntervalDays ?? 1) days from today")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    // MARK: - Preview
    
    private var previewView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next occurrences:")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
            
            let dates = generatePreviewDates()
            if dates.isEmpty {
                Text("Please select at least one day")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.error)
            } else {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    HStack {
                        Image(systemName: "calendar")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.accentPrimary)
                        Text(formatDate(date))
                            .font(DSFonts.caption())
                    }
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    // MARK: - Helper Methods
    
    private var isConfigurationValid: Bool {
        switch frequency {
        case .daily:
            return true
        case .weekly:
            return activeDays != nil && !activeDays!.isEmpty
        case .monthly:
            return activeDays != nil && !activeDays!.isEmpty
        case .custom:
            // Valid if either weekdays selected OR interval set
            if customMode == .weekdays {
                return activeDays != nil && !activeDays!.isEmpty
            } else {
                return customIntervalDays != nil && customIntervalDays! > 0
            }
        }
    }
    
    private func toggleWeekday(_ weekday: Int) {
        var currentDays = activeDays ?? []
        if currentDays.contains(weekday) {
            currentDays.removeAll { $0 == weekday }
        } else {
            currentDays.append(weekday)
        }
        activeDays = currentDays.isEmpty ? nil : currentDays.sorted()
    }
    
    private func resetOptionsForFrequency(_ freq: RecurrenceFrequency) {
        weekInterval = nil
        monthInterval = nil
        monthWeek = nil
        customIntervalDays = nil
        weekdaysOnly = false
        activeDays = nil
        showingPreview = false  // Reset preview when frequency changes
        selectedDayOfMonth = Calendar.current.component(.day, from: Date())
        
        switch freq {
        case .daily:
            break
        case .weekly:
            weekInterval = 1
            // Don't pre-select days for weekly
        case .monthly:
            monthInterval = 1
            monthlyMode = .dayOfMonth
            // Set default to current day of month (1-31)
            activeDays = [selectedDayOfMonth]
        case .custom:
            // Custom requires either interval or weekdays
            // Don't set defaults to avoid confusion
            break
        }
    }
    
    private func generatePreviewDates() -> [Date] {
        // Create a temporary routine for preview
        let routine = Routine(
            title: "Preview",
            lifeDomain: .personal,
            icon: "calendar",
            colorHex: "#000000",
            frequency: frequency,
            activeDays: activeDays,
            timeOfDay: nil,
            endDate: endDate
        )
        routine.startDate = startDate
        routine.weekInterval = weekInterval
        routine.monthInterval = monthInterval
        routine.monthWeek = monthWeek
        routine.customIntervalDays = customIntervalDays
        routine.weekdaysOnly = weekdaysOnly
        
        // Use actual start/end dates from the routine form
        let dates = RecurrenceRuleBuilder.shared.occurrences(from: startDate, to: endDate, routine: routine)
        
        return Array(dates.prefix(5))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    RecurrencePickerView(
        frequency: .constant(.weekly),
        activeDays: .constant([2, 3, 4, 5, 6]),
        weekInterval: .constant(1),
        monthInterval: .constant(nil),
        monthWeek: .constant(nil),
        customIntervalDays: .constant(nil),
        weekdaysOnly: .constant(false),
        startDate: .constant(Date()),
        endDate: .constant(Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date())
    )
    .padding()
}
