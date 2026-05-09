//
//  FAQView.swift
//  iAlly
//
//  Created on 13/12/2025.
//  Updated: 14/12/2025 - Comprehensive FAQ from FAQ.md
//

import SwiftUI

struct FAQView: View {
    @State private var expandedIndex: Int? = nil
    @State private var selectedSection: FAQSection = .gettingStarted
    
    enum FAQSection: String, CaseIterable {
        case gettingStarted = "Getting Started"
        case privacyData = "Privacy & Data"
        case lumina = "Lumina AI"
        case tasks = "Tasks & Productivity"
        case focus = "Focus & Time Management"
        case aiInsights = "AI Insights & Analytics"
        case routines = "Routines & Streaks"
        case tags = "Tags & Custom Views"
        case notifications = "Notifications & Reminders"
        case icloudSync = "iCloud Sync & Data"
        case troubleshooting = "Troubleshooting"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FAQSection.allCases, id: \.self) { section in
                        Button(action: {
                            withAnimation {
                                selectedSection = section
                                expandedIndex = nil
                            }
                        }) {
                            Text(section.rawValue)
                                .font(DSFonts.body(14))
                                .fontWeight(selectedSection == section ? .semibold : .regular)
                                .foregroundColor(selectedSection == section ? DSColors.onAccent : DSColors.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSection == section ?
                                    DSColors.accentPrimary : DSColors.canvasSecondary
                                )
                                .cornerRadius(UIConstants.CornerRadius.round)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(DSColors.canvasPrimary)
            
            Divider()
            
            // FAQ Content
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(faqItems(for: selectedSection).enumerated()), id: \.offset) { index, item in
                        FAQItem(
                            index: index,
                            number: item.number,
                            question: item.question,
                            answer: item.answer,
                            expandedIndex: $expandedIndex
                        )
                    }
                }
                .padding()
                
                // Support Section
                VStack(spacing: 12) {
                    Divider()
                        .padding(.vertical)
                    
                    Text("Still have questions?")
                        .font(DSFonts.headline())
                    
                    Text("Visit our website for more information")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.accentPrimary)
                    
