//
//  CalendarEventsSection.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData
import EventKit

struct CalendarEventsSection: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var events: [EKEvent] = []
    @State private var isLoading = false
    
    let date: Date
    
    var body: some View {
        if calendarManager.isCalendarEnabled && calendarManager.hasCalendarAccess {
            VStack(alignment: .leading, spacing: 12) {
                // Section Header
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(DSColors.accentPrimary)
                    
                    Text("Calendar Events")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Spacer()
                    
                    if !events.isEmpty {
                        Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    
                    Button {
                        refreshEvents()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Events List
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding()
                } else if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 32))
                            .foregroundColor(DSColors.textSecondary)
                        
                        Text("No events scheduled")
                            .font(DSFonts.body(14))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    VStack(spacing: 0) {
                        ForEach(events, id: \.eventIdentifier) { event in
                            CalendarEventCard(event: event)
                            
                            if event.eventIdentifier != events.last?.eventIdentifier {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(DSColors.canvasSecondary)
                    .cornerRadius(UIConstants.CornerRadius.large)
                    .padding(.horizontal)
                }
            }
            .onAppear {
                loadEvents()
            }
            .onChange(of: date) { _, _ in
                loadEvents()
            }
            .onChange(of: calendarManager.selectedCalendars) { _, _ in
                loadEvents()
            }
        }
    }
    
    private func loadEvents() {
        isLoading = true
        // Small delay to avoid UI stuttering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            events = calendarManager.fetchEvents(for: date)
            isLoading = false
        }
    }
    
    private func refreshEvents() {
        loadEvents()
    }
}

// MARK: - Calendar Event Card
struct CalendarEventCard: View {
    @Environment(\.modelContext) private var modelContext
    let event: EKEvent
    @State private var showDetails = false
    @State private var showCreateTask = false
    @State private var showSuccess = false
    
    var body: some View {
        Button {
            showDetails = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Time indicator
                VStack(spacing: 4) {
                    if event.isAllDay {
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DSColors.warning)
                    } else {
                        Text(startTime)
                            .font(DSFonts.label(12).monospacedDigit())
                            .foregroundColor(timeColor)
                    }
                    
                    if isHappening {
                        Circle()
                            .fill(DSColors.success)
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(width: 48)
                
                // Calendar color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(event.calendar.cgColor))
                    .frame(width: 4)
                
                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(DSFonts.body(15))
                        .foregroundColor(DSColors.textPrimary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if !event.isAllDay {
                            Text(timeRange)
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                        } else {
                            Text("All day")
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        Text("•")
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                        
                        Text(event.calendar.title)
                            .font(DSFonts.caption(12))
                            .foregroundColor(Color(event.calendar.cgColor))
                    }
                    
                    // Location if available
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Status badges
                    HStack(spacing: 6) {
                        if isHappening {
                            StatusBadge(text: "Happening now", color: DSColors.success)
                        } else if isUpcoming {
                            StatusBadge(text: "Upcoming", color: DSColors.warning)
                        }
                        
                        if event.hasRecurrenceRules {
                            Image(systemName: "repeat")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        if event.hasAlarms {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DSColors.textSecondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .leading) {
            Button {
                createTaskFromEvent()
            } label: {
                Label("Create Task", systemImage: "checkmark.circle.fill")
            }
            .tint(DSColors.success)
        }
        .sheet(isPresented: $showDetails) {
            CalendarEventDetailView(event: event, modelContext: modelContext)
        }
        .alert("Task Created", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("A new task has been created from this calendar event.")
        }
    }
    
    private func createTaskFromEvent() {
        let task = TaskWork(title: event.title)
        
        // Set due date to event start time
        task.dueDate = event.startDate
        
        // Add event details and location to task detail
        var detail = ""
        if let notes = event.notes, !notes.isEmpty {
            detail += notes + "\n\n"
        }
        if let location = event.location, !location.isEmpty {
            detail += "📍 Location: \(location)"
        }
        task.detail = detail.isEmpty ? nil : detail
        
        // Estimate size based on event duration
        let duration = CalendarManager.shared.duration(for: event)
        if duration < 30 {
            task.size = TaskSize.small
        } else if duration <= 60 {
            task.size = TaskSize.medium
        } else {
            task.size = TaskSize.large
        }
        
        // Add calendar category
        task.category = event.calendar.title
        
        modelContext.insert(task)
        try? modelContext.save()
        
        showSuccess = true
    }
    
    private var startTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate)
    }
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        
        return "\(start) - \(end)"
    }
    
    private var isHappening: Bool {
        CalendarManager.shared.isHappening(now: event)
    }
    
    private var isUpcoming: Bool {
        CalendarManager.shared.isUpcoming(event)
    }
    
    private var timeColor: Color {
        if isHappening {
            return DSColors.success
        } else if isUpcoming {
            return DSColors.warning
        } else {
            return DSColors.textSecondary
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Calendar Event Detail View
struct CalendarEventDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let event: EKEvent
    let modelContext: ModelContext
    
    @State private var showSuccess = false
    @State private var taskCreated = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(DSColors.accentPrimary)
                        Text(event.calendar.title)
                            .foregroundColor(Color(event.calendar.cgColor))
                    }
                }
                
                Section("Event Details") {
                    DetailRow(icon: "text.alignleft", label: "Title", value: event.title)
                    
                    if event.isAllDay {
                        DetailRow(icon: "calendar", label: "Date", value: formatDate(event.startDate))
                        DetailRow(icon: "sun.max", label: "Duration", value: "All day")
                    } else {
                        DetailRow(icon: "clock", label: "Start", value: formatDateTime(event.startDate))
                        DetailRow(icon: "clock.fill", label: "End", value: formatDateTime(event.endDate))
                        DetailRow(icon: "hourglass", label: "Duration", value: "\(CalendarManager.shared.duration(for: event)) minutes")
                    }
                }
                
                if let location = event.location, !location.isEmpty {
                    Section("Location") {
                        Text(location)
                    }
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                    }
                }
                
                if event.hasRecurrenceRules, let rules = event.recurrenceRules, !rules.isEmpty {
                    Section("Recurrence") {
                        ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                            Text(formatRecurrence(rule))
                        }
                    }
                }
                
