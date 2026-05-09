//
//  LuminaView.swift
//  iAlly
//
//  Phase 2: Capture & Knowledge Layer
//  The persistent conversational interface — streaming responses from PAIService,
//  optional voice input via SFSpeechRecognizer, and a new-session action.
//
//  GAP 3: Loads the most recent persisted LuminaSession on appear so
//         conversation history survives app restarts.
//  GAP 8: Shows a task-proposal confirmation card when Lumina suggests creating
//         a task — user taps Confirm to insert it into SwiftData.
//

import SwiftUI
import SwiftData
import Speech
import AVFoundation

struct LuminaView: View {

    @State private var service = LuminaConversationService.shared
    @State private var inputText = ""
    @State private var isListening = false
    @State private var speechError: String?
    @FocusState private var inputFocused: Bool

    // GAP 3 + 8: SwiftData context for session loading and task creation
    @Environment(\.modelContext) private var modelContext

    // P1-E: Quick Capture sheet
    @State private var showQuickCapture = false

    // Speech recogniser (on-device)
    @State private var recogniser = SFSpeechRecognizer(locale: Locale.current)
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner
                messageList
                // Proposal cards — MODIFY first (delete/complete), then CREATE
                if let proposal = service.pendingJourneyDeleteProposal {
                    journeyDeleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingJourneyDeleteProposal != nil)
                } else if let proposal = service.pendingJourneyCompleteProposal {
                    journeyCompleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingJourneyCompleteProposal != nil)
                } else if let proposal = service.pendingPlanDeleteProposal {
                    planDeleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingPlanDeleteProposal != nil)
                } else if let proposal = service.pendingPlanCompleteProposal {
                    planCompleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingPlanCompleteProposal != nil)
                } else if let proposal = service.pendingMilestoneDeleteProposal {
                    milestoneDeleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingMilestoneDeleteProposal != nil)
                } else if let proposal = service.pendingMilestoneCompleteProposal {
                    milestoneCompleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingMilestoneCompleteProposal != nil)
                } else if let proposal = service.pendingRoutineDeleteProposal {
                    routineDeleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingRoutineDeleteProposal != nil)
                } else if let proposal = service.pendingTaskCompleteProposal {
                    taskCompleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingTaskCompleteProposal != nil)
                } else if let proposal = service.pendingTaskUpdateProposal {
                    taskUpdateCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingTaskUpdateProposal != nil)
                } else if let proposal = service.pendingTaskDeleteProposal {
                    taskDeleteCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingTaskDeleteProposal != nil)
                } else if let proposal = service.pendingJourneyProposal {
                    journeyProposalCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingJourneyProposal != nil)
                } else if let proposal = service.pendingPlanProposal {
                    planProposalCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingPlanProposal != nil)
                } else if let proposal = service.pendingMilestoneProposal {
                    milestoneProposalCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingMilestoneProposal != nil)
                } else if let proposal = service.pendingRoutineProposal {
                    routineProposalCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingRoutineProposal != nil)
                } else if let proposal = service.pendingTaskProposal {
                    taskProposalCard(proposal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: service.pendingTaskProposal != nil)
                }
                inputBar
            }
            .navigationTitle("Lumina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // P1-E: Quick Capture button (lightning bolt = immediate capture)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showQuickCapture = true
                    } label: {
                        Image(systemName: "bolt.circle")
                    }
                    .accessibilityLabel("Quick Capture")
                    .accessibilityIdentifier("quickCaptureButton")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        service.startNewSession()
                        Task { await service.sendWelcomeIfNeeded() }
                    } label: {
                        Image(systemName: "plus.bubble")
                    }
                    .accessibilityLabel("New conversation")
                }
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .task {
                // GAP 3: Restore most recent session before showing welcome
                service.loadMostRecentSession(context: modelContext)
                await service.sendWelcomeIfNeeded()
            }
            .onChange(of: service.pendingInput) { _, pending in
                if let text = pending, !text.isEmpty {
                    inputText = text
                    service.pendingInput = nil
                    inputFocused = true
                }
            }
        }
    }

    // MARK: - Connection banner

    @ViewBuilder
    private var connectionBanner: some View {
        let hasProvider = LuminaInferenceRouter.shared.isActiveProviderConfigured

        if !hasProvider {
            // No AI provider configured — warn the user.
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                Text("No AI provider configured — go to Settings to add an API key")
                    .font(DSFonts.caption())
            }
            .foregroundColor(DSColors.onAccent)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(DSColors.warning)
        }
        // else: direct provider is configured → banner suppressed; inference works normally.
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(service.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                    if service.isTyping {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: service.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: service.isTyping) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(DSColors.canvasPrimary)
    }

    @ViewBuilder
    private func messageBubble(_ message: LuminaMessage) -> some View {
        if message.role == .info {
            // Local acknowledgment pill — centered, no avatar, never sent to the model
            HStack {
                Spacer()
                Text(message.content)
                    .font(DSFonts.caption(12).italic())
                    .foregroundColor(DSColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DSColors.canvasSecondary)
                    .clipShape(Capsule())
                Spacer()
            }
        } else {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                // Lumina avatar
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18))
                    .foregroundColor(DSColors.accentPrimary)
                    .frame(width: 32, height: 32)
                    .background(DSColors.accentPrimary.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? "…" : message.content)
                    .font(DSFonts.body())
                    .foregroundColor(message.role == .user ? DSColors.onAccent : DSColors.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.role == .user
                            ? DSColors.accentPrimary
                            : DSColors.canvasSecondary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(message.timestamp, style: .time)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }

            if message.role == .user {
                // User avatar placeholder
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(DSColors.textSecondary)
            } else {
                Spacer(minLength: 60)
            }
        }
        .accessibilityElement(children: .combine)
        } // end else (non-info roles)
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 18))
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 32, height: 32)
                .background(DSColors.accentPrimary.opacity(0.1))
                .clipShape(Circle())

            TypingDotsView()
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DSColors.canvasSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer(minLength: 60)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if service.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = service.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // Voice button
                Button {
                    isListening ? stopListening() : startListening()
                } label: {
                    Image(systemName: isListening ? "mic.fill" : "mic")
                        .font(.system(size: 20))
                        .foregroundColor(isListening ? .red : DSColors.accentPrimary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(isListening ? "Stop dictation" : "Start dictation")

                // Text input
                TextField("Ask Lumina anything…", text: $inputText, axis: .vertical)
                    .font(DSFonts.body())
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .onSubmit { sendMessage() }
                    .accessibilityIdentifier("luminaInputField")
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                inputFocused = false
                            }
                        }
                    }

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DSColors.textSecondary
                            : DSColors.accentPrimary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || service.isTyping)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DSColors.canvasPrimary)
        }
    }

    // MARK: - GAP 8: Task proposal card

    @ViewBuilder
    private func taskProposalCard(_ proposal: LuminaTaskProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(DSFonts.headline(13))
                    .foregroundColor(DSColors.accentPrimary)
                Text("Create Task?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Button {
                    withAnimation { service.pendingTaskProposal = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(DSColors.textSecondary)
                }
                .accessibilityLabel("Dismiss proposal")
            }

            // Task title
            Text(proposal.title)
                .font(DSFonts.body().weight(.medium))
                .foregroundColor(DSColors.textPrimary)

            // Optional detail
            if let detail = proposal.detail {
                Text(detail)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }

            // Priority badge
            if let priorityStr = proposal.priority, let priority = Priority(rawValue: priorityStr.capitalized) {
                HStack(spacing: 4) {
                    Image(systemName: priority.icon)
                        .font(.system(size: 10))
                    Text(priority.rawValue)
                        .font(DSFonts.caption())
                }
                .foregroundColor(Color(hex: priority.color))
            }

            // Checklist preview
            if let items = proposal.checklistItems, !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checklist (\(items.count) items)")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    ForEach(items.prefix(5), id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "circle")
                                .font(.system(size: 10))
                                .foregroundColor(DSColors.textSecondary)
                            Text(item)
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textPrimary)
                        }
                    }
                    if items.count > 5 {
                        Text("+\(items.count - 5) more")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            }

            // Action buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation { service.pendingTaskProposal = nil }
                }
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)

                Button {
                    confirmCreateTask(proposal)
                } label: {
                    Label("Create Task", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.accentPrimary)
                .accessibilityIdentifier("confirmCreateTaskButton")
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DSColors.accentPrimary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func confirmCreateTask(_ proposal: LuminaTaskProposal) {
        // Map priority string → Priority enum (case-insensitive)
        let priority = proposal.priority.flatMap { Priority(rawValue: $0.capitalized) } ?? .medium

        // Create the task in SwiftData
        let task = TaskWork(title: proposal.title, detail: proposal.detail)
        task.priority = priority

        // Apply due date if Lumina resolved one (from ISO8601 marker or NLP fallback).
        // Tasks with a dueDate appear in Today/Upcoming views and the calendar;
        // tasks without one land in Inbox.
        if let dueDate = proposal.dueDate {
            task.dueDate = dueDate
        }

        // Apply checklist items if Lumina proposed any.
        if let items = proposal.checklistItems, !items.isEmpty {
            task.checklistItems = items.enumerated().map { i, title in
                ChecklistItem(title: title, order: i)
            }
        }

        modelContext.insert(task)
        try? modelContext.save()

        // Schedule a local notification for the due date (only if in the future).
        // NotificationManager handles the authorization check internally.
        if let dueDate = proposal.dueDate, dueDate > Date() {
            Task {
                await NotificationManager.shared.scheduleTaskDueNotification(
                    taskId: task.id.uuidString,
                    taskTitle: task.title,
                    dueDate: dueDate
                )
            }
        }

        // Sync to system calendar (if user has calendar integration enabled).
        if task.dueDate != nil {
            let _ = CalendarManager.shared.createEvent(from: task)
        }

        // Refresh widgets so task counts update immediately.
        WidgetHelper.shared.reloadAllWidgets()

        // Record to PAI episodic memory
        PAIMemoryBridge.shared.recordTaskCreated(task)

        // Dismiss the proposal card
        withAnimation { service.pendingTaskProposal = nil }

        // Acknowledge in chat — local bubble only, never sent to the model
        let scheduleNote: String
        if let dueDate = proposal.dueDate {
            let f = DateFormatter()
            f.dateStyle = .none
            f.timeStyle = .short
            let dateStr = Calendar.current.isDateInToday(dueDate)
                ? "today at \(f.string(from: dueDate))"
                : { f.dateStyle = .short; return f.string(from: dueDate) }()
            scheduleNote = " — scheduled \(dateStr)"
        } else {
            scheduleNote = ""
        }
        service.appendLocalAck("✓ Task created: \"\(proposal.title)\"\(scheduleNote)")
    }

    // MARK: - CRUD proposal cards (complete / update / delete)

    @ViewBuilder
    private func taskCompleteCard(_ proposal: LuminaTaskCompleteProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(DSColors.success)
                Text("Mark as Complete?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingTaskCompleteProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            if !proposal.remarks.isEmpty {
                Text("Note: \(proposal.remarks)")
                    .font(DSFonts.caption(11)).foregroundColor(DSColors.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingTaskCompleteProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmCompleteTask(proposal) } label: {
                    Label("Mark Done", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(DSColors.success)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DSColors.success.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func confirmCompleteTask(_ proposal: LuminaTaskCompleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<TaskWork>()
        guard let tasks = try? modelContext.fetch(desc) else { return }
        let matched = tasks.filter({ $0.completedAt == nil }).first { $0.title.lowercased() == lower }
            ?? tasks.filter({ $0.completedAt == nil }).first { $0.title.lowercased().hasPrefix(lower) }
            ?? tasks.filter({ $0.completedAt == nil }).first { $0.title.lowercased().contains(lower) }
        guard let task = matched else {
            service.appendLocalAck("Could not find an open task matching \"\(proposal.title)\".")
            withAnimation { service.pendingTaskCompleteProposal = nil }
            return
        }
        task.completedAt = Date()
        if !proposal.remarks.isEmpty { task.completionReflection = proposal.remarks }
        try? modelContext.save()
        PAIMemoryBridge.shared.recordTaskCompleted(task)
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingTaskCompleteProposal = nil }
        service.appendLocalAck("✓ Marked complete: \"\(task.title)\"")
    }

    @ViewBuilder
    private func taskUpdateCard(_ proposal: LuminaTaskUpdateProposal) -> some View {
        let accentColor = DSColors.accentPrimary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.circle.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(accentColor)
                Text("Update Task?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingTaskUpdateProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.matchTitle).font(DSFonts.body().weight(.medium))
            if let newTitle = proposal.newTitle {
                Label("Rename to: \(newTitle)", systemImage: "character.cursor.ibeam")
                    .font(DSFonts.caption(11)).foregroundColor(DSColors.textSecondary)
            }
            if let dueDate = proposal.dueDate {
                let df: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f }()
                Label("Reschedule to: \(df.string(from: dueDate))", systemImage: "calendar")
                    .font(DSFonts.caption(11)).foregroundColor(DSColors.textSecondary)
            }
            if let priority = proposal.priority {
                Label("Priority: \(priority)", systemImage: "flag.fill")
                    .font(DSFonts.caption(11)).foregroundColor(DSColors.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingTaskUpdateProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmUpdateTask(proposal) } label: {
                    Label("Update", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(accentColor)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(accentColor.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func confirmUpdateTask(_ proposal: LuminaTaskUpdateProposal) {
        let lower = proposal.matchTitle.lowercased()
        let desc = FetchDescriptor<TaskWork>()
        guard let tasks = try? modelContext.fetch(desc) else { return }
        let matched = tasks.first { $0.title.lowercased() == lower }
            ?? tasks.first { $0.title.lowercased().hasPrefix(lower) }
            ?? tasks.first { $0.title.lowercased().contains(lower) }
        guard let task = matched else {
            service.appendLocalAck("Could not find a task matching \"\(proposal.matchTitle)\".")
            withAnimation { service.pendingTaskUpdateProposal = nil }
            return
        }
        var changes: [String] = []
        if let newTitle = proposal.newTitle {
            task.title = newTitle
            changes.append("renamed to \"\(newTitle)\"")
        }
        if let dueDate = proposal.dueDate {
            task.dueDate = dueDate
            changes.append("rescheduled")
            // Update calendar event
            let _ = CalendarManager.shared.createEvent(from: task)
        }
        if let priority = proposal.priority,
           let p = Priority(rawValue: priority.capitalized) {
            task.priority = p
            changes.append("priority → \(priority)")
        }
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingTaskUpdateProposal = nil }
        let summary = changes.isEmpty ? "no changes" : changes.joined(separator: ", ")
        service.appendLocalAck("✓ Task updated: \"\(task.title)\" — \(summary)")
    }

    @ViewBuilder
    private func taskDeleteCard(_ proposal: LuminaTaskDeleteProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(DSColors.error)
                Text("Delete Task?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingTaskDeleteProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            Text("This cannot be undone.")
                .font(DSFonts.caption(11)).foregroundColor(DSColors.error.opacity(0.8))
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingTaskDeleteProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmDeleteTask(proposal) } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(.red)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DSColors.error.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func confirmDeleteTask(_ proposal: LuminaTaskDeleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<TaskWork>()
        guard let tasks = try? modelContext.fetch(desc) else { return }
        let matched = tasks.first { $0.title.lowercased() == lower }
            ?? tasks.first { $0.title.lowercased().hasPrefix(lower) }
            ?? tasks.first { $0.title.lowercased().contains(lower) }
        guard let task = matched else {
            service.appendLocalAck("Could not find a task matching \"\(proposal.title)\".")
            withAnimation { service.pendingTaskDeleteProposal = nil }
            return
        }
        // Safety: if the task has been started (has focus sessions), refuse deletion.
        if let sessions = task.focusSessions, !sessions.isEmpty {
            service.appendLocalAck("This task has been started. Please mark it complete with remarks instead.")
            withAnimation { service.pendingTaskDeleteProposal = nil }
            return
        }
        let title = task.title
        modelContext.delete(task)
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingTaskDeleteProposal = nil }
        service.appendLocalAck("✓ Deleted: \"\(title)\"")
    }

    // MARK: - Routine delete card

    private func routineDeleteCard(_ proposal: LuminaRoutineDeleteProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(DSColors.error)
                Text("Delete Routine?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingRoutineDeleteProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            Text("This will remove the routine and all its upcoming tasks. This cannot be undone.")
                .font(DSFonts.caption(11)).foregroundColor(DSColors.error.opacity(0.8))
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingRoutineDeleteProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmDeleteRoutine(proposal) } label: {
                    Label("Delete Routine", systemImage: "trash.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent).tint(.red)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DSColors.error.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    private func confirmDeleteRoutine(_ proposal: LuminaRoutineDeleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Routine>()
        guard let routines = try? modelContext.fetch(desc) else { return }
        let matched = routines.first { $0.title.lowercased() == lower }
            ?? routines.first { $0.title.lowercased().hasPrefix(lower) }
            ?? routines.first { $0.title.lowercased().contains(lower) }
        guard let routine = matched else {
            service.appendLocalAck("Could not find a routine matching \"\(proposal.title)\".")
            withAnimation { service.pendingRoutineDeleteProposal = nil }
            return
        }
        let routineTitle = routine.title
        // Delete future (incomplete) tasks generated by this routine.
        // The relationship is .nullify so we must delete them manually before removing the routine.
        if let tasks = routine.generatedTasks {
            for task in tasks where task.completedAt == nil {
                modelContext.delete(task)
            }
        }
        modelContext.delete(routine)
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingRoutineDeleteProposal = nil }
        service.appendLocalAck("✓ Deleted routine: \"\(routineTitle)\" and all upcoming tasks.")
    }

    // MARK: - Plan CRUD cards

    private func planDeleteCard(_ proposal: LuminaPlanDeleteProposal) -> some View {
        crudDestructiveCard(
            icon: "folder.fill", color: DSColors.error,
            header: "Delete Plan?", name: proposal.title,
            warning: "This will also delete all tasks in this plan. Cannot be undone.",
            actionLabel: "Delete Plan", actionIcon: "trash.fill",
            cancel: { service.pendingPlanDeleteProposal = nil },
            confirm: { confirmDeletePlan(proposal) }
        )
    }

    private func confirmDeletePlan(_ proposal: LuminaPlanDeleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Plan>()
        guard let plans = try? modelContext.fetch(desc) else { return }
        let matched = plans.first { $0.name.lowercased() == lower }
            ?? plans.first { $0.name.lowercased().hasPrefix(lower) }
            ?? plans.first { $0.name.lowercased().contains(lower) }
        guard let plan = matched else {
            service.appendLocalAck("Could not find a plan matching \"\(proposal.title)\".")
            withAnimation { service.pendingPlanDeleteProposal = nil }
            return
        }
        if plan.activeTaskCount > 0 || plan.completedTaskCount > 0 {
            service.appendLocalAck("This plan has active or completed tasks — please complete it with remarks instead.")
            withAnimation { service.pendingPlanDeleteProposal = nil }
            return
        }
        let name = plan.name
        modelContext.delete(plan)
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingPlanDeleteProposal = nil }
        service.appendLocalAck("✓ Deleted plan: \"\(name)\"")
    }

    private func planCompleteCard(_ proposal: LuminaPlanCompleteProposal) -> some View {
        crudCompleteCard(
            icon: "folder.badge.checkmark", color: DSColors.success,
            header: "Complete Plan?", name: proposal.title,
            remarks: proposal.remarks,
            actionLabel: "Complete Plan", actionIcon: "checkmark.circle.fill",
            cancel: { service.pendingPlanCompleteProposal = nil },
            confirm: { confirmCompletePlan(proposal) }
        )
    }

    private func confirmCompletePlan(_ proposal: LuminaPlanCompleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Plan>()
        guard let plans = try? modelContext.fetch(desc) else { return }
        let matched = plans.first { $0.name.lowercased() == lower }
            ?? plans.first { $0.name.lowercased().hasPrefix(lower) }
            ?? plans.first { $0.name.lowercased().contains(lower) }
        guard let plan = matched else {
            service.appendLocalAck("Could not find a plan matching \"\(proposal.title)\".")
            withAnimation { service.pendingPlanCompleteProposal = nil }
            return
        }
        plan.status = .archived
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingPlanCompleteProposal = nil }
        let note = proposal.remarks.isEmpty ? "" : " — \(proposal.remarks)"
        service.appendLocalAck("✓ Completed plan: \"\(plan.name)\"\(note)")
    }

    // MARK: - Journey CRUD cards

    private func journeyDeleteCard(_ proposal: LuminaJourneyDeleteProposal) -> some View {
        crudDestructiveCard(
            icon: "flag.fill", color: DSColors.error,
            header: "Delete Journey?", name: proposal.title,
            warning: "This will also delete all milestones. Cannot be undone.",
            actionLabel: "Delete Journey", actionIcon: "trash.fill",
            cancel: { service.pendingJourneyDeleteProposal = nil },
            confirm: { confirmDeleteJourney(proposal) }
        )
    }

    private func confirmDeleteJourney(_ proposal: LuminaJourneyDeleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Journey>()
        guard let journeys = try? modelContext.fetch(desc) else { return }
        let matched = journeys.first { $0.title.lowercased() == lower }
            ?? journeys.first { $0.title.lowercased().hasPrefix(lower) }
            ?? journeys.first { $0.title.lowercased().contains(lower) }
        guard let journey = matched else {
            service.appendLocalAck("Could not find a journey matching \"\(proposal.title)\".")
            withAnimation { service.pendingJourneyDeleteProposal = nil }
            return
        }
        let hasStarted = journey.milestones?.contains {
            $0.completedAt != nil || ($0.tasks?.contains { $0.completedAt != nil } ?? false)
        } ?? false
        if hasStarted {
            service.appendLocalAck("This journey has started milestones — please complete it with remarks instead.")
            withAnimation { service.pendingJourneyDeleteProposal = nil }
            return
        }
        let title = journey.title
        modelContext.delete(journey)
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingJourneyDeleteProposal = nil }
        service.appendLocalAck("✓ Deleted journey: \"\(title)\"")
    }

    private func journeyCompleteCard(_ proposal: LuminaJourneyCompleteProposal) -> some View {
        crudCompleteCard(
            icon: "flag.checkered", color: DSColors.success,
            header: "Complete Journey?", name: proposal.title,
            remarks: proposal.remarks,
            actionLabel: "Complete Journey", actionIcon: "checkmark.circle.fill",
            cancel: { service.pendingJourneyCompleteProposal = nil },
            confirm: { confirmCompleteJourney(proposal) }
        )
    }

    private func confirmCompleteJourney(_ proposal: LuminaJourneyCompleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Journey>()
        guard let journeys = try? modelContext.fetch(desc) else { return }
        let matched = journeys.first { $0.title.lowercased() == lower }
            ?? journeys.first { $0.title.lowercased().hasPrefix(lower) }
            ?? journeys.first { $0.title.lowercased().contains(lower) }
        guard let journey = matched else {
            service.appendLocalAck("Could not find a journey matching \"\(proposal.title)\".")
            withAnimation { service.pendingJourneyCompleteProposal = nil }
            return
        }
        journey.status = .completed
        try? modelContext.save()
        PAIMemoryBridge.shared.recordJourneyStarted(journey) // reuse for completion record
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingJourneyCompleteProposal = nil }
        let note = proposal.remarks.isEmpty ? "" : " — \(proposal.remarks)"
        service.appendLocalAck("✓ Completed journey: \"\(journey.title)\"\(note)")
    }

    // MARK: - Milestone CRUD cards

    private func milestoneDeleteCard(_ proposal: LuminaMilestoneDeleteProposal) -> some View {
        crudDestructiveCard(
            icon: "mappin.circle.fill", color: DSColors.error,
            header: "Delete Milestone?", name: proposal.title,
            warning: "This cannot be undone.",
            actionLabel: "Delete Milestone", actionIcon: "trash.fill",
            cancel: { service.pendingMilestoneDeleteProposal = nil },
            confirm: { confirmDeleteMilestone(proposal) }
        )
    }

    private func confirmDeleteMilestone(_ proposal: LuminaMilestoneDeleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Milestone>()
        guard let milestones = try? modelContext.fetch(desc) else { return }
        let matched = milestones.first { $0.title.lowercased() == lower }
            ?? milestones.first { $0.title.lowercased().hasPrefix(lower) }
            ?? milestones.first { $0.title.lowercased().contains(lower) }
        guard let milestone = matched else {
            service.appendLocalAck("Could not find a milestone matching \"\(proposal.title)\".")
            withAnimation { service.pendingMilestoneDeleteProposal = nil }
            return
        }
        let isStarted = milestone.completedAt != nil ||
            (milestone.tasks?.contains { $0.completedAt != nil } ?? false)
        if isStarted {
            service.appendLocalAck("This milestone has been started — please complete it with remarks instead.")
            withAnimation { service.pendingMilestoneDeleteProposal = nil }
            return
        }
        let title = milestone.title
        modelContext.delete(milestone)
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingMilestoneDeleteProposal = nil }
        service.appendLocalAck("✓ Deleted milestone: \"\(title)\"")
    }

    private func milestoneCompleteCard(_ proposal: LuminaMilestoneCompleteProposal) -> some View {
        crudCompleteCard(
            icon: "mappin.and.ellipse", color: DSColors.success,
            header: "Complete Milestone?", name: proposal.title,
            remarks: proposal.remarks,
            actionLabel: "Complete Milestone", actionIcon: "checkmark.circle.fill",
            cancel: { service.pendingMilestoneCompleteProposal = nil },
            confirm: { confirmCompleteMilestone(proposal) }
        )
    }

    private func confirmCompleteMilestone(_ proposal: LuminaMilestoneCompleteProposal) {
        let lower = proposal.title.lowercased()
        let desc = FetchDescriptor<Milestone>()
        guard let milestones = try? modelContext.fetch(desc) else { return }
        let matched = milestones.first { $0.title.lowercased() == lower }
            ?? milestones.first { $0.title.lowercased().hasPrefix(lower) }
            ?? milestones.first { $0.title.lowercased().contains(lower) }
        guard let milestone = matched else {
            service.appendLocalAck("Could not find a milestone matching \"\(proposal.title)\".")
            withAnimation { service.pendingMilestoneCompleteProposal = nil }
            return
        }
        // Respect canBeCompleted — don't allow completing milestones with incomplete tasks
        guard milestone.canBeCompleted else {
            let pending = milestone.tasks?.filter { $0.completedAt == nil }.count ?? 0
            service.appendLocalAck("Cannot complete \"\(milestone.title)\" — \(pending) task(s) still incomplete.")
            withAnimation { service.pendingMilestoneCompleteProposal = nil }
            return
        }
        milestone.completedAt = Date()
        // Update journey status
        if let journey = milestone.journey {
            if journey.status == .notStarted || journey.status == nil {
                journey.status = .inProgress
            }
            if let allMilestones = journey.milestones, allMilestones.allSatisfy({ $0.isCompleted }) {
                journey.status = .completed
            }
            PAIMemoryBridge.shared.recordMilestoneCompleted(milestone: milestone, journey: journey)
        }
        try? modelContext.save()
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingMilestoneCompleteProposal = nil }
        let note = proposal.remarks.isEmpty ? "" : " — \(proposal.remarks)"
        service.appendLocalAck("✓ Completed milestone: \"\(milestone.title)\"\(note)")
    }

    // MARK: - Shared card builders (DRY)

    @ViewBuilder
    private func crudDestructiveCard(
        icon: String, color: Color,
        header: String, name: String, warning: String,
        actionLabel: String, actionIcon: String,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(DSFonts.headline(13)).foregroundColor(color)
                Text(header).font(DSFonts.caption().weight(.semibold)).foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { cancel() } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(name).font(DSFonts.body().weight(.medium))
            Text(warning).font(DSFonts.caption(11)).foregroundColor(DSColors.error.opacity(0.8))
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { cancel() } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirm() } label: {
                    Label(actionLabel, systemImage: actionIcon).font(DSFonts.caption().weight(.semibold))
                }.buttonStyle(.borderedProminent).tint(color)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    @ViewBuilder
    private func crudCompleteCard(
        icon: String, color: Color,
        header: String, name: String, remarks: String,
        actionLabel: String, actionIcon: String,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(DSFonts.headline(13)).foregroundColor(color)
                Text(header).font(DSFonts.caption().weight(.semibold)).foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { cancel() } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(name).font(DSFonts.body().weight(.medium))
            if !remarks.isEmpty {
                Text("Note: \(remarks)").font(DSFonts.caption(11)).foregroundColor(DSColors.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { cancel() } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirm() } label: {
                    Label(actionLabel, systemImage: actionIcon).font(DSFonts.caption().weight(.semibold))
                }.buttonStyle(.borderedProminent).tint(color)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16).padding(.bottom, 4)
    }

    // MARK: - GAP 8: Routine proposal card

    @ViewBuilder
    private func routineProposalCard(_ proposal: LuminaRoutineProposal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(DSColors.warning)
                Text("Create Routine?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textSecondary)
                Spacer()
                Button {
                    withAnimation { service.pendingRoutineProposal = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(DSColors.textSecondary)
                }
                .accessibilityLabel("Dismiss routine proposal")
            }

            // Routine title
            Text(proposal.title)
                .font(DSFonts.body().weight(.medium))
                .foregroundColor(DSColors.textPrimary)

            // Schedule summary pills
            HStack(spacing: 10) {
                Label(proposal.frequency.rawValue, systemImage: proposal.frequency.icon)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.warning)

                if let timeOfDay = proposal.timeOfDay {
                    Label(timeOfDay.formatted(date: .omitted, time: .shortened),
                          systemImage: "clock")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }

                Label("\(proposal.durationWeeks) weeks", systemImage: "calendar")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }

            // Optional detail
            if let detail = proposal.detail {
                Text(detail)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }

            // Action buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation { service.pendingRoutineProposal = nil }
                }
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)

                Button {
                    confirmCreateRoutine(proposal)
                } label: {
                    Label("Create Routine", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(DSColors.warning)
                .accessibilityIdentifier("confirmCreateRoutineButton")
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DSColors.warning.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func confirmCreateRoutine(_ proposal: LuminaRoutineProposal) {
        // Calculate end date from the user's requested duration
        let endDate = Calendar.current.date(
            byAdding: .weekOfYear, value: proposal.durationWeeks, to: Date()
        )

        // Create the Routine in SwiftData (defaults to .personal — user can change in Routines)
        let routine = Routine(
            title: proposal.title,
            lifeDomain: .personal,
            frequency: proposal.frequency,
            activeDays: proposal.daysOfWeek,
            timeOfDay: proposal.timeOfDay,
            autoGenerateDays: 14,
            endDate: endDate
        )
        modelContext.insert(routine)
        try? modelContext.save()

        // Pre-generate the first 14-day batch of TaskWork instances
        Task {
            await RoutineManager.shared.generateTasksForRoutine(routine, context: modelContext)
        }

        // Create recurring calendar events if the user has granted access
        let durationDays = proposal.durationWeeks * 7
        let _ = CalendarManager.shared.createRecurringEvent(from: routine, durationDays: durationDays)

        // Refresh widgets so task counts update immediately
        WidgetHelper.shared.reloadAllWidgets()

        // Dismiss the proposal card
        withAnimation { service.pendingRoutineProposal = nil }

        // Acknowledge in chat — local bubble only, never sent to the model
        let freqLabel = proposal.frequency == .custom ? "weekdays" : proposal.frequency.rawValue.lowercased()
        let timeLabel = proposal.timeOfDay.map {
            " at \($0.formatted(date: .omitted, time: .shortened))"
        } ?? ""
        let durationLabel = "\(proposal.durationWeeks) week\(proposal.durationWeeks == 1 ? "" : "s")"
        service.appendLocalAck("✓ Routine created: \"\(proposal.title)\" — \(freqLabel)\(timeLabel) for \(durationLabel)")
    }

    // MARK: - Journey proposal card

    @ViewBuilder
    private func journeyProposalCard(_ proposal: LuminaJourneyProposal) -> some View {
        let domain = proposal.domain.flatMap { LifeDomain(rawValue: $0.capitalized) } ?? .personal
        let color  = Color(hex: proposal.colorHex ?? domain.defaultColor)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: proposal.icon ?? "flag.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(color)
                Text("Create Journey?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingJourneyProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            if let vision = proposal.vision {
                Text(vision).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
            }
            HStack(spacing: 8) {
                Label(domain.rawValue, systemImage: domain.icon)
                    .font(DSFonts.caption(11))
                    .foregroundColor(color)
                if let targetDate = proposal.targetDate {
                    let df: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; return f }()
                    Label("Target: \(df.string(from: targetDate))", systemImage: "calendar")
                        .font(DSFonts.caption(11))
                        .foregroundColor(DSColors.textSecondary)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingJourneyProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmCreateJourney(proposal) } label: {
                    Label("Create Journey", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func confirmCreateJourney(_ proposal: LuminaJourneyProposal) {
        let domain    = proposal.domain.flatMap { LifeDomain(rawValue: $0.capitalized) } ?? .personal
        let colorHex  = proposal.colorHex ?? domain.defaultColor
        let icon      = proposal.icon ?? "flag.fill"
        let journey   = Journey(title: proposal.title, vision: proposal.vision,
                                targetDate: proposal.targetDate, colorHex: colorHex,
                                icon: icon, status: .notStarted, lifeDomain: domain)
        modelContext.insert(journey)
        try? modelContext.save()
        PAIMemoryBridge.shared.recordJourneyStarted(journey)
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingJourneyProposal = nil }
        service.appendLocalAck("✓ Journey created: \"\(proposal.title)\" — generating milestones…")

        // Auto-generate milestones in the background via a one-shot inference call.
        // The result is shown as a follow-up ack; the journey card is already dismissed.
        let ctx = modelContext
        Task {
            let created = await service.generateMilestones(for: journey, modelContext: ctx)
            if created.isEmpty {
                service.appendLocalAck("Could not auto-generate milestones — add them manually or ask Lumina.")
            } else {
                let list = created.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                service.appendLocalAck("✓ \(created.count) milestones added:\n\(list)")
                WidgetHelper.shared.reloadAllWidgets()
            }
        }
    }

    // MARK: - Plan proposal card

    @ViewBuilder
    private func planProposalCard(_ proposal: LuminaPlanProposal) -> some View {
        let domain = proposal.domain.flatMap { LifeDomain(rawValue: $0.capitalized) } ?? .personal
        let color  = Color(hex: proposal.colorHex ?? domain.defaultColor)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: proposal.icon ?? "folder.fill")
                    .font(DSFonts.headline(13))
                    .foregroundColor(color)
                Text("Create Plan?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingPlanProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            if let goal = proposal.goal {
                Text(goal).font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
            }
            Label(domain.rawValue, systemImage: domain.icon)
                .font(DSFonts.caption(11))
                .foregroundColor(color)
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingPlanProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmCreatePlan(proposal) } label: {
                    Label("Create Plan", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func confirmCreatePlan(_ proposal: LuminaPlanProposal) {
        let domain   = proposal.domain.flatMap { LifeDomain(rawValue: $0.capitalized) } ?? .personal
        let colorHex = proposal.colorHex ?? domain.defaultColor
        let icon     = proposal.icon ?? "folder.fill"
        let plan     = Plan(name: proposal.title, lifeDomain: domain,
                            icon: icon, colorHex: colorHex, goal: proposal.goal)
        modelContext.insert(plan)
        try? modelContext.save()
        PAIMemoryBridge.shared.recordPlanCreated(plan)
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingPlanProposal = nil }
        service.appendLocalAck("✓ Plan created: \"\(proposal.title)\"")
    }

    // MARK: - Milestone proposal card

    @ViewBuilder
    private func milestoneProposalCard(_ proposal: LuminaMilestoneProposal) -> some View {
        let accentColor = DSColors.accentPrimary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                    .font(DSFonts.headline(13))
                    .foregroundColor(accentColor)
                Text("Add Milestone?")
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                Button { withAnimation { service.pendingMilestoneProposal = nil } } label: {
                    Image(systemName: "xmark").font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                }.buttonStyle(.plain)
            }
            Text(proposal.title).font(DSFonts.body().weight(.medium))
            if let journeyTitle = proposal.journeyTitle {
                Label("In: \(journeyTitle)", systemImage: "map")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textSecondary)
            }
            if let targetDate = proposal.targetDate {
                let df: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; return f }()
                Label("Target: \(df.string(from: targetDate))", systemImage: "calendar")
                    .font(DSFonts.caption(11))
                    .foregroundColor(DSColors.textSecondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { withAnimation { service.pendingMilestoneProposal = nil } }
                    .font(DSFonts.caption()).foregroundColor(DSColors.textSecondary)
                Button { confirmCreateMilestone(proposal) } label: {
                    Label("Add Milestone", systemImage: "checkmark.circle.fill")
                        .font(DSFonts.caption().weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(accentColor)
            }
        }
        .padding(14)
        .background(DSColors.canvasSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(accentColor.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func confirmCreateMilestone(_ proposal: LuminaMilestoneProposal) {
        let milestone = Milestone(title: proposal.title, targetDate: proposal.targetDate)

        // Attach to matching journey if one was named
        if let journeyTitle = proposal.journeyTitle {
            let desc = FetchDescriptor<Journey>()
            if let journeys = try? modelContext.fetch(desc) {
                let lower = journeyTitle.lowercased()
                // Fuzzy match: exact first, then prefix, then contains
                let matched = journeys.first { $0.title.lowercased() == lower }
                    ?? journeys.first { $0.title.lowercased().hasPrefix(lower) }
                    ?? journeys.first { $0.title.lowercased().contains(lower) }
                milestone.journey = matched
            }
        }

        modelContext.insert(milestone)
        try? modelContext.save()
        PAIMemoryBridge.shared.recordMilestoneCreated(milestone)
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { service.pendingMilestoneProposal = nil }
        let journeyNote = proposal.journeyTitle.map { " in \"\($0)\"" } ?? ""
        service.appendLocalAck("✓ Milestone added: \"\(proposal.title)\"\(journeyNote)")
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        // Refresh the context reference before every send so buildAppContext() always
        // reads from the live main-actor ModelContext, not a potentially stale snapshot.
        service.modelContext = modelContext
        Task { await service.send(text) }
    }

    // MARK: - Voice / Speech Recognition

    private func startListening() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.speechError = "Microphone access is required for voice input."
                    return
                }
                self.beginRecognition()
            }
        }
    }

    private func beginRecognition() {
        stopListening() // reset any previous session

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
        isListening = true

        recognitionTask = recogniser?.recognitionTask(with: request) { result, error in
            if let result {
                self.inputText = result.bestTranscription.formattedString
            }
            if error != nil || result?.isFinal == true {
                self.stopListening()
            }
        }
    }

    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }
}

// MARK: - Typing dots animation

struct TypingDotsView: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DSColors.textSecondary)
                    .frame(width: 8, height: 8)
                    .scaleEffect(phase == i ? 1.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = 1 }
    }
}

#Preview {
    LuminaView()
}
