//
//  RecurringTaskInstanceView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

struct RecurringTaskInstanceView: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMonth = Date()
    @State private var showingSkipSheet = false
    @State private var showingRescheduleSheet = false
    @State private var selectedDate: Date?
    @State private var skipReason = ""
    @State private var rescheduleDate = Date()
    @State private var rescheduleReason = ""
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Month navigation
                    HStack {
                        Button(action: { previousMonth() }) {
                            Image(systemName: "chevron.left")
                                .font(DSFonts.headline())
                        }
                        
                        Spacer()
                        
                        Text(monthYearText)
                            .font(DSFonts.headline())
                        
                        Spacer()
                        
                        Button(action: { nextMonth() }) {
                            Image(systemName: "chevron.right")
                                .font(DSFonts.headline())
                        }
                    }
                    .padding()
                    
                    // Calendar grid
                    CalendarGridView(
                        selectedMonth: selectedMonth,
                        routine: routine,
                        onDateTap: { date in
                            selectedDate = date
                        }
                    )
                    
                    Divider()
                    
                    // Upcoming instances
                    UpcomingInstancesSection(routine: routine)
                    
                    // Exceptions list
                    if !routine.exceptions.isEmpty {
                        ExceptionsSection(routine: routine)
                    }
                    
                    // Instance modifications
                    if !routine.instanceModifications.isEmpty {
                        ModificationsSection(routine: routine)
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSkipSheet) {
                if let date = selectedDate {
                    SkipInstanceSheet(
                        date: date,
                        routine: routine,
                        reason: $skipReason,
                        onSkip: {
                            RecurrenceRuleBuilder.shared.skipInstance(date: date, routine: routine, reason: skipReason.isEmpty ? nil : skipReason)
                            try? modelContext.save()
                            showingSkipSheet = false
                            skipReason = ""
                        }
                    )
                }
            }
            .sheet(isPresented: $showingRescheduleSheet) {
                if let date = selectedDate {
                    RescheduleInstanceSheet(
                        originalDate: date,
                        routine: routine,
                        newDate: $rescheduleDate,
                        reason: $rescheduleReason,
                        onReschedule: {
                            RecurrenceRuleBuilder.shared.rescheduleInstance(from: date, to: rescheduleDate, routine: routine, reason: rescheduleReason.isEmpty ? nil : rescheduleReason)
                            try? modelContext.save()
                            showingRescheduleSheet = false
                            rescheduleReason = ""
                        }
                    )
                }
            }
            .actionSheet(item: Binding(
                get: { selectedDate.map { ActionSheetDate(date: $0) } },
                set: { selectedDate = $0?.date }
            )) { dateWrapper in
                ActionSheet(
                    title: Text(formatDate(dateWrapper.date)),
                    buttons: [
                        .default(Text("Skip This Instance")) {
                            showingSkipSheet = true
                        },
                        .default(Text("Reschedule")) {
                            rescheduleDate = dateWrapper.date
                            showingRescheduleSheet = true
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var monthYearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private func previousMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
    }
    
    private func nextMonth() {
        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    let selectedMonth: Date
    let routine: Routine
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(DSFonts.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            routine: routine,
                            isCurrentMonth: isCurrentMonth(date),
                            onTap: { onDateTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
    
    private var calendarDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
            return []
        }
        
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        
        // Get the first day of the week for the first day of the month
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        
        // Calculate padding days for the start
        let paddingDays = firstWeekday - 1
        
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        
        // Add all days in the month
        var currentDate = monthStart
        while currentDate < monthEnd {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month)
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let routine: Routine
    let isCurrentMonth: Bool
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: dayWeight))
                    .foregroundColor(dayColor)
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .opacity(hasStatus ? 1 : 0)
            }
            .frame(width: 44, height: 44)
            .background(dayBackground)
            .cornerRadius(UIConstants.CornerRadius.standard)
        }
    }
    
    private var dayWeight: Font.Weight {
        calendar.isDateInToday(date) ? .bold : .regular
    }
    
    private var dayColor: Color {
        if !isCurrentMonth {
            return .gray.opacity(0.5)
        } else if calendar.isDateInToday(date) {
            return DSColors.accentPrimary
        } else {
            return .primary
        }
    }
    
    private var dayBackground: Color {
        if isOccurrence {
            return DSColors.accentPrimary.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var isOccurrence: Bool {
        RecurrenceRuleBuilder.shared.isOccurrence(date: date, routine: routine)
    }
    
    private var hasStatus: Bool {
        let key = dateKey(date)
        if let modification = routine.instanceModifications[key] {
            return modification.isSkipped || modification.isRescheduled
        }
        return routine.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: date) })
    }
    
    private var statusColor: Color {
        let key = dateKey(date)
        if let modification = routine.instanceModifications[key] {
            if modification.isSkipped {
                return DSColors.error
            } else if modification.isRescheduled {
                return DSColors.warning
            }
        }
        if routine.exceptions.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            return .gray
        }
        return DSColors.success
    }
    
    private func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - Upcoming Instances Section

