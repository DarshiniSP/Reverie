//
//  FocusModeView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var notificationManager = NotificationManager.shared
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var allSessions: [FocusSession]
    @Query private var allTasks: [TaskWork]
    @State private var timerManager = FocusTimerManager()
    @State private var selectedTask: TaskWork?
    @State private var showTaskPicker = false
    @State private var selectedDuration: Int = 25 // minutes
    @State private var isCustomDuration: Bool = false
    @State private var showCustomDurationPicker = false
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 30
    @State private var showHistory = false
    @State private var interruptions: [Interruption] = []
    @State private var showInterruptionLog = false
    @State private var enableDND = true
    @State private var playAmbientSound = false
    @State private var selectedAmbientSound: AmbientSound = .none
    // P4-B: tracks whether the Focus Live Activity is active for Dynamic Island
    @State private var liveActivityActive: Bool = false
    // Body Doubling: Lumina "sits with you" during the session
    @State private var bodyDoublingEnabled: Bool = false
    
    enum AmbientSound: String, CaseIterable {
        case none = "None"
        case rain = "Rain"
        case waves = "Ocean Waves"
        case forest = "Forest"
        case cafe = "Café"
        
        var icon: String {
            switch self {
            case .none: return "speaker.slash"
            case .rain: return "cloud.rain"
            case .waves: return "water.waves"
            case .forest: return "leaf"
            case .cafe: return "cup.and.saucer"
            }
        }
    }
    
    struct Interruption: Identifiable {
        let id = UUID()
        let timestamp: Date
        let note: String
    }
    
    private var todaySessions: [FocusSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allSessions.filter { session in
            return calendar.isDate(session.startedAt, inSameDayAs: today)
        }
    }
    
    private var todayTasks: [TaskWork] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // 1. Overdue tasks (due before today)
        let overdueTasks = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return taskDate < today && !task.isCompleted
        }
        
        // 2. Due today tasks (excluding routine tasks)
        let dueTodayTasks = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return taskDate >= today && taskDate < tomorrow && task.routine == nil && !task.isCompleted
        }
        
        // 3. Today's routine tasks
        let todayRoutineTasks = allTasks.filter { task in
            guard let routine = task.routine,
                  let dueDate = task.dueDate else { return false }
            let taskDate = calendar.startOfDay(for: dueDate)
            return routine.isActive && taskDate >= today && taskDate < tomorrow && !task.isCompleted
        }
        
        // Combine all three categories (no duplicates since routine check prevents overlap)
        let allTodayTasks = overdueTasks + dueTodayTasks + todayRoutineTasks
        
        // Sort: overdue first, then routines, then regular tasks, all by due date
        return allTodayTasks.sorted { task1, task2 in
            let task1Overdue = task1.dueDate.map { calendar.startOfDay(for: $0) < today } ?? false
            let task2Overdue = task2.dueDate.map { calendar.startOfDay(for: $0) < today } ?? false
            
            // Overdue tasks first
            if task1Overdue != task2Overdue {
                return task1Overdue
            }
            
            // Then routine tasks
            let task1IsRoutine = task1.routine != nil
            let task2IsRoutine = task2.routine != nil
            if task1IsRoutine != task2IsRoutine {
                return task1IsRoutine
            }
            
            // Then by due date
            return (task1.dueDate ?? .distantFuture) < (task2.dueDate ?? .distantFuture)
        }
    }
    
    private var sessionStats: (total: Int, totalMinutes: Int, completed: Int) {
        let completed = todaySessions.filter { $0.completedAt != nil }.count
        let totalMinutes = todaySessions.reduce(0) { total, session in
            let duration = session.actualDuration ?? session.duration
            return total + Int(duration / 60)
        }
        return (todaySessions.count, totalMinutes, completed)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Today's stats
                    if !todaySessions.isEmpty {
                        todayStatsView
                    }
                    
                    // Settings (when not running)
                    if !timerManager.isRunning {
                        focusSettingsView
                    }
                    
                    // Interruption log (when running)
                    if timerManager.isRunning && !interruptions.isEmpty {
                        interruptionSummary
                    }
                    
                    Spacer()
                    
                    // Timer display
                    timerDisplay
                    
                    // Task info
                    if let task = selectedTask {
                        taskInfo(task)
                    } else {
                        noTaskSelected
                    }
                    
                    // Duration picker
                    if !timerManager.isRunning {
                        durationPicker
                    }
                    
                    Spacer()
                    
                    // Controls
                    controlButtons
                    
                    // Log interruption button (when running)
                    if timerManager.isRunning {
                        Button {
                            showInterruptionLog = true
                        } label: {
                            Label("Log Interruption", systemImage: "exclamationmark.circle")
                                .font(DSFonts.caption())
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .sheet(isPresented: $showTaskPicker) {
                TaskPickerView(selectedTask: $selectedTask, filterToday: true, todayTasks: todayTasks)
            }
            .sheet(isPresented: $showHistory) {
                SessionHistoryView(sessions: allSessions)
            }
            .alert("Log Interruption", isPresented: $showInterruptionLog) {
                TextField("What interrupted you?", text: $interruptionNote)
                Button("Cancel", role: .cancel) { interruptionNote = "" }
                Button("Log") {
                    if !interruptionNote.isEmpty {
                        interruptions.append(Interruption(timestamp: Date(), note: interruptionNote))
                        interruptionNote = ""
                    }
                }
            } message: {
                Text("Track what broke your focus to identify patterns")
            }
        }
    }
    
    @State private var interruptionNote = ""

    // MARK: - Body Doubling messages
    // Research basis: body doubling is a validated ADHD support technique (Patros et al., 2016)
    // in which the presence of another person (even virtual) improves task initiation and focus.
    private var luminaBodyDoubleMessage: String {
        let progress = timerManager.progress
        switch progress {
        case 0..<0.15: return "I'm here with you. Take a breath and begin."
        case 0.15..<0.45: return "You're building momentum. I'm right here."
        case 0.45..<0.55: return "Halfway. You're doing the thing."
        case 0.55..<0.85: return "Almost there. One task at a time."
        default:           return "You showed up. That's the whole thing."
        }
    }
    
    private var focusSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Settings")
                .font(DSFonts.caption())
                .fontWeight(.semibold)
                .foregroundColor(DSColors.textSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                Toggle(isOn: $enableDND) {
                    Label("Enable Do Not Disturb", systemImage: "moon")
                        .font(DSFonts.body(14))
                }
                .tint(DSColors.accentPrimary)
                
                Toggle(isOn: $playAmbientSound) {
                    Label("Play Ambient Sound", systemImage: "speaker.wave.2")
                        .font(DSFonts.body(14))
                }
                .tint(DSColors.accentPrimary)

                Toggle(isOn: $bodyDoublingEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Body Double with Lumina", systemImage: "person.2.fill")
                            .font(DSFonts.body(14))
                        Text("Lumina sits with you quietly and checks in at milestones")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                .tint(DSColors.accentPrimary)
                
                if playAmbientSound {
                    Picker("Ambient Sound", selection: $selectedAmbientSound) {
                        ForEach(AmbientSound.allCases, id: \.self) { sound in
                            Label(sound.rawValue, systemImage: sound.icon).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(DSFonts.body(14))
                }
            }
            .padding(12)
            .background(DSColors.canvasSecondary)
            .cornerRadius(UIConstants.CornerRadius.large)
        }
    }
    
    private var interruptionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(DSColors.warning)
                    .font(DSFonts.caption())
                Text("Interruptions: \(interruptions.count)")
                    .font(DSFonts.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(DSColors.textPrimary)
            }
            
            if let lastInterruption = interruptions.last {
                Text("Latest: \(lastInterruption.note)")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColors.warning.opacity(0.1))
        .cornerRadius(UIConstants.CornerRadius.medium)
    }
    
    private var todayStatsView: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundColor(DSColors.warning)
                Text("\(sessionStats.total)")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundColor(DSColors.accentPrimary)
                Text("\(sessionStats.totalMinutes)m")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DSColors.success)
                Text("\(sessionStats.completed)")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.extraLarge)
    }
    
    // MARK: - Duration picker

    /// Label shown on the Custom pill once the user has set a value.
    private var customDurationLabel: String {
        let h = customHours, m = customMinutes
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0            { return "\(h)h" }
        return "\(m)m"
    }

    private var durationPicker: some View {
        VStack(spacing: 12) {
            // Row 1 — Custom button, centred and fully visible
            Button {
                showCustomDurationPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(DSFonts.caption())
                    Text(isCustomDuration ? customDurationLabel : "Custom Duration")
                        .font(DSFonts.label())
                }
                .foregroundColor(isCustomDuration ? DSColors.onAccent : DSColors.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .background(isCustomDuration ? DSColors.accentPrimary : DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.standard)
            }

            // Row 2 — Fixed presets
            HStack(spacing: 12) {
                ForEach([15, 25, 45, 60], id: \.self) { duration in
                    Button {
                        selectedDuration = duration
                        isCustomDuration = false
                    } label: {
                        Text("\(duration)m")
                            .font(DSFonts.label())
                            .foregroundColor(!isCustomDuration && selectedDuration == duration ? DSColors.onAccent : DSColors.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(!isCustomDuration && selectedDuration == duration ? DSColors.accentPrimary : DSColors.canvasSecondary)
                            .cornerRadius(UIConstants.CornerRadius.standard)
                    }
                }
            }
        }
        .sheet(isPresented: $showCustomDurationPicker) {
            customDurationSheet
        }
    }

    private var customDurationSheet: some View {
        NavigationStack {
            VStack(spacing: 28) {
                // Wheel pickers side-by-side
                HStack(spacing: 0) {
                    // Hours
                    VStack(spacing: 6) {
                        Picker("Hours", selection: $customHours) {
                            ForEach(0..<6, id: \.self) { h in
                                Text("\(h)").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 110)
                        .clipped()

                        Text("hours")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }

                    // Minutes
                    VStack(spacing: 6) {
                        Picker("Minutes", selection: $customMinutes) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 110)
                        .clipped()

                        Text("minutes")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                // Live preview of the selected total
                let totalMins = customHours * 60 + customMinutes
                if totalMins > 0 {
                    Text("Duration: \(customDurationLabel)")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                }

                // Confirm button
                Button {
                    let total = customHours * 60 + customMinutes
                    guard total > 0 else { return }
                    selectedDuration = total
                    isCustomDuration = true
                    showCustomDurationPicker = false
                } label: {
                    Text("Set Duration")
                        .font(DSFonts.label())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(customHours * 60 + customMinutes == 0)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Custom Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCustomDurationPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private var timerDisplay: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(DSColors.textSecondary.opacity(0.2), lineWidth: 12)
                    .frame(width: 240, height: 240)

                Circle()
                    .trim(from: 0, to: timerManager.progress)
                    .stroke(
                        Color(hex: selectedTask?.plan?.colorHex ?? "#4C8BF5"),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.progress)

                VStack(spacing: 8) {
                    Text(timerManager.timeString)
                        .font(DSFonts.headline(56))
                        .foregroundColor(DSColors.textPrimary)
                        .accessibilityIdentifier("focusTimerDisplay")

                    if timerManager.isRunning {
                        if bodyDoublingEnabled {
                            Text(luminaBodyDoubleMessage)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.accentPrimary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .animation(.easeInOut, value: luminaBodyDoubleMessage)
                        } else {
                            Text("Stay focused")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }
            }

            // P4-B: Live Activity / Dynamic Island status chip
            if liveActivityActive {
                HStack(spacing: 6) {
                    Circle()
                        .fill(DSColors.accentPrimary)
                        .frame(width: 8, height: 8)
                    Text("Live Activity Active · Dynamic Island")
                        .font(DSFonts.body(12))
                        .foregroundColor(DSColors.accentPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(DSColors.accentPrimary.opacity(0.1))
                .clipShape(Capsule())
                .accessibilityIdentifier("focusLiveActivityIndicator")
            } else if !timerManager.isRunning {
                // Static info chip shown before any session starts
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    Text("Updates Dynamic Island & Lock Screen")
                        .font(DSFonts.body(12))
                        .foregroundColor(DSColors.textSecondary)
                }
                .accessibilityIdentifier("focusLiveActivityInfo")
            }
        }
    }
    
    private func taskInfo(_ task: TaskWork) -> some View {
        VStack(spacing: 8) {
            Text(task.title)
                .font(DSFonts.title(22))
                .foregroundColor(DSColors.textPrimary)
                .multilineTextAlignment(.center)
            
            if let whyItMatters = task.whyItMatters, !whyItMatters.isEmpty {
                Text(whyItMatters)
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    private var noTaskSelected: some View {
        Button("Select a task") {
            showTaskPicker = true
        }
        .buttonStyle(SecondaryButtonStyle())
    }
    
    private var controlButtons: some View {
        HStack(spacing: 20) {
            if timerManager.isRunning {
                Button {
                    timerManager.pause()
                    // P4-B: update the Live Activity to show paused state
                    FocusLiveActivityManager.shared.updateLiveActivity(
                        timeRemainingSeconds: Int(timerManager.timeRemaining)
                    )
                } label: {
                    Image(systemName: "pause.fill")
                        .font(DSFonts.title())
                }
                .buttonStyle(SecondaryButtonStyle())

                Button {
                    // P4-B: end the Live Activity before stopping the timer
                    FocusLiveActivityManager.shared.endLiveActivity()
                    liveActivityActive = false
                    timerManager.stop()
                    if let task = selectedTask {
                        saveSession(task: task)
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(DSFonts.title())
                }
                .buttonStyle(DestructiveButtonStyle())
            } else {
                Button {
                    if selectedTask == nil {
                        showTaskPicker = true
                    } else {
                        let durationSecs = selectedDuration * 60
                        timerManager.start(duration: TimeInterval(durationSecs))
                        // P4-B: start a Live Activity in the Dynamic Island
                        FocusLiveActivityManager.shared.startLiveActivity(
                            taskTitle: selectedTask?.title ?? "Focus Session",
                            durationSeconds: durationSecs
                        )
                        liveActivityActive = FocusLiveActivityManager.shared.isLiveActivityActive
                    }
                } label: {
                    Label("Start Focus", systemImage: "play.fill")
                        .font(DSFonts.label())
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedTask == nil)
                .accessibilityIdentifier("startFocusButton")
            }
        }
    }
    
    private func saveSession(task: TaskWork) {
        let session = FocusSession(
            duration: timerManager.totalDuration,
            taskTitle: task.title
        )
        let actualTime = timerManager.totalDuration - timerManager.timeRemaining
        session.complete(actualDuration: actualTime)
        modelContext.insert(session)
        try? modelContext.save()
        
        // Send completion notification
        let durationMinutes = Int(actualTime / 60)
        _Concurrency.Task {
            await notificationManager.scheduleFocusCompleteNotification(
                sessionId: session.id.uuidString,
                taskTitle: task.title,
                duration: durationMinutes
            )
        }
    }
}

// MARK: - Session History View
struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [FocusSession]
    
    private var groupedSessions: [(String, [FocusSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session -> String in
            let date = session.startedAt
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        
        let sortOrder = ["Today", "Yesterday"]
        return grouped.sorted { first, second in
            if let firstIndex = sortOrder.firstIndex(of: first.key),
               let secondIndex = sortOrder.firstIndex(of: second.key) {
                return firstIndex < secondIndex
            }
            if sortOrder.contains(first.key) { return true }
            if sortOrder.contains(second.key) { return false }
            return first.key > second.key
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedSessions, id: \.0) { date, sessions in
                        Section {
                            ForEach(sessions) { session in
                                SessionRowView(session: session)
                            }
                        } header: {
                            HStack {
                                Text(date)
                                    .font(DSFonts.label())
                                    .foregroundColor(DSColors.textSecondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(DSColors.canvasPrimary)
                        }
                    }
                }
                .padding()
            }
            .background(DSColors.canvasPrimary)
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SessionRowView: View {
    let session: FocusSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.taskTitle ?? "Focus Session")
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Text(timeString(from: session.startedAt))
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                let minutes = Int((session.actualDuration ?? session.duration) / 60)
                Text("\(minutes)m")
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textPrimary)
                
                if session.completedAt != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DSColors.success)
                        .font(DSFonts.caption())
                }
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

@Observable
class FocusTimerManager {
    var isRunning = false
    var timeRemaining: TimeInterval = 25 * 60
    var totalDuration: TimeInterval = 25 * 60
    private var timer: Timer?
    private var startTime: Date?
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (timeRemaining / totalDuration)
    }
    
    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func start(duration: TimeInterval) {
        totalDuration = duration
        timeRemaining = duration
        isRunning = true
        startTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeRemaining -= 1
            
            if self.timeRemaining <= 0 {
                self.stop()
            }
        }
    }
    
    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        timeRemaining = totalDuration
    }
}

#Preview {
    NavigationStack {
        FocusModeView()
    }
    .modelContainer(for: [TaskWork.self, FocusSession.self], inMemory: true)
}
