//
//  SiriSettingsView.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import SwiftUI
import Intents
import IntentsUI

struct SiriSettingsView: View {
    @State private var showShortcutsGuide = false
    
    var body: some View {
        List {
            // Overview Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.circle.fill")
                            .font(DSFonts.title(34))
                            .foregroundColor(DSColors.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Siri Integration")
                                .font(DSFonts.title(22))
                                .foregroundColor(DSColors.textPrimary)
                            
                            Text("Voice-powered task management")
                                .font(DSFonts.body(14))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    
                    Text("Use Siri to quickly add tasks, check your schedule, and manage your day hands-free.")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
            
            // Natural Language Parser Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(DSColors.accentPrimary)
                        Text("Smart Text Parsing")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textPrimary)
                    }
                    
                    Text("Reverie automatically detects dates, times, and task details when you type naturally.")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ExampleRow(input: "Buy milk tomorrow", detected: "Due: Tomorrow")
                        ExampleRow(input: "Call dentist next monday at 3pm", detected: "Due: Monday 3:00 PM")
                        ExampleRow(input: "Exercise daily small task", detected: "Size: Small, Recurring: Daily")
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Natural Language Processing")
            }
            
            // Voice Commands Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(DSColors.accentPrimary)
                        Text("Available Commands")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textPrimary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        VoiceCommandRow(
                            icon: "plus.circle.fill",
                            command: "Add [task name] to Reverie",
                            example: "Add buy groceries to Reverie"
                        )
                        
                        VoiceCommandRow(
                            icon: "bell.fill",
                            command: "Remind me to [task] in Reverie",
                            example: "Remind me to call dentist in Reverie"
                        )
                        
                        VoiceCommandRow(
                            icon: "calendar.badge.plus",
                            command: "Add [task] for [date] to Reverie",
                            example: "Add team meeting for tomorrow to Reverie"
                        )
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Voice Commands")
            } footer: {
                Text("Say 'Hey Siri' followed by any of these commands to quickly add tasks.")
                    .font(DSFonts.body(13))
            }
            
            // Setup Instructions Section
            Section {
                Button {
                    showShortcutsGuide = true
                } label: {
                    HStack {
                        Image(systemName: "book.circle.fill")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Setup Guide")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            
                            Text("Learn how to create custom Siri Shortcuts")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    if let url = URL(string: "shortcuts://") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "app.badge")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open Shortcuts App")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            
                            Text("Create and manage your Siri Shortcuts")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Shortcuts Setup")
            }
            
            // Features Section
            Section {
                FeatureRow(
                    icon: "calendar",
                    title: "Date Detection",
                    description: "Understands: today, tomorrow, next monday, in 3 days",
                    available: true
                )
                
                FeatureRow(
                    icon: "clock",
                    title: "Time Detection",
                    description: "Supports: 3pm, 14:30, at 5:00pm",
                    available: true
                )
                
                FeatureRow(
                    icon: "chart.bar",
                    title: "Size Detection",
                    description: "Recognizes: small, medium, large, quick",
                    available: true
                )
                
                FeatureRow(
                    icon: "repeat",
                    title: "Recurrence",
                    description: "Detects: daily, weekly, monthly patterns",
                    available: true
                )
            } header: {
                Text("Supported Features")
            }
            
            // Privacy Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(DSColors.accentPrimary)
                        Text("Privacy First")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textPrimary)
                    }
                    
                    Text("All processing happens on your device. No data is sent to external servers. Siri Shortcuts work entirely offline.")
                        .font(DSFonts.body(14))
                        .foregroundColor(DSColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Privacy & Security")
            }

            // P4-C: App Intents — available in Siri and the Shortcuts app
            Section {
                AppIntentRow(
                    icon: "plus.circle.fill",
                    title: "Add Task to Reverie",
                    example: "\"Add call dentist to Reverie\"",
                    description: "Quickly capture any task by voice."
                )
                .accessibilityIdentifier("captureTaskIntentRow")

                AppIntentRow(
                    icon: "brain.head.profile",
                    title: "Get Today's Focus",
                    example: "\"What's my focus for today in Reverie?\"",
                    description: "Hear Lumina's daily briefing spoken aloud."
                )
                .accessibilityIdentifier("dailyBriefingIntentRow")

                AppIntentRow(
                    icon: "checkmark.circle.fill",
                    title: "Mark Routine Complete",
                    example: "\"Mark gym as done in Reverie\"",
                    description: "Hands-free routine completion."
                )
                .accessibilityIdentifier("completeRoutineIntentRow")
            } header: {
                Text("App Intents (Siri & Shortcuts)")
            } footer: {
                Text("These actions appear automatically in Siri and the Shortcuts app. No setup needed.")
                    .font(DSFonts.body(13))
            }
        }
        .navigationTitle("Siri & Voice")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShortcutsGuide) {
            ShortcutsGuideView()
        }
    }
}

