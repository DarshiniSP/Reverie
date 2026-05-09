//
//  SettingsView.swift
//  iAlly
//
//  Created on 8/12/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var cloudSyncManager = CloudSyncManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("taskDueReminders") private var taskDueReminders = true
    @AppStorage("overdueReminders") private var overdueReminders = true
    @AppStorage("milestoneReminders") private var milestoneReminders = true
    @AppStorage("focusCompleteAlerts") private var focusCompleteAlerts = true
    @AppStorage("dailyReviewReminders") private var dailyReviewReminders = true
    @AppStorage("reminderTime") private var reminderTime: Double = 9 // 9 AM
    @AppStorage("reviewTime") private var reviewTime: Double = 20 // 8 PM
    
    // Growth Mindset Settings
    @AppStorage("enableRecoveryTracking") private var enableRecoveryTracking = true
    @AppStorage("showResilienceMetrics") private var showResilienceMetrics = true
    @AppStorage("generateInsights") private var generateInsights = true
    @AppStorage("celebrationAnimations") private var celebrationAnimations = true
    @AppStorage("enableAutoCleanup") private var enableAutoCleanup = false
    @AppStorage("archiveThresholdDays") private var archiveThresholdDays = 30
    
    @State private var pendingCount = 0
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSyncInfoAlert = false
    @State private var exportURLWrapper: ExportURLWrapper?
    @State private var isExporting = false
    @State private var showExportConfirmation = false
    @State private var showRecommendSheet = false

    // Privacy & Security (Custom Patterns)
    @State private var showAddPatternSheet = false
    @State private var showAuditLog = false
    @State private var newPatternLabel = ""
    @State private var newPatternRegex = ""
    @State private var newPatternReplacement = ""
    @State private var newPatternRegexError: String? = nil
    
    
    private let syncInfoMessage = """
Reverie automatically syncs your data with your personal iCloud account.

✓ Your data stays private
✓ Syncs across all your devices
✓ Restores automatically after reinstall
✓ This is NOT a social feature

Your tasks, routines, plans, and journeys sync across all your devices signed in with the same iCloud account.
"""

    private let exportMessage = """
This will create a JSON backup of your:
• Tasks & Routines
• Journeys & Plans
• Insights

Note: Attachments (photos and files) are NOT included in this backup.
"""
    
    
    var body: some View {
        NavigationStack {
            List {
                // iCloud Sync Status Section
                Section {
                    HStack {
                        Image(systemName: cloudSyncManager.syncStatus.icon)
                            .font(.system(size: 20))
                            .foregroundColor(cloudSyncManager.syncStatus.color)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCloud Sync")
                                .font(DSFonts.body())
                            Text(cloudSyncManager.syncStatus.displayText)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }

                        Spacer()

                        Button {
                            showSyncInfoAlert = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let lastImport = cloudSyncManager.lastImportDate {
                        HStack {
                            Text("Last restored")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Text(lastImport.formatted(date: .abbreviated, time: .shortened))
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }

                    if let lastExport = cloudSyncManager.lastExportDate {
                        HStack {
                            Text("Last backed up")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Text(lastExport.formatted(date: .abbreviated, time: .shortened))
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }

                    if let error = cloudSyncManager.lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DSColors.error)
                            Text(error)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.error)
                            Spacer()
                            Button("Dismiss") {
                                cloudSyncManager.dismissError()
                            }
                            .font(DSFonts.body(13))
                        }
                    }

                    if !cloudSyncManager.isNetworkAvailable {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundColor(DSColors.warning)
                            Text("No internet connection")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.warning)
                        }
                    }
                } header: {
                    Text("Cloud Storage")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Your data syncs automatically across all your devices signed in with the same iCloud account.")
                        .font(DSFonts.body(13))
                }
                
                // Integrations Section
                Section {
                    NavigationLink(destination: CalendarSettingsView()) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.accentPrimary)
                                .frame(width: 32, height: 32)
                                .background(DSColors.accentPrimary.opacity(0.1))
                                .cornerRadius(UIConstants.CornerRadius.standard)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar")
                                    .font(DSFonts.body())

                                Text(CalendarManager.shared.isCalendarEnabled ? "Active" : "Disabled")
                                    .font(DSFonts.caption(12))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }

                    NavigationLink(destination: SiriSettingsView()) {
                        HStack {
                            Image(systemName: "mic.circle.fill")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.accentSecondary)
                                .frame(width: 32, height: 32)
                                .background(DSColors.accentSecondary.opacity(0.1))
                                .cornerRadius(UIConstants.CornerRadius.standard)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Siri & Voice")
                                    .font(DSFonts.body())

                                Text("Set up voice commands & shortcuts")
                                    .font(DSFonts.caption(12))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Integrations")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Connect calendar events and configure voice shortcuts.")
                        .font(DSFonts.body(13))
                }
                
                // Custom Patterns
                Section {
                    ForEach(PIIScrubber.shared.customPatterns) { pattern in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern.label)
                                    .font(DSFonts.body())
                                Text(pattern.regex)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(DSColors.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { pattern.enabled },
                                set: { enabled in
                                    var patterns = PIIScrubber.shared.customPatterns
                                    if let i = patterns.firstIndex(where: { $0.id == pattern.id }) {
                                        patterns[i].enabled = enabled
                                        PIIScrubber.shared.customPatterns = patterns
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }
                    .onDelete { indices in
                        var patterns = PIIScrubber.shared.customPatterns
                        patterns.remove(atOffsets: indices)
                        PIIScrubber.shared.customPatterns = patterns
                    }

                    Button {
                        newPatternLabel = ""
                        newPatternRegex = ""
                        newPatternReplacement = "[CUSTOM]"
                        newPatternRegexError = nil
                        showAddPatternSheet = true
                    } label: {
                        Label("Add Custom Pattern", systemImage: "plus.circle.fill")
                            .foregroundColor(DSColors.accentPrimary)
                            .font(DSFonts.body())
                    }
                } header: {
                    Text("Privacy & Custom Patterns")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("PII (phone, email, credit card, etc.) is automatically scrubbed before Lumina messages leave this device. Add custom patterns for organisation-specific identifiers.")
                        .font(DSFonts.body(13))
                }

                // Redaction Log
                Section {
                    Button {
                        showAuditLog = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Redaction Log")
                                    .font(DSFonts.body())
                                    .foregroundColor(DSColors.textPrimary)
                                let total = PIIScrubber.shared.sessionRedactionTotal
                                Text(total == 0 ? "No items redacted this session" : "\(total) item\(total == 1 ? "" : "s") redacted this session")
                                    .font(DSFonts.caption(12))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Audit")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Log is stored locally and clears when the app is restarted.")
                        .font(DSFonts.body(13))
                }

                // Permission Status Section
                Section {
                    HStack {
                        Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "bell.slash.fill")
                            .foregroundColor(notificationManager.isAuthorized ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notification Status")
                                .font(DSFonts.body())
                            Text(authorizationStatusText)
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if notificationManager.authorizationStatus == .denied {
                            Button("Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(DSFonts.body(15))
                        }
                    }
                } header: {
                    Text("Permissions")
                        .font(DSFonts.label())
                        .textCase(nil)
                }
                
                // Notification Types
                if notificationManager.isAuthorized {
                    Section {
                        Toggle(isOn: $taskDueReminders) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Task Due Reminders")
                                    .font(DSFonts.body())
                                Text("Morning of due date")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        
                        Toggle(isOn: $overdueReminders) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Overdue Task Alerts")
                                    .font(DSFonts.body())
                                Text("Daily reminders")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        
                        Toggle(isOn: $milestoneReminders) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Milestone Reminders")
                                    .font(DSFonts.body())
                                Text("3 days before due date")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        
                        Toggle(isOn: $focusCompleteAlerts) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Focus Complete")
                                    .font(DSFonts.body())
                                Text("When timer finishes")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        
                        Toggle(isOn: $dailyReviewReminders) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Review")
                                    .font(DSFonts.body())
                                Text("Evening reflection prompt")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        .onChange(of: dailyReviewReminders) { _, newValue in
                            _Concurrency.Task {
                                if newValue {
                                    await notificationManager.scheduleDailyReviewReminder()
                                } else {
                                    // Only cancel the daily review notification, not all notifications
                                    UNUserNotificationCenter.current()
                                        .removePendingNotificationRequests(withIdentifiers: ["daily-review"])
                                }
                            }
                        }
                    } header: {
                        Text("Notification Types")
                            .font(DSFonts.label())
                            .textCase(nil)
                    }
                    
                    // Time Preferences
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Task Reminder Time")
                                .font(DSFonts.body())
                            
                            HStack {
                                Text("\(Int(reminderTime)):00")
                                    .font(DSFonts.body(15).monospacedDigit())
                                    .foregroundColor(DSColors.accentPrimary)
                                Spacer()
                                Stepper("", value: $reminderTime, in: 6...22, step: 1)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Review Time")
                                .font(DSFonts.body())
                            
                            HStack {
                                Text("\(Int(reviewTime)):00")
                                    .font(DSFonts.body(15).monospacedDigit())
                                    .foregroundColor(DSColors.accentPrimary)
                                Spacer()
                                Stepper("", value: $reviewTime, in: 17...23, step: 1)
                            }
                        }
                    } header: {
                        Text("Timing")
                            .font(DSFonts.label())
                            .textCase(nil)
                    } footer: {
                        Text("Changes will apply to newly scheduled notifications")
                            .font(DSFonts.body(13))
                    }
                    
                    // Notification Testing — dev builds only
                    #if DEBUG
                    Section {
                        Button(action: {
                            _Concurrency.Task {
                                await sendTestNotification()
                            }
                        }) {
                            HStack {
                                Label("Test Notifications", systemImage: "bell.badge")
                                Spacer()
                                if !notificationManager.isAuthorized {
                                    Text("⚠️ Not Authorized")
                                        .font(DSFonts.body(13))
                                        .foregroundColor(DSColors.warning)
                                }
                            }
                        }
                        .disabled(!notificationManager.isAuthorized)
                    } header: {
                        Text("Notification Test (Dev)")
                            .font(DSFonts.label())
                            .textCase(nil)
                    } footer: {
                        Text("Send a test notification to verify settings. Only visible in debug builds.")
                            .font(DSFonts.body(13))
                    }
                    #endif
                }
                
                // Growth Mindset Features
                Section {
                    Toggle(isOn: $enableRecoveryTracking) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recovery Tracking")
                                .font(DSFonts.body())
                            Text("Track when tasks are completed after being overdue")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    Toggle(isOn: $showResilienceMetrics) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Resilience Metrics")
                                .font(DSFonts.body())
                            Text("Show recovery rates and streak resilience")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    Toggle(isOn: $generateInsights) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pattern Insights")
                                .font(DSFonts.body())
                            Text("Generate AI-like insights from your behavior patterns")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    Toggle(isOn: $celebrationAnimations) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Celebration Animations")
                                .font(DSFonts.body())
                            Text("Show confetti when recovering from setbacks")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    Toggle(isOn: $enableAutoCleanup) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto-Cleanup")
                                .font(DSFonts.body())
                            Text("Archive inactive tasks and routines automatically")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    if enableAutoCleanup {
                        Stepper(value: $archiveThresholdDays, in: 7...90, step: 7) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Archive After")
                                    .font(DSFonts.body())
                                Text("\(archiveThresholdDays) days of inactivity")
                                    .font(DSFonts.body(13))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                } header: {
                    Text("Growth Mindset Features")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Focus on resilience over perfection. Learn from setbacks and celebrate recoveries.")
                        .font(DSFonts.body(13))
                }
                
                // ── AI Provider ─────────────────────────────────────────
                Section {
                    NavigationLink(destination: AIProviderSettingsView()) {
                        HStack {
                            Label("AI Provider", systemImage: "cpu")
                            Spacer()
                            Text(LuminaInferenceRouter.shared.selectedProviderID.displayName
                                 + " · "
                                 + LuminaInferenceRouter.shared.selectedProviderID.modelLabel)
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    NavigationLink(destination: LuminaProfileView()) {
                        Label("Lumina Profile", systemImage: "person.text.rectangle")
                    }
                } header: {
                    Text("Lumina AI")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Configure your AI provider and personalise Lumina's context. Only relevant profile fields are sent per message — sensitive notes are never shared automatically.")
                        .font(DSFonts.body(13))
                }

                // ── Memory ────────────────────────────────────
                Section {
                    LuminaTokenUsageRow()
                    LuminaBiometricRow()
                } header: {
                    Text("Memory & Security")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("All memory is stored locally on your device. Review token usage and set biometric lock for privacy.")
                        .font(DSFonts.body(13))
                }

                // About Section
                Section {
                    NavigationLink(destination: FAQView()) {
                        Label("FAQ", systemImage: "questionmark.circle")
                    }

                    NavigationLink(destination: AboutView()) {
                        Label("About Reverie", systemImage: "info.circle")
                    }

                    Button {
                        showRecommendSheet = true
                    } label: {
                        Label("Recommend to Friend", systemImage: "heart.circle")
                            .foregroundColor(DSColors.textPrimary)
                    }
                } header: {
                    Text("About")
                        .font(DSFonts.label())
                        .textCase(nil)
                }

                // Data Export
                Section {
                    Button {
                        showExportConfirmation = true
                    } label: {
                        if isExporting {
                            HStack {
                                Text("Exporting...")
                                Spacer()
                                ProgressView()
                            }
                        } else {
                            Label("Export All Data", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(isExporting)
                } header: {
                    Text("Data Management")
                        .font(DSFonts.label())
                        .textCase(nil)
                } footer: {
                    Text("Download a copy of your tasks, journeys, and routines.")
                        .font(DSFonts.body(13))
                }
                
            }
            .navigationTitle("Settings")
            .background(DSColors.canvasPrimary)
            .alert("iCloud Sync", isPresented: $showSyncInfoAlert) {
                Button("Got It", role: .cancel) { }
            } message: {
                Text(syncInfoMessage)
            }
            .alert("Notification", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Export Data", isPresented: $showExportConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Export") {
                    Task {
                        await performExport()
                    }
                }
            } message: {
                Text(exportMessage)
            }
            .sheet(item: $exportURLWrapper) { wrapper in
                ShareSheet(items: [wrapper.url])
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showRecommendSheet) {
                RecommendToFriendSheet()
            }
            .sheet(isPresented: $showAddPatternSheet) {
                PIIAddPatternSheet(
                    label: $newPatternLabel,
                    regex: $newPatternRegex,
                    replacement: $newPatternReplacement,
                    regexError: $newPatternRegexError
                )
            }
            .sheet(isPresented: $showAuditLog) {
                PIIAuditLogSheet()
            }
            .task {
                await refreshPendingCount()
            }
        }
    }
    
    private var authorizationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            return "Not requested yet"
        case .denied:
            return "Denied - Enable in System Settings"
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "Reverie notifications are working! 🎉"
        content.sound = .default
        content.badge = NSNumber(value: 1)
        content.categoryIdentifier = "TEST_NOTIFICATION"
        
        // Trigger in 5 seconds so user can see it
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            showFeedback("✅ Test notification will appear in 5 seconds!\n\n💡 You can stay in the app - it will show as a banner at the top.")
        } catch {
            showFeedback("❌ Error: \(error.localizedDescription)")
        }
    }
    
    private func refreshPendingCount() async {
        let pending = await notificationManager.getPendingNotifications()
        pendingCount = pending.count
    }
    
    private func showFeedback(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func performExport() async {
        isExporting = true
        // Delay slightly to show progress (UX)
        try? await _Concurrency.Task.sleep(for: .seconds(0.5))
        
        let service = DataExportService(context: modelContext)
        do {
            let url = try service.export()
            await MainActor.run {
                exportURLWrapper = ExportURLWrapper(url: url)
                isExporting = false
            }
        } catch {
            await MainActor.run {
                isExporting = false
                showFeedback("Failed to export data: \(error.localizedDescription)")
            }
        }
    }
    
}

// MARK: - Lumina AI Setting Rows

/// Shows monthly token usage with optional budget cap.
private struct LuminaTokenUsageRow: View {
    @State private var usage = LuminaTokenUsage.current
    @State private var showBudgetSheet = false
    @State private var budgetDraft = ""

    var body: some View {
        Button { showBudgetSheet = true } label: {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.warning)
                    .frame(width: 32, height: 32)
                    .background(DSColors.warning.opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.standard)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Token Usage")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)

                    HStack(spacing: 8) {
                        Text("\(usage.totalTokensThisMonth.formatted()) tokens")
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                        Text("\u{2248} $\(String(format: "%.4f", usage.estimatedCostUSD))")
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Token usage: \(usage.totalTokensThisMonth) tokens this month")
        .sheet(isPresented: $showBudgetSheet) { budgetSheet }
    }

    private var budgetSheet: some View {
        NavigationStack {
            Form {
                Section("This Month") {
                    LabeledContent("Total Tokens", value: usage.totalTokensThisMonth.formatted())
                    LabeledContent("API Calls", value: usage.totalCallsThisMonth.formatted())
                    LabeledContent("Est. Cost", value: "$\(String(format: "%.4f", usage.estimatedCostUSD))")
                }
            }
            .navigationTitle("Token Usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showBudgetSheet = false }
                }
            }
        }
    }
}

/// Toggle for Face ID / Touch ID app lock.
private struct LuminaBiometricRow: View {
    @State private var auth = BiometricAuthManager.shared

    var body: some View {
        HStack {
            Image(systemName: auth.biometryIcon)
                .font(DSFonts.headline())
                .foregroundColor(DSColors.accentSecondary)
                .frame(width: 32, height: 32)
                .background(DSColors.accentSecondary.opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(auth.biometryLabel) Lock")
                    .font(DSFonts.body())
                Text("Re-lock after \(Int(auth.idleLockThreshold / 60)) minutes background")
                    .font(DSFonts.caption(12))
                    .foregroundColor(DSColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { auth.isLockEnabled },
                set: { auth.isLockEnabled = $0 }
            ))
            .labelsHidden()
            .accessibilityLabel("\(auth.biometryLabel) lock")
        }
    }
}

// RemoteIntelligenceRow removed — PAIService no longer used for beta

// MARK: - PII Sheet Views

private struct PIIAddPatternSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var label: String
    @Binding var regex: String
    @Binding var replacement: String
    @Binding var regexError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Employee ID", text: $label)
                } header: {
                    Text("Pattern Name")
                }

                Section {
                    TextField("e.g. EMP-\\d{6}", text: $regex)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: regex) { _, new in
                            regexError = PIIScrubber.shared.validateRegex(new)
                        }
                    if let err = regexError {
                        Text(err)
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.error)
                    }
                } header: {
                    Text("Regex Pattern")
                } footer: {
                    Text("Use standard regular expression syntax. Test your pattern before saving.")
                }

                Section {
                    TextField("e.g. [EMPLOYEE_ID]", text: $replacement)
                        .autocorrectionDisabled()
                } header: {
                    Text("Replacement Token")
                }
            }
            .navigationTitle("Add Custom Pattern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !label.isEmpty, !regex.isEmpty, !replacement.isEmpty,
                              PIIScrubber.shared.validateRegex(regex) == nil else { return }
                        let newPattern = CustomPIIPattern(
                            id: UUID(),
                            label: label,
                            regex: regex,
                            replacement: replacement.isEmpty ? "[CUSTOM]" : replacement,
                            enabled: true
                        )
                        PIIScrubber.shared.customPatterns.append(newPattern)
                        dismiss()
                    }
                    .disabled(label.isEmpty || regex.isEmpty || regexError != nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct PIIAuditLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if PIIScrubber.shared.auditLog.isEmpty {
                    ContentUnavailableView(
                        "No Redactions Yet",
                        systemImage: "checkmark.shield",
                        description: Text("Items redacted from Lumina messages will appear here.")
                    )
                } else {
                    List {
                        ForEach(PIIScrubber.shared.auditLog.reversed()) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(DSFonts.caption(12))
                                    .foregroundColor(DSColors.textSecondary)
                                ForEach(entry.redactions, id: \.category) { r in
                                    Text("• \(r.category): \(r.count) item\(r.count == 1 ? "" : "s")")
                                        .font(DSFonts.body(14))
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Redaction Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    SettingsView()
        .environmentObject(NotificationManager.shared)
}