                    Text("www.iAlly.app")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                .padding()
            }
        }
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func faqItems(for section: FAQSection) -> [(number: String, question: String, answer: String)] {
        switch section {
        case .gettingStarted:
            return [
                ("1.1", "What is iAlly?", "iAlly is a privacy-first personal productivity app that helps you organise tasks, achieve goals, and build lasting habits — entirely on your device. It also includes Lumina, an AI assistant that can create tasks, set up routines, manage journeys, and answer questions about your schedule using natural conversation. No account required."),
                ("1.2", "How is iAlly different from other productivity apps?", "iAlly combines a full-featured task and goal system with a conversational AI assistant, all with your privacy protected. Key differences: No account required — start immediately. Data stays on your device by default. Full offline support — every feature works without internet. Life Domains — organise work across 8 life areas for balance. Lumina AI — natural language task creation and goal management. Growth Mindset — tracks resilience and recovery, not just completion rates."),
                ("1.3", "Do I need to create an account?", "No. iAlly works immediately without any account. Your data is stored locally on your device using SwiftData — Apple's native data framework. Optional iCloud Sync backs up to your own iCloud account (not our servers)."),
                ("1.4", "Does iAlly work offline?", "Yes. iAlly is designed offline-first. All core features work without internet: creating and completing tasks, tracking routines and streaks, Focus Mode, AI Insights, and Calendar integration. Lumina AI requires an internet connection if using a cloud AI provider (Claude, ChatGPT, Gemini). Only iCloud Sync requires internet."),
                ("1.5", "Where do I start?", "Open the Today tab to see tasks due today. Tap the + button to add your first task. Tap More → Lumina to chat with your AI assistant. Explore Plans for goal-based task groups, Journeys for long-term goals, and More → Routines for recurring habits."),
            ]
        case .privacyData:
            return [
                ("2.1", "Where is my data stored?", "All your tasks, plans, journeys, routines, and Lumina conversations are stored locally on your device using SwiftData — Apple's native data framework. No data is sent anywhere by default."),
                ("2.2", "Does Lumina AI send my data to the cloud?", "Only if you configure a cloud AI provider (Claude, ChatGPT, Gemini, or Mercury) in Settings → Lumina AI. In that case, your message and relevant context from your task data is sent to that provider using your own API key. Sensitive personal health information (entered in Settings → Lumina Profile → Never Auto-Shared) is never sent to any AI provider — it stays on device only. If you use a local provider (no API key configured), nothing leaves your device."),
                ("2.3", "What context does Lumina receive about me?", "Lumina receives only what's needed for each message. Tier 1 (always sent): your name, timezone, communication style, current focus. Tier 2 (only when relevant to the topic): work context, scheduling constraints, family context. Tier 3: health notes — never sent automatically, you paste these in manually if you want Lumina to know. All of this is configurable in Settings → Lumina AI → Lumina Profile."),
                ("2.4", "What is iCloud Sync?", "iCloud Sync is an optional backup that stores your data in your personal iCloud account (not our servers). When enabled, data syncs across your devices and is end-to-end encrypted by Apple. This is not a social feature — no sharing with other users. Enable in: More → Settings → iCloud Sync."),
                ("2.5", "Can other people see my tasks?", "No. iAlly has zero social features. Your data is completely private."),
                ("2.6", "What happens if I delete the app?", "Without iCloud Sync: all data is permanently deleted. With iCloud Sync enabled: data remains in your iCloud and restores when you reinstall."),
            ]
        case .lumina:
            return [
                ("3.1", "What is Lumina?", "Lumina is iAlly's built-in AI assistant. You can have a conversation with Lumina to create tasks, set up routines, plan journeys, check what you have on, and get advice about your goals and schedule. Lumina reads your live task and routine data and can take action — with your confirmation — directly from the chat."),
                ("3.2", "How do I start a conversation with Lumina?", "Tap More tab → Lumina. Type or speak your message. Examples: 'Add a task to review the quarterly report by Friday', 'Set up a daily meditation habit at 7am', 'What do I have on today?', 'Help me plan a journey to learn Spanish this year'."),
                ("3.3", "Can Lumina create and modify my tasks?", "Yes. When Lumina detects you want to create or change something, it shows a confirmation card with the details. Tap Confirm on the card and the item is created or updated in your app. Lumina never makes changes without showing the card and receiving your confirmation first."),
                ("3.4", "What can Lumina do?", "Lumina can: Create tasks with priority, due date, and detail. Set up routines (daily, weekly, custom days). Create journeys with milestones for long-term goals. Create plans for goal-based task groups. Complete, update, reschedule, or delete tasks. Complete or delete routines, plans, and journeys. Answer questions about your schedule, tasks, and goals. Give advice based on your context and goals."),
                ("3.5", "Which AI providers does Lumina support?", "Claude (Anthropic), ChatGPT (OpenAI), Gemini (Google), and Mercury (Inception). Configure your provider and API key in More → Settings → Lumina AI → AI Provider. Each provider requires your own API key. If no key is configured, Lumina operates in a limited offline mode."),
                ("3.6", "How do I configure Lumina's context about me?", "Go to More → Settings → Lumina AI → Lumina Profile. Here you can set your communication style (e.g., 'brief and direct'), current focus, work context, scheduling constraints, and more. The profile is organised by what Lumina always receives vs. only when relevant — keeping token usage and data sharing minimal."),
                ("3.7", "Are my Lumina conversations saved?", "Yes. Conversations are saved in the Lumina chat history on your device. You can start new conversations or continue previous ones. Conversation history is not sent to any server unless you are using a cloud AI provider, in which case only the recent context window is included in each call."),
                ("3.8", "What is the Knowledge Base?", "The Knowledge Base (More → Knowledge Base) is a second-brain for notes, learnings, quotes, and decisions. Items you capture here can optionally sync to Lumina's memory so it remembers context across conversations (requires PAI connection). Access from More → Knowledge Base."),
            ]
        case .tasks:
            return [
                ("4.1", "What are Life Domains?", "8 fundamental areas of life for balance: Health (physical wellness), Career (work, projects), Relationships (family, friends), Learning (education, skills), Creativity (art, hobbies), Finance (money, budgeting), Home (household, maintenance), Personal (self-care, values). Every task, plan, journey, and routine belongs to one domain."),
                ("4.2", "What's the difference between Tasks, Plans, and Journeys?", "Tasks: individual action items with a due date, priority, and energy level (e.g., 'Send invoice by Thursday'). Plans: groups of related tasks within one Life Domain — good for projects (e.g., 'Website Redesign' under Career). Journeys: long-term goals broken into ordered milestones — for months-long ambitions (e.g., 'Launch My Business' with milestones over 6 months)."),
                ("4.3", "What are Routines?", "Routines are recurring task templates that build habits. Frequencies: Daily, Weekly, Weekdays, Monthly, Custom (specific days). Routines automatically generate task instances in your Today view. They include streak tracking to show consistency over time."),
                ("4.4", "How does task prioritization work?", "Priority: Urgent (red), High, Medium, Low. Energy: High (complex work), Medium, Low (quick tasks). Size: Large, Medium, Small. Use high-priority and high-energy tasks during your peak hours — AI Insights shows when you perform best."),
                ("4.5", "What is the Inbox?", "The Inbox (Today tab → Inbox) holds tasks with no due date and no plan. It's a capture zone — add tasks quickly and organise later. Ask Lumina 'What's in my inbox?' for a quick review."),
                ("4.6", "Can I convert a calendar event to a task?", "Yes. In the Today tab, find the event in the Calendar Events section → swipe left → 'Create Task'. Event details auto-populate the task form."),
            ]
        case .focus:
            return [
                ("5.1", "How does Focus Mode work?", "Focus Mode is a Pomodoro-style timer (default 25 minutes work, 5 minutes break). Select a task, tap the Focus icon, and the timer starts. The session links to the task for time tracking in Analytics. A Live Activity shows the timer on your lock screen. Sessions are saved in your Focus History."),
                ("5.2", "What is Time Blocking?", "Time Blocking (More → Time Blocking) lets you visually schedule tasks on a daily timeline. Assign tasks to time slots, see your day at a glance, and set realistic duration estimates. Blocks are colour-coded by Life Domain."),
                ("5.3", "Can I track how long tasks actually take?", "Yes. Focus Mode tracks exact timer time. When you complete a task, you can also log the actual time taken in the completion reflection. Analytics shows total focus time per day and week, average duration by task size, and time breakdown by Life Domain."),
            ]
        case .aiInsights:
            return [
                ("6.1", "What are AI Insights?", "AI Insights analyses your productivity patterns entirely on-device using your task completion history. No external AI is used. It generates: Productivity Score (completion rate, on-time %), Energy Timeline (when you complete high vs. low energy tasks), Domain Balance (which life areas you're investing in), and Recommendations (actionable suggestions based on your patterns)."),
                ("6.2", "Is AI Insights different from Lumina AI?", "Yes, they are separate. AI Insights uses local statistical analysis of your SwiftData to generate behavioural patterns — no internet required, no AI provider needed. Lumina AI is a conversational assistant powered by a language model (Claude, ChatGPT, etc.) for natural language interaction. Both complement each other: Insights shows what you're doing, Lumina helps you plan what to do next."),
                ("6.3", "What's the difference between AI Insights and Analytics Dashboard?", "AI Insights: Behavioural patterns and recommendations (e.g., 'You complete 60% of tasks before noon but only 35% in the evening'). Analytics Dashboard: Raw numbers — task counts, completion rates, focus totals, domain charts. Use Insights for self-improvement, Analytics for tracking progress."),
                ("6.4", "How accurate are the insights?", "Insights improve with more data. Week 1: basic patterns. Weeks 2–4: meaningful insights emerge. Month 2+: highly personalised. Requirements: at least 5 completed tasks, 3 days of usage, and 1 mindset event (completion reflection). Each insight shows a confidence rating based on data quality."),
                ("6.5", "What is Growth Mindset tracking?", "iAlly tracks resilience alongside completion. For every task or routine, it records: miss count (times overdue), reschedule count, and recovery count (times you returned after missing). Recovery counts are shown positively — they represent resilience. Routines also track recovery count when you resume a broken streak."),
            ]
        case .routines:
            return [
                ("7.1", "How do streaks work?", "Streaks count consecutive completions. Daily routine: complete every day = streak increments. Weekly routine: complete every week = streak increments. Miss a day or week = streak resets. iAlly tracks: Current streak, Longest streak, Total completions, and Recovery count (how many times you bounced back after a break)."),
                ("7.2", "What happens if I miss a routine?", "Current streak resets to 0. A streak break is recorded. Recovery tracking begins — when you resume, the recovery count increments. Recovery counts are shown as a positive resilience metric, not a negative one."),
                ("7.3", "Can I skip a routine without breaking the streak?", "Yes. Swipe on the routine task → Skip This Once. The streak stays intact (marked as an intentional skip). Use this for planned days off, illness, or special circumstances."),
                ("7.4", "Can I edit routine frequency after creating it?", "Yes, with a caution: changing frequency deletes future generated tasks and recreates them on the new schedule. Past completions and streaks are preserved. Example: changing 'Daily' to 'Mon/Wed/Fri' regenerates tasks for the new days only."),
                ("7.5", "Can Lumina set up a routine for me?", "Yes. Tell Lumina: 'Set up a daily meditation habit at 7am' or 'Create a gym routine every Monday, Wednesday and Friday at 6pm'. Lumina will propose the routine with a confirmation card. Tap Confirm to create it."),
            ]
        case .tags:
            return [
                ("8.1", "What are Tags?", "Tags are custom labels for organising tasks across plans. Examples: #urgent, #quick-win, #waiting-on-others. You can apply up to 10 tags per task. Tags are colour-coded and support custom icons. Use tags to group tasks from different plans that share a characteristic."),
                ("8.2", "What are Custom Views?", "Custom Views (More → Custom Views) are saved task filters for quick access. Example: create a 'High Priority Morning Tasks' view filtering by Priority = High, Energy = High, sorted by due date. Tap the view any time to see only those tasks."),
                ("8.3", "What's the difference between Tags and Life Domains?", "Life Domains: 8 fixed categories (Health, Career, etc.) — one per plan, used for life-area balance tracking. Tags: unlimited, user-created labels applied to individual tasks. Use Domains for broad categorisation and Plans, use Tags for task-level attributes like #urgent or #delegated."),
            ]
        case .notifications:
            return [
                ("9.1", "How do task reminders work?", "By default, iAlly sends a reminder at 9:00 AM on the due date of each task, and a Daily Review reminder at 8:00 PM. Both times are adjustable in More → Settings → Notifications (range: 6 AM – 11 PM)."),
                ("9.2", "Why am I not getting notifications?", "Check in this order: 1) iOS Settings → iAlly → Notifications → Allow Notifications must be ON. 2) iAlly → Settings → Notifications toggle must be ON. 3) Use Settings → Test Notifications to verify delivery. 4) Restart the app if you recently changed settings. Note: the app must be opened at least once after installation to register notifications."),
                ("9.3", "Can I set different reminder times for different tasks?", "Currently all tasks use the global reminder time set in Settings. Per-task custom reminders (e.g., 15 minutes before, or a specific time independent of due date) are planned for a future update."),
                ("9.4", "What's the Daily Review notification?", "The Daily Review notification (default 8 PM) prompts you to review tomorrow's tasks, reschedule anything overdue, and reflect on today. Adjust the time in More → Settings → Notifications to fit your evening routine."),
            ]
        case .icloudSync:
            return [
                ("10.1", "How do I enable iCloud Sync?", "1) Make sure you are signed into iCloud on your device (iOS Settings → [Your Name] → iCloud). 2) Open iAlly → More → Settings. 3) Toggle iCloud Sync ON. 4) Wait for 'Backed up to iCloud' status (first sync may take 10–30 seconds)."),
                ("10.2", "How do I check if iCloud Sync is working?", "Go to More → Settings → iCloud Sync section. Status: Backed up to iCloud (working), Backing up... (in progress), iCloud Backup Active (waiting for connection), Backup Error (check internet and iCloud storage). If sync fails: check internet, verify iCloud has storage, restart the app, or toggle sync off and back on."),
                ("10.3", "Can I sync between iPhone and iPad?", "Yes. Both devices must use the same Apple ID and have iCloud Sync enabled. Changes sync automatically within 1–2 minutes when connected. Pull-to-refresh forces an immediate sync check."),
                ("10.4", "What happens if two devices edit the same task offline?", "iCloud uses last-write-wins conflict resolution. Both devices edit offline → come online → the most recently saved change wins. Avoid editing the same task simultaneously on multiple devices."),
            ]
        case .troubleshooting:
            return [
                ("11.1", "App crashes on launch", "Most common causes: corrupted database, iOS version below 17, or insufficient device storage. Steps: 1) Restart your device (fixes most cases). 2) Update to the latest iOS version. 3) If iCloud Sync is enabled: delete the app, reinstall, and your data will restore from iCloud. 4) If none of those work, contact support."),
                ("11.2", "Tasks are duplicating", "Usually an iCloud Sync edge case. Fix: 1) Toggle iCloud Sync OFF in Settings. 2) Delete the duplicate tasks. 3) Wait 30 seconds. 4) Toggle iCloud Sync back ON. 5) Pull-to-refresh. Avoid rapid task creation while iCloud is syncing."),
                ("11.3", "Routines aren't generating tasks", "Check: 1) Routine has a valid Start Date (required, must be today or earlier). 2) End Date is in the future (3 months ahead recommended). 3) Frequency and active days are configured correctly. Fix: edit the routine, verify dates, save, then restart the app. Tasks generate within a few seconds of launch."),
                ("11.4", "Streak count is incorrect", "Possible causes: time zone change (travel), completing a task after midnight (counts toward the next day), or an intentional skip. How streaks count: Daily = each calendar day midnight-to-midnight. Weekly = within the scheduled week. Custom = interval-based from start date."),
                ("11.5", "Focus timer isn't recording to my task", "Make sure: 1) You selected a task before starting the timer. 2) The task is not already completed. 3) You let the session finish — force-quitting mid-session does not save. Check Analytics → Focus Sessions to verify the session is linked."),
                ("11.6", "Calendar events aren't showing", "Requirements: Calendar permission must be granted (iOS Settings → Privacy → Calendars → iAlly → Allow), and Calendar Integration must be enabled in iAlly Settings. Only today's and tomorrow's events are shown. Pull-to-refresh after granting permission."),
                ("11.7", "AI Insights shows No insights yet", "Insights require: at least 5 completed tasks, 3 days of usage, and at least 1 completion reflection (mindset event). Use Focus Mode and complete tasks with reflection to build data faster. Insights appear within 3–7 days and improve significantly after 2 weeks."),
                ("11.8", "Lumina isn't responding or gives an error", "Check: 1) An AI provider is configured in Settings → Lumina AI → AI Provider. 2) Your API key is valid and has available credits. 3) You have an internet connection. 4) Try the Test button on the provider card to verify connectivity. If you see a timeout, the provider may be experiencing issues — try again or switch providers."),
                ("11.9", "Search isn't finding my task", "Search is case-insensitive and matches partial words. It searches task titles, descriptions, tags, and plan names — but not completion reflections. Make sure the task exists and hasn't been deleted. Use tags to make tasks easier to find later."),
            ]
        }
    }
}

// MARK: - FAQ Item Component
struct FAQItem: View {
    let index: Int
    let number: String
    let question: String
    let answer: String
    @Binding var expandedIndex: Int?
    
    var isExpanded: Bool {
        expandedIndex == index
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expandedIndex = isExpanded ? nil : index
                }
            }) {
                HStack(alignment: .top, spacing: 12) {
                    // Number badge
                    Text(number)
                        .font(DSFonts.body(12))
                        .fontWeight(.bold)
                        .foregroundColor(DSColors.onAccent)
                        .frame(width: 36, height: 24)
                        .background(DSColors.accentPrimary)
                        .cornerRadius(UIConstants.CornerRadius.small)
                    
                    Text(question)
                        .font(DSFonts.headline(15))
                        .foregroundColor(DSColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(DSColors.accentPrimary)
                        .font(DSFonts.body(14))
                }
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Text(answer)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textSecondary)
                    .lineSpacing(4)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSColors.canvasTertiary)
                    .cornerRadius(UIConstants.CornerRadius.large)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
