//
//  QuickCaptureView.swift
//  Reverie
//
//  Redesigned: 4 large intent cards (Task / Routine / Knowledge / Note)
//  each opening the dedicated form sheet directly.
//

import SwiftUI
import SwiftData

// MARK: - Capture intent

enum CaptureIntent: String, CaseIterable {
    case task        = "task"
    case routine     = "routine"
    case knowledge   = "knowledge"
    case note        = "note"
    case unknown     = "unknown"

    var icon: String {
        switch self {
        case .task:      return "checkmark.circle.fill"
        case .routine:   return "repeat.circle.fill"
        case .knowledge: return "lightbulb.fill"
        case .note:      return "note.text"
        case .unknown:   return "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .task:      return "Task"
        case .routine:   return "Daily Anchor"
        case .knowledge: return "Knowledge"
        case .note:      return "Note to Lumina"
        case .unknown:   return "Classify…"
        }
    }

    var description: String {
        switch self {
        case .task:      return "Something to get done"
        case .routine:   return "A daily habit to anchor your routine"
        case .knowledge: return "A learning or insight to remember"
        case .note:      return "A quick thought or message to Lumina"
        case .unknown:   return ""
        }
    }

    var colorHex: String {
        switch self {
        case .task:      return "5C8A6E"
        case .routine:   return "7A8A5C"
        case .knowledge: return "D4945A"
        case .note:      return "9EA88E"
        case .unknown:   return "BDC3C7"
        }
    }
}

// MARK: - View

struct QuickCaptureView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showAddTask      = false
    @State private var showAddRoutine   = false
    @State private var showAddKnowledge = false
    @State private var showAddNote      = false

    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("What would you like to capture?")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    // 3 primary intent cards
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            IntentCard(intent: .task)    { showAddTask = true }
                            IntentCard(intent: .routine) { showAddRoutine = true }
                        }
                        IntentCard(intent: .note) { showAddNote = true }
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView()
            }
            .sheet(isPresented: $showAddRoutine) {
                AddRoutineView()
            }
            .sheet(isPresented: $showAddKnowledge) {
                AddKnowledgeView()
            }
            .sheet(isPresented: $showAddNote) {
                ComposeNoteView()
            }
        }
    }
}

// MARK: - Intent Card

struct IntentCard: View {
    let intent: CaptureIntent
    let action: () -> Void

    private var cardColor: Color { Color(hex: intent.colorHex) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: intent.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(cardColor)
                }

                VStack(spacing: 4) {
                    Text(intent.label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(DSColors.textPrimary)
                    Text(intent.description)
                        .font(DSFonts.caption(12))
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 12)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(cardColor.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: DSColors.shadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(intent.label)")
        .accessibilityIdentifier("intentCard_\(intent.rawValue)")
    }
}

extension CaptureIntent: Identifiable {
    var id: String { rawValue }
}

// MARK: - NLP Chip (kept for other uses)

/// A small pill showing a parsed attribute (date, priority, domain) detected by NLP.
struct NLPChip: View {
    let icon: String
    let label: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
        }
        .accessibilityLabel("Detected: \(label)")
    }
}

#Preview {
    QuickCaptureView()
        .modelContainer(for: [TaskWork.self, Knowledge.self], inMemory: true)
}
