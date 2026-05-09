//
//  MoreView.swift
//  Reverie
//
//  Created on 9/12/2025.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                // Lumina Section
                Section("Lumina") {
                    NavigationLink {
                        QuickNotesView()
                    } label: {
                        Label("Quick Notes", systemImage: "note.text")
                    }

                    NavigationLink {
                        MemoryInspectorView()
                    } label: {
                        Label("Lumina's Memory", systemImage: "brain.head.profile")
                    }
                }

                // Countdowns Section
                Section("Countdowns & Deadlines") {
                    NavigationLink {
                        CountdownView()
                    } label: {
                        Label("Exams, NS & Deadlines", systemImage: "calendar.badge.clock")
                    }
                }

                // Resilience Section
                Section("Resilience & Wellbeing") {
                    NavigationLink {
                        AnalyticsDashboardView()
                    } label: {
                        Label("Resilience Index", systemImage: "waveform.path.ecg.rectangle")
                    }

                    NavigationLink {
                        AIInsightsView()
                    } label: {
                        Label("Lumina Insights", systemImage: "sparkles")
                    }

                    NavigationLink {
                        WeeklyReviewView()
                    } label: {
                        Label("Weekly Review", systemImage: "calendar.badge.checkmark")
                    }

                    NavigationLink {
                        CompletedTasksView()
                    } label: {
                        Label("Task History", systemImage: "checkmark.circle.fill")
                    }
                }

                // Tools Section
                Section("Tools") {
                    NavigationLink {
                        RoutinesView()
                    } label: {
                        Label("Daily Anchors", systemImage: "repeat.circle.fill")
                            .accessibilityIdentifier("routinesButton")
                    }

                    NavigationLink {
                        ChecklistsView()
                    } label: {
                        Label("Checklists", systemImage: "checklist")
                            .accessibilityIdentifier("checklistsButton")
                    }

                    NavigationLink {
                        FocusModeView()
                    } label: {
                        Label("Focus Mode", systemImage: "timer")
                    }

                    NavigationLink {
                        CustomViewsListView()
                    } label: {
                        Label("Custom Views", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        InferenceLogView()
                    } label: {
                        Label("Inference Logs", systemImage: "doc.text.magnifyingglass")
                    }
                }
                #endif

                // App Section
                Section("App") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .accessibilityIdentifier("settingsButton")

                    NavigationLink {
                        PrivacyView()
                    } label: {
                        Label("Privacy", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

// MARK: - Placeholder Views
struct AboutView: View {
    @Environment(\.openURL) var openURL
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon
                if let icon = UIImage(named: "AppIcon60x60") ?? getAppIcon() {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .cornerRadius(22.37)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(DSColors.accentPrimary)
                }
                
                VStack(spacing: 8) {
                    Text("Reverie")
                        .font(DSFonts.title(34))
                        .fontWeight(.bold)
                    
                    Text("Your personal resilience companion")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    // Version info
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Version \(version) (Build \(build))")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                            .padding(.top, 4)
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                // Core Values
                VStack(alignment: .leading, spacing: 16) {
                    InfoRow(
                        icon: "lock.shield.fill",
                        title: "Privacy First",
                        description: "Your data never leaves your device. No accounts, no tracking, no servers. Optional iCloud sync uses YOUR private storage."
                    )
                    
                    InfoRow(
                        icon: "wifi.slash",
                        title: "Offline First",
                        description: "Full functionality without internet. All features work perfectly offline with local data storage."
                    )
                    
                    InfoRow(
                        icon: "waveform.path.ecg.rectangle",
                        title: "Resilience Index",
                        description: "A composite wellbeing score computed from your mood, daily anchors, academic load, and consistency — based on Maslach Burnout Inventory dimensions."
                    )

                    InfoRow(
                        icon: "brain",
                        title: "Cognitive Load Awareness",
                        description: "Your home screen shows today's cognitive load in real time — task complexity, context-switching cost, and overdue pressure — so you can protect your mental bandwidth."
                    )

                    InfoRow(
                        icon: "brain.head.profile",
                        title: "Lumina AI",
                        description: "A supportive AI companion that monitors wellbeing signals and proactively surfaces support — not just a productivity assistant, but a presence that notices when you're struggling."
                    )

                    InfoRow(
                        icon: "person.2.fill",
                        title: "Body Doubling",
                        description: "A validated ADHD support technique (Patros et al., 2016): Lumina sits with you during focus sessions, providing virtual presence and milestone check-ins."
                    )
                }
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
                
                // Footer
                VStack(spacing: 12) {
                    Text("Need help or have questions?")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Button(action: {
                        if let url = URL(string: "https://www.reverie.app") {
                            openURL(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "link")
                            Text("www.reverie.app")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.accentPrimary)
                    }
                }
                .padding()
                
                // Copyright
                Text("© 2025 Irigam Innovations. All rights reserved.")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Helper function to get the app icon
    private func getAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

struct PrivacyView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Privacy Policy")
                        .font(DSFonts.title())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("Last Updated: December 14, 2025")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                
                // Introduction
                PrivacySection(title: "Our Commitment", icon: "hand.raised.fill", color: DSColors.accentPrimary) {
                    Text("Reverie is designed with your privacy as the top priority. We believe your productivity data belongs to you and only you.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                }
                
                // Data Storage
                PrivacySection(title: "Data Storage", icon: "internaldrive.fill", color: DSColors.accentPrimary) {
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyDetail(
                            title: "Local-First Architecture",
                            description: "All your data is stored directly on your device using Apple's SwiftData framework. Your tasks, plans, journeys, and routines never leave your device unless you choose to enable iCloud Sync."
                        )
                        
                        PrivacyDetail(
                            title: "AI Inference — Your API Key",
                            description: "Lumina AI connects directly to the provider you choose (Claude, ChatGPT, Gemini, or Mercury) using your own API key. Requests go directly from your device to that provider — never through Irigam Innovations servers."
                        )
                        
                        PrivacyDetail(
                            title: "Complete Control",
                            description: "You can delete all your data at any time by uninstalling the app. Your data is immediately and permanently removed from your device."
                        )
                    }
                }
                
                // iCloud Sync
                PrivacySection(title: "iCloud Sync", icon: "icloud.fill", color: .cyan) {
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyDetail(
                            title: "Your Personal iCloud",
                            description: "Your data is synced to your personal iCloud account — not our servers. This keeps your tasks, plans, and journeys in sync across all your Apple devices and restores them automatically after reinstall."
                        )

                        PrivacyDetail(
                            title: "Apple's Encryption",
                            description: "iCloud data is encrypted and managed by Apple according to their privacy policy. We do not have access to your iCloud storage or any data stored there."
                        )

                        PrivacyDetail(
                            title: "Automatic",
                            description: "iCloud Sync works automatically when you are signed in to iCloud. No additional setup is required."
                        )
                    }
                }
                
                // What We Don't Collect
                PrivacySection(title: "What We Don't Collect", icon: "xmark.shield.fill", color: DSColors.error) {
                    VStack(alignment: .leading, spacing: 8) {
                        NonCollectionItem(text: "No personal information (name, email, phone)")
                        NonCollectionItem(text: "No user accounts or authentication")
                        NonCollectionItem(text: "No analytics or usage tracking")
                        NonCollectionItem(text: "No advertising identifiers")
                        NonCollectionItem(text: "No location data")
                        NonCollectionItem(text: "No device identifiers")
                        NonCollectionItem(text: "No crash reports or diagnostics")
                    }
                }
                
                // iOS Permissions
                PrivacySection(title: "iOS Permissions", icon: "lock.shield.fill", color: DSColors.warning) {
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyDetail(
                            title: "Calendar Access (Optional)",
                            description: "If you grant calendar permission, Reverie can display your calendar events alongside your tasks for better planning. This access is read-only and your calendar data stays on your device."
                        )
                        
                        PrivacyDetail(
                            title: "Notifications (Optional)",
                            description: "If you enable notifications, Reverie can remind you about tasks and routines. All notifications are generated locally on your device."
                        )
                        
                        PrivacyDetail(
                            title: "Siri & Shortcuts (Optional)",
                            description: "If you enable Siri integration, you can use voice commands to add tasks. Your voice commands are processed by Apple's Siri, not by Reverie or Irigam Innovations."
                        )
                    }
                }
                
                // AI Features
                PrivacySection(title: "Lumina AI", icon: "brain.head.profile", color: DSColors.accentSecondary) {
                    VStack(alignment: .leading, spacing: 16) {
                        PrivacyDetail(
                            title: "Direct API Connection",
                            description: "Lumina connects directly from your device to the AI provider you choose (Claude, ChatGPT, Gemini, or Mercury). No data passes through Irigam Innovations servers."
                        )

                        PrivacyDetail(
                            title: "Your API Key",
                            description: "You provide your own API key in Settings. Requests go directly from your device to the provider. Memory and conversation history are stored locally on your device."
                        )
                    }
                }

                // Third-Party Services
                PrivacySection(title: "Third-Party Services", icon: "link", color: .gray) {
                    Text("Reverie does not integrate with analytics platforms or advertising networks. The only external connection is to the AI provider you configure (e.g. Anthropic Claude API) under your own API key.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                }
                
                // Children's Privacy
                PrivacySection(title: "Children's Privacy", icon: "figure.and.child.holdinghands", color: DSColors.success) {
                    Text("Reverie does not knowingly collect any information from children. Because we don't collect any data from anyone, users of all ages can use the app safely.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                }
                
                // Changes to Policy
                PrivacySection(title: "Changes to This Policy", icon: "doc.text.fill", color: .indigo) {
                    Text("We may update this privacy policy from time to time. Any changes will be reflected in the app with an updated \"Last Updated\" date. Continued use of the app after changes constitutes acceptance of the updated policy.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                }
                
                // Contact
                PrivacySection(title: "Contact Us", icon: "envelope.fill", color: DSColors.accentPrimary) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("If you have questions about this privacy policy or Reverie's privacy practices, please visit:")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textPrimary)
                        
                        Button(action: {
                            if let url = URL(string: "https://www.reverie.app") {
                                openURL(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "link")
                                Text("www.reverie.app")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.accentPrimary)
                            .padding(12)
                            .background(DSColors.canvasSecondary)
                            .cornerRadius(UIConstants.CornerRadius.standard)
                        }
                    }
                }
                
                // Developer Info
                VStack(spacing: 8) {
                    Text("Developed by")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    
                    Text("Irigam Innovations")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("Building thoughtful tools for modern life")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Components

struct PrivacySection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(DSFonts.headline())
                    .foregroundColor(color)
                
                Text(title)
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
            }
            
            content
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}

struct PrivacyDetail: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSFonts.label())
                .foregroundColor(DSColors.textPrimary)
            
            Text(description)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
        }
    }
}

struct NonCollectionItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(DSFonts.body())
                .foregroundColor(DSColors.error)
            
            Text(text)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
        }
    }
}

// MARK: - Helper Components
struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFonts.headline())
                Text(description)
                    .font(DSFonts.label())
                    .foregroundColor(DSColors.textSecondary)
            }
        }
    }
}