// MARK: - Helper Views

// P4-C: App Intent display row
struct AppIntentRow: View {
    let icon: String
    let title: String
    let example: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(DSFonts.headline())
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DSFonts.body().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Text(example)
                    .font(DSFonts.body(13).italic())
                    .foregroundColor(DSColors.textSecondary)
                Text(description)
                    .font(DSFonts.body(12))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExampleRow: View {
    let input: String
    let detected: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\"\(input)\"")
                .font(DSFonts.body(13).italic())
                .foregroundColor(DSColors.textPrimary)
            
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.accentPrimary)
                
                Text(detected)
                    .font(DSFonts.body(12))
                    .foregroundColor(DSColors.accentPrimary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct VoiceCommandRow: View {
    let icon: String
    let command: String
    let example: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(DSFonts.headline())
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(command)
                    .font(DSFonts.body(14).weight(.medium))
                    .foregroundColor(DSColors.textPrimary)
                
                Text("e.g., \"\(example)\"")
                    .font(DSFonts.body(12))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let available: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(DSFonts.headline())
                .foregroundColor(available ? .green : DSColors.textSecondary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                
                Text(description)
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
            }
            
            Spacer()
            
            if available {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DSColors.success)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shortcuts Guide View

struct ShortcutsGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step 1
                    GuideStepView(
                        number: 1,
                        title: "Open Shortcuts App",
                        description: "Launch the Shortcuts app on your iPhone (comes pre-installed with iOS).",
                        icon: "app.badge"
                    )
                    
                    // Step 2
                    GuideStepView(
                        number: 2,
                        title: "Create New Shortcut",
                        description: "Tap the '+' button in the top right corner to create a new shortcut.",
                        icon: "plus.circle.fill"
                    )
                    
                    // Step 3
                    GuideStepView(
                        number: 3,
                        title: "Add iAlly Action",
                        description: "Search for 'iAlly' in the actions list and select 'Add Task'.",
                        icon: "magnifyingglass"
                    )
                    
                    // Step 4
                    GuideStepView(
                        number: 4,
                        title: "Configure Task Details",
                        description: "Set the task title, size, and optional due date. You can use variables for dynamic content.",
                        icon: "slider.horizontal.3"
                    )
                    
                    // Step 5
                    GuideStepView(
                        number: 5,
                        title: "Set Siri Phrase",
                        description: "Tap 'Add to Siri' and record your custom voice command like 'Add groceries to Reverie'.",
                        icon: "mic.circle.fill"
                    )
                    
                    // Step 6
                    GuideStepView(
                        number: 6,
                        title: "Use Your Shortcut",
                        description: "Say 'Hey Siri' followed by your custom phrase to quickly add tasks.",
                        icon: "checkmark.circle.fill"
                    )
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Pro Tips")
                                .font(DSFonts.headline(18))
                                .foregroundColor(DSColors.textPrimary)
                        }
                        
                        TipRow(tip: "Create shortcuts for common tasks like 'Exercise', 'Review goals', or 'Buy groceries'")
                        TipRow(tip: "Use the 'Ask Each Time' option to make shortcuts more flexible")
                        TipRow(tip: "Add shortcuts to your home screen for quick access")
                        TipRow(tip: "Combine iAlly shortcuts with other apps for powerful automations")
                    }
                    .padding()
                    .background(DSColors.accentPrimary.opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.large)
                }
                .padding()
            }
            .navigationTitle("Shortcuts Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GuideStepView: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(DSColors.accentPrimary)
                    .frame(width: 40, height: 40)
                
                Text("\(number)")
                    .font(DSFonts.body().weight(.bold))
                    .foregroundColor(DSColors.onAccent)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(DSColors.accentPrimary)
                    
                    Text(title)
                        .font(DSFonts.body().weight(.semibold))
                        .foregroundColor(DSColors.textPrimary)
                }
                
                Text(description)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TipRow: View {
    let tip: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.accentPrimary)
                .padding(.top, 2)
            
            Text(tip)
                .font(DSFonts.body(14))
                .foregroundColor(DSColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        SiriSettingsView()
    }
}