                if event.hasAlarms, let alarms = event.alarms, !alarms.isEmpty {
                    Section("Reminders") {
                        ForEach(Array(alarms.enumerated()), id: \.offset) { _, alarm in
                            let offset = alarm.relativeOffset
                            Text(formatAlarmOffset(offset))
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        createTaskFromEvent()
                    } label: {
                        Label(taskCreated ? "Task Created" : "Create Task", 
                              systemImage: taskCreated ? "checkmark.circle.fill" : "plus.circle.fill")
                            .foregroundColor(taskCreated ? .secondary : .green)
                    }
                    .disabled(taskCreated)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }
            .alert("Task Created", isPresented: $showSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("A new task has been created from this calendar event.")
            }
        }
    }
    
    private func createTaskFromEvent() {
        let task = TaskWork(title: event.title)
        
        // Set due date to event start time
        task.dueDate = event.startDate
        
        // Add event details and location to task detail
        var detail = ""
        if let notes = event.notes, !notes.isEmpty {
            detail += notes + "\n\n"
        }
        if let location = event.location, !location.isEmpty {
            detail += "📍 Location: \(location)"
        }
        task.detail = detail.isEmpty ? nil : detail
        
        // Estimate size based on event duration
        let duration = CalendarManager.shared.duration(for: event)
        if duration < 30 {
            task.size = TaskSize.small
        } else if duration <= 60 {
            task.size = TaskSize.medium
        } else {
            task.size = TaskSize.large
        }
        
        // Add calendar category
        task.category = event.calendar.title
        
        modelContext.insert(task)
        try? modelContext.save()
        
        // Mark task as created to prevent duplicates
        taskCreated = true
        showSuccess = true
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatRecurrence(_ rule: EKRecurrenceRule) -> String {
        switch rule.frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        @unknown default: return "Recurring"
        }
    }
    
    private func formatAlarmOffset(_ offset: TimeInterval) -> String {
        let minutes = Int(abs(offset) / 60)
        if minutes < 60 {
            return "\(minutes) minutes before"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s") before"
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(DSColors.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(DSColors.textPrimary)
        }
    }
}

#Preview {
    CalendarEventsSection(date: Date())
}
