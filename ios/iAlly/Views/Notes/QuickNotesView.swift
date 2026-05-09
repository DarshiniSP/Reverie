// QuickNotesView.swift
// iAlly
//
// A scratchpad for quick thoughts — like iOS Notes.
// User captures fast, reviews later, and promotes each note to a Task,
// Journey, Routine, or Knowledge item. Notes are never injected into
// Lumina context automatically.

import SwiftUI
import SwiftData

// MARK: - List View

struct QuickNotesView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<LuminaNote> { !$0.isArchived },
        sort: \LuminaNote.createdAt,
        order: .reverse
    ) private var notes: [LuminaNote]

    @State private var searchQuery = ""
    @State private var showCompose  = false
    @State private var editingNote: LuminaNote?
    @State private var promotingNote: LuminaNote?

    private var filteredNotes: [LuminaNote] {
        guard !searchQuery.isEmpty else { return notes }
        return notes.filter {
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        Group {
            if notes.isEmpty {
                emptyState
            } else {
                noteList
            }
        }
        .navigationTitle("Quick Notes")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchQuery, prompt: "Search notes…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCompose = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New note")
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeNoteView()
        }
        .sheet(item: $editingNote) { note in
            ComposeNoteView(note: note)
        }
        .sheet(item: $promotingNote) { note in
            PromoteNoteSheet(note: note)
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 56))
                .foregroundColor(DSColors.textSecondary.opacity(0.4))
            Text("No notes yet")
                .font(DSFonts.title())
                .foregroundColor(DSColors.textPrimary)
            Text("Capture a quick thought. Review it later and turn it into a task, journey, or routine.")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showCompose = true
            } label: {
                Label("New Note", systemImage: "square.and.pencil")
                    .font(DSFonts.body().weight(.medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(DSColors.accentPrimary)
                    .foregroundColor(DSColors.onAccent)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColors.canvasPrimary.ignoresSafeArea())
    }

    // MARK: Note List

    private var noteList: some View {
        List {
            ForEach(filteredNotes) { note in
                QuickNoteRow(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture { editingNote = note }
                    .swipeActions(edge: .leading) {
                        Button {
                            promotingNote = note
                        } label: {
                            Label("Use", systemImage: "arrow.up.forward.circle.fill")
                        }
                        .tint(DSColors.accentPrimary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            archive(note)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
                    .contextMenu {
                        Button {
                            editingNote = note
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button {
                            promotingNote = note
                        } label: {
                            Label("Use this note…", systemImage: "arrow.up.forward.circle")
                        }
                        Divider()
                        Button(role: .destructive) {
                            archive(note)
                        } label: {
                            Label("Archive", systemImage: "archivebox")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private func archive(_ note: LuminaNote) {
        note.isArchived = true
        try? modelContext.save()
    }
}

// MARK: - Row

private struct QuickNoteRow: View {

    let note: LuminaNote

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.content)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(note.createdAt, style: .relative)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)

                if let promoted = note.promotedTo {
                    Text("→ \(promoted)")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.accentPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DSColors.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Compose / Edit Sheet

struct ComposeNoteView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Non-nil when editing an existing note.
    var note: LuminaNote? = nil

    @State private var content = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("What's on your mind?")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                }
                TextEditor(text: $content)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .focused($focused)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DSColors.canvasPrimary)
            .navigationTitle(note == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .bold()
                }
            }
            .onAppear {
                content = note?.content ?? ""
                focused = true
            }
        }
    }

    private func save() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = note {
            existing.content  = trimmed
            existing.updatedAt = Date()
        } else {
            let newNote = LuminaNote(content: trimmed)
            modelContext.insert(newNote)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Promote Sheet

struct PromoteNoteSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let note: LuminaNote

    @State private var showTaskConfirm    = false
    @State private var showKnowledgePick  = false
    @State private var knowledgeType: KnowledgeItemType = .learning
    @State private var feedbackMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Note preview
                VStack(alignment: .leading, spacing: 6) {
                    Text("Note")
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textSecondary)
                    Text(note.content)
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
                .padding()

                if let msg = feedbackMessage {
                    Text(msg)
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.success)
                        .padding(.horizontal)
                        .transition(.opacity)
                }

                List {
                    Section("Turn this note into…") {

                        // Create Task
                        Button {
                            createTask()
                        } label: {
                            Label("Create Task", systemImage: "checkmark.circle.fill")
                                .foregroundColor(DSColors.accentPrimary)
                        }

                        // Add to Knowledge
                        DisclosureGroup(
                            isExpanded: $showKnowledgePick,
                            content: {
                                Picker("Type", selection: $knowledgeType) {
                                    ForEach(KnowledgeItemType.allCases) { t in
                                        Label(t.rawValue, systemImage: t.icon).tag(t)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.vertical, 4)

                                Button("Save to Knowledge Base") {
                                    saveKnowledge()
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.vertical, 4)
                            },
                            label: {
                                Label("Add to Knowledge", systemImage: "lightbulb.fill")
                                    .foregroundColor(Color(hex: "#F5A623"))
                            }
                        )

                        // Send to Lumina
                        Button {
                            sendToLumina()
                        } label: {
                            Label("Ask Lumina about this", systemImage: "bubble.left.and.sparkles")
                                .foregroundColor(DSColors.accentSecondary)
                        }
                    }

                    Section {
                        // Archive without promoting
                        Button(role: .destructive) {
                            archive()
                        } label: {
                            Label("Archive note", systemImage: "archivebox")
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("Use Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: Actions

    private func createTask() {
        let task = TaskWork(
            title: note.content,
            detail: nil,
            dueDate: nil,
            energy: nil,
            size: .medium
        )
        modelContext.insert(task)
        note.promotedTo  = "Task"
        note.isArchived  = true
        try? modelContext.save()
        PAIMemoryBridge.shared.recordTaskCreated(task)
        WidgetHelper.shared.reloadAllWidgets()
        withAnimation { feedbackMessage = "Task created." }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }

    private func saveKnowledge() {
        let words = note.content.split(separator: " ")
        let title = String(words.prefix(6).joined(separator: " "))
        let repo  = KnowledgeRepository(context: modelContext)
        _ = try? repo.create(
            title: title,
            content: note.content,
            type: knowledgeType
        )
        note.promotedTo = "Knowledge (\(knowledgeType.rawValue))"
        note.isArchived = true
        try? modelContext.save()
        withAnimation { feedbackMessage = "Added to Knowledge Base." }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }

    private func sendToLumina() {
        // Pre-fill Lumina input — user can refine the prompt before sending
        LuminaConversationService.shared.pendingInput = note.content
        note.promotedTo = "Lumina"
        note.isArchived = true
        try? modelContext.save()
        dismiss()
    }

    private func archive() {
        note.isArchived = true
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        QuickNotesView()
    }
    .modelContainer(for: LuminaNote.self, inMemory: true)
}