struct PrivacyPoint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(DSColors.success)
                .frame(width: 24)
            Text(text)
                .font(DSFonts.body())
        }
    }
}

// MARK: - Recommend to Friend Sheet

struct RecommendToFriendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    private let shareMessage = """
    I've been using Reverie for task management and it's been great! 
    
    It's a privacy-first productivity app that works completely offline - all your data stays on your device. No accounts, no tracking, no ads.
    
    Search "Reverie" on the Apple App Store to download it.
    """
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                
                // Title
                VStack(spacing: 8) {
                    Text("Recommend Reverie")
                        .font(DSFonts.title())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("Share with friends who value privacy")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // App Store Notice
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "app.badge.checkmark.fill")
                            .foregroundColor(DSColors.accentPrimary)
                        Text("Find on App Store")
                            .font(DSFonts.label())
                    }
                    
                    Text("Your friends can find Reverie by searching the Apple App Store. Share the app with anyone who values privacy and offline productivity!")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
                .padding(.horizontal)
                
                Spacer()
                
                // Share Button
                Button(action: {
                    showShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Reverie")
                    }
                    .font(DSFonts.label())
                    .fontWeight(.semibold)
                    .foregroundColor(DSColors.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DSColors.accentPrimary)
                    .cornerRadius(UIConstants.CornerRadius.large)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding()
            .navigationTitle("Recommend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareMessage])
            }
        }
    }
}

#Preview {
    MoreView()
}
