//
//  CalendarSettingsView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var showPermissionAlert = false
    @State private var availableCalendars: [EKCalendar] = []
    
    var body: some View {
        List {
            // Calendar Integration Toggle
            Section {
                Toggle(isOn: $calendarManager.isCalendarEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.accentPrimary)
                            .frame(width: 32, height: 32)
                            .background(DSColors.accentPrimary.opacity(0.1))
                            .cornerRadius(UIConstants.CornerRadius.standard)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calendar Integration")
                                .font(DSFonts.body())
                            
                            Text(statusText)
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
                .onChange(of: calendarManager.isCalendarEnabled) { _, newValue in
                    if newValue && !calendarManager.hasCalendarAccess {
                        showPermissionAlert = true
                        calendarManager.isCalendarEnabled = false
                    } else {
                        calendarManager.saveSettings()
                    }
                }
            } header: {
                Text("Integration")
            } footer: {
                Text("Show your calendar events alongside tasks in the Today view")
            }
            
            // Calendar Selection (if enabled and has access)
            if calendarManager.isCalendarEnabled && calendarManager.hasCalendarAccess {
                Section {
                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        CalendarRowView(
                            calendar: calendar,
                            isSelected: calendarManager.selectedCalendars.contains(calendar.calendarIdentifier)
                        ) {
                            toggleCalendar(calendar)
                        }
                    }
                } header: {
                    HStack {
                        Text("Calendars to Show")
                        Spacer()
                        if !calendarManager.selectedCalendars.isEmpty {
                            Text("\(calendarManager.selectedCalendars.count) selected")
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                } footer: {
                    Text("Select which calendars to display. If none selected, all calendars will be shown.")
                }
                
                Section {
                    Button {
                        selectAllCalendars()
                    } label: {
                        Label("Select All", systemImage: "checklist")
                    }
                    
                    Button {
                        deselectAllCalendars()
                    } label: {
                        Label("Deselect All", systemImage: "xmark.circle")
                    }
                }
            }
            
            // Permission Request
            if !calendarManager.hasCalendarAccess {
                Section {
                    Button {
                        _Concurrency.Task {
                            await requestCalendarAccess()
                        }
                    } label: {
                        Label("Grant Calendar Access", systemImage: "calendar.badge.plus")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                } footer: {
                    Text("iAlly needs access to your calendars to show events alongside your tasks")
                }
            }
            
            // Preview
            if calendarManager.isCalendarEnabled && calendarManager.hasCalendarAccess {
                Section {
                    let todayEvents = calendarManager.fetchTodayEvents()
                    
                    if todayEvents.isEmpty {
                        Text("No events today")
                            .foregroundColor(DSColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(todayEvents.prefix(3), id: \.eventIdentifier) { event in
                            CalendarEventPreviewRow(event: event)
                        }
                        
                        if todayEvents.count > 3 {
                            Text("+ \(todayEvents.count - 3) more events today")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                } header: {
                    Text("Today's Events Preview")
                }
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalendars()
        }
        .alert("Calendar Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant calendar access in Settings to use calendar integration")
        }
    }
    
    private var statusText: String {
        if !calendarManager.hasCalendarAccess {
            return "Calendar access required"
        } else if calendarManager.isCalendarEnabled {
            return "Active"
        } else {
            return "Disabled"
        }
    }
    
    private func loadCalendars() {
        if calendarManager.hasCalendarAccess {
            availableCalendars = calendarManager.getCalendars()
        }
    }
    
    private func requestCalendarAccess() async {
        let granted = await calendarManager.requestAccess()
        if granted {
            loadCalendars()
        }
    }
    
    private func toggleCalendar(_ calendar: EKCalendar) {
        if calendarManager.selectedCalendars.contains(calendar.calendarIdentifier) {
            calendarManager.selectedCalendars.remove(calendar.calendarIdentifier)
        } else {
            calendarManager.selectedCalendars.insert(calendar.calendarIdentifier)
        }
        calendarManager.saveSettings()
    }
    
    private func selectAllCalendars() {
        calendarManager.selectedCalendars = Set(availableCalendars.map { $0.calendarIdentifier })
        calendarManager.saveSettings()
    }
    
    private func deselectAllCalendars() {
        calendarManager.selectedCalendars.removeAll()
        calendarManager.saveSettings()
    }
}

// MARK: - Calendar Row View
struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(calendar.cgColor))
                    .frame(width: 16, height: 16)
                
                Text(calendar.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DSFonts.headline(14))
                        .foregroundColor(DSColors.accentPrimary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Calendar Event Preview Row
struct CalendarEventPreviewRow: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Calendar color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(event.calendar.cgColor))
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textPrimary)
                
                HStack(spacing: 8) {
                    Label(timeRange, systemImage: "clock")
                        .font(DSFonts.caption(12))
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text(event.calendar.title)
                        .font(DSFonts.caption(12))
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var timeRange: String {
        if event.isAllDay {
            return "All day"
        }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        
        return "\(start) - \(end)"
    }
}

#Preview {
    NavigationStack {
        CalendarSettingsView()
    }
}