struct UpcomingInstancesSection: View {
    let routine: Routine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(DSFonts.headline())
            
            if upcomingDates.isEmpty {
                Text("No upcoming instances")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
                    .padding()
            } else {
                ForEach(upcomingDates, id: \.self) { date in
                    InstanceRow(date: date, routine: routine)
                }
            }
        }
    }
    
    private var upcomingDates: [Date] {
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let dates = RecurrenceRuleBuilder.shared.occurrences(from: Date(), to: endDate, routine: routine)
        return Array(dates.prefix(7))
    }
}

// MARK: - Instance Row

struct InstanceRow: View {
    let date: Date
    let routine: Routine
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(date))
                    .font(DSFonts.label())
                
                if let modification = getModification(for: date) {
                    if modification.isSkipped {
                        Text("Skipped")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.error)
                    } else if let newDate = modification.newDate {
                        Text("Rescheduled to \(formatDate(newDate))")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.warning)
                    }
                }
            }
            
            Spacer()
            
            if let modification = getModification(for: date) {
                Image(systemName: modification.isSkipped ? "xmark.circle.fill" : "calendar.badge.clock")
                    .foregroundColor(modification.isSkipped ? .red : .orange)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(DSColors.success)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func getModification(for date: Date) -> InstanceModification? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return routine.instanceModifications[key]
    }
}

// MARK: - Exceptions Section

struct ExceptionsSection: View {
    let routine: Routine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exceptions")
                .font(DSFonts.headline())
            
            ForEach(routine.exceptions.sorted(by: >), id: \.self) { date in
                HStack {
                    Text(formatDate(date))
                        .font(DSFonts.label())
                    
                    Spacer()
                    
                    Button(action: {
                        RecurrenceRuleBuilder.shared.removeException(date: date, routine: routine)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DSColors.error)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(UIConstants.CornerRadius.standard)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Modifications Section

struct ModificationsSection: View {
    let routine: Routine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Modifications")
                .font(DSFonts.headline())
            
            ForEach(sortedModifications, id: \.key) { item in
                ModificationRow(modification: item.value, routine: routine)
            }
        }
    }
    
    private var sortedModifications: [(key: String, value: InstanceModification)] {
        routine.instanceModifications.sorted { $0.value.instanceDate > $1.value.instanceDate }
    }
}

struct ModificationRow: View {
    let modification: InstanceModification
    let routine: Routine
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatDate(modification.instanceDate))
                    .font(DSFonts.label())
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    RecurrenceRuleBuilder.shared.removeModification(date: modification.instanceDate, routine: routine)
                    try? modelContext.save()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            HStack {
                Image(systemName: modification.isSkipped ? "xmark.circle.fill" : "calendar.badge.clock")
                    .foregroundColor(modification.isSkipped ? .red : .orange)
                
                if modification.isSkipped {
                    Text("Skipped")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.error)
                } else if let newDate = modification.newDate {
                    Text("Rescheduled to \(formatDate(newDate))")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.warning)
                }
            }
            
            if let reason = modification.reason, !reason.isEmpty {
                Text(reason)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(UIConstants.CornerRadius.standard)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Skip Instance Sheet

struct SkipInstanceSheet: View {
    let date: Date
    let routine: Routine
    @Binding var reason: String
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skip instance on")
                        .font(DSFonts.headline())
                    Text(formatDate(date))
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason (optional)")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    TextEditor(text: $reason)
                        .frame(height: 100)
                        .padding(8)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                }
                
                Spacer()
                
                Button(action: {
                    onSkip()
                    dismiss()
                }) {
                    Text("Skip Instance")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DSColors.error)
                        .foregroundColor(DSColors.onAccent)
                        .cornerRadius(UIConstants.CornerRadius.medium)
                }
            }
            .padding()
            .navigationTitle("Skip Instance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

// MARK: - Reschedule Instance Sheet

struct RescheduleInstanceSheet: View {
    let originalDate: Date
    let routine: Routine
    @Binding var newDate: Date
    @Binding var reason: String
    let onReschedule: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reschedule from")
                        .font(DSFonts.headline())
                    Text(formatDate(originalDate))
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                DatePicker("New date", selection: $newDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason (optional)")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    TextEditor(text: $reason)
                        .frame(height: 100)
                        .padding(8)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                }
                
                Spacer()
                
                Button(action: {
                    onReschedule()
                    dismiss()
                }) {
                    Text("Reschedule")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DSColors.warning)
                        .foregroundColor(DSColors.onAccent)
                        .cornerRadius(UIConstants.CornerRadius.medium)
                }
            }
            .padding()
            .navigationTitle("Reschedule Instance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct ActionSheetDate: Identifiable {
    let id = UUID()
    let date: Date
}

#Preview {
    RecurringTaskInstanceView(routine: Routine(
        title: "Morning Meditation",
        lifeDomain: .health,
        frequency: .daily,
        isActive: true
    ))
}
