import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Main Countdown List

struct CountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CountdownEvent.targetDate) private var events: [CountdownEvent]
    @State private var showAddEvent = false

    private var activeEvents: [CountdownEvent] {
        events.filter { !$0.isArchived && $0.daysRemaining >= 0 }
    }

    private var pastEvents: [CountdownEvent] {
        events.filter { !$0.isArchived && $0.daysRemaining < 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary.ignoresSafeArea()

                if activeEvents.isEmpty && pastEvents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Active countdowns
                            if !activeEvents.isEmpty {
                                LazyVStack(spacing: 12) {
                                    ForEach(activeEvents) { event in
                                        CountdownCard(event: event) {
                                            delete(event)
                                        }
                                    }
                                }
                            }

                            // Past events
                            if !pastEvents.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Past")
                                        .font(DSFonts.label(13))
                                        .foregroundColor(DSColors.textTertiary)
                                        .padding(.horizontal, 4)
                                    ForEach(pastEvents) { event in
                                        CountdownCard(event: event, isPast: true) {
                                            delete(event)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Countdowns")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DSColors.textSecondary)
                            .font(.system(size: 20))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddEvent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showAddEvent) {
                AddCountdownView()
            }
        }
    }

    private func delete(_ event: CountdownEvent) {
        modelContext.delete(event)
        try? modelContext.save()
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DSColors.accentPrimary.opacity(0.10))
                    .frame(width: 110, height: 110)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColors.accentPrimary, DSColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(spacing: 8) {
                Text("No Countdowns Yet")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)
                Text("Add your exams, NS ORD date,\nor any important deadline.")
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add a Countdown") { showAddEvent = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Countdown Card

struct CountdownCard: View {
    let event: CountdownEvent
    var isPast: Bool = false
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Coloured left strip
            Color(hex: event.type.color)
                .frame(width: 4)
                .clipShape(RoundedCorner(radius: 14, corners: [.topLeft, .bottomLeft]))

            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: event.type.color).opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: event.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: event.type.color))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(DSFonts.label(15))
                        .foregroundColor(isPast ? DSColors.textSecondary : DSColors.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(event.type.rawValue)
                            .font(DSFonts.caption(11))
                            .foregroundColor(Color(hex: event.type.color))
                        Text("·")
                            .foregroundColor(DSColors.textTertiary)
                        Text(event.targetDate.formatted(date: .abbreviated, time: .omitted))
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                Spacer()

                // Days remaining badge
                VStack(spacing: 2) {
                    if isPast {
                        Text("Done")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(DSColors.textTertiary)
                    } else {
                        Text(event.daysRemaining == 0 ? "Today" : "\(event.daysRemaining)")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(event.urgencyColor)
                        if event.daysRemaining > 0 {
                            Text("days")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(DSColors.textTertiary)
                        }
                    }
                }
                .frame(minWidth: 44)
            }
            .padding(14)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedCorner(radius: 14, corners: [.topRight, .bottomRight]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: DSColors.shadow, radius: 8, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(DSColors.divider, lineWidth: 0.5))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Home Button (always visible on Today tab — tap to open Countdowns)

struct CountdownHomeButton: View {
    @Query(sort: \CountdownEvent.targetDate) private var events: [CountdownEvent]

    private var upcoming: [CountdownEvent] {
        events
            .filter { !$0.isArchived && $0.daysRemaining >= 0 && $0.daysRemaining <= 60 }
            .prefix(2)
            .map { $0 }
    }

    private var nextEvent: CountdownEvent? { upcoming.first }

    var body: some View {
        NavigationLink(destination: CountdownView()) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DSColors.accentSecondary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DSColors.accentSecondary)
                }

                if let event = nextEvent {
                    // Show the closest deadline
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next deadline")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textTertiary)
                        Text(event.title)
                            .font(DSFonts.label(14))
                            .foregroundColor(DSColors.textPrimary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(event.urgencyLabel)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(event.urgencyColor)
                        if upcoming.count > 1 {
                            Text("+\(upcoming.count - 1) more")
                                .font(DSFonts.caption(10))
                                .foregroundColor(DSColors.textTertiary)
                        }
                    }
                } else {
                    // No upcoming deadlines — prompt to add
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Countdowns & Deadlines")
                            .font(DSFonts.label(14))
                            .foregroundColor(DSColors.textPrimary)
                        Text("Exams, NS ORD, PSLE & more")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DSColors.textTertiary)
                }
            }
            .padding(14)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: DSColors.shadow, radius: 8, x: 0, y: 2)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(DSColors.divider, lineWidth: 0.5))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Home Preview Card (shown on Today tab when within 60 days — kept for backward compat)

struct CountdownPreviewCard: View {
    var body: some View {
        CountdownHomeButton()
    }
}

// MARK: - Add Countdown Sheet

struct AddCountdownView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: CountdownType = .exam
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Event name (e.g. A-Level Chemistry)", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(CountdownType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                }

                Section("Target Date") {
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(DSColors.accentPrimary)
                }

                Section("Notes (Optional)") {
                    TextField("Any notes…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }

    private func save() {
        let event = CountdownEvent(
            title: title.trimmingCharacters(in: .whitespaces),
            targetDate: targetDate,
            type: type,
            notes: notes.isEmpty ? nil : notes
        )
        modelContext.insert(event)
        try? modelContext.save()
        scheduleNotifications(for: event)
        dismiss()
    }

    private func scheduleNotifications(for event: CountdownEvent) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            // Schedule reminders at 30, 7, 3, 1 days before and on the day
            let intervals: [(days: Int, message: String)] = [
                (30, "30 days to go — \(event.title) is coming up."),
                (7,  "One week until \(event.title). Stay focused."),
                (3,  "\(event.title) is in 3 days. Are you ready?"),
                (1,  "\(event.title) is tomorrow. You've got this."),
                (0,  "Today is the day — \(event.title). Give it everything.")
            ]
            for (days, message) in intervals {
                guard let fireDate = Calendar.current.date(
                    byAdding: .day, value: -days, to: event.targetDate
                ), fireDate > Date() else { continue }

                let content = UNMutableNotificationContent()
                content.title = event.title
                content.body  = message
                content.sound = .default

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate
                )
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let id = "\(event.id.uuidString)-\(days)d"
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}


#Preview {
    CountdownView()
        .modelContainer(for: CountdownEvent.self, inMemory: true)
}
