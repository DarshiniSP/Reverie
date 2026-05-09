//
//  ChecklistsView.swift
//  iAlly
//
//  Main view listing all standalone checklists (groceries, travel, exams, etc.).
//  Follows the RoutinesView pattern.
//

import SwiftUI
import SwiftData

struct ChecklistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Checklist.createdAt, order: .reverse) private var checklists: [Checklist]
    @State private var showAddChecklist = false

    private var activeChecklists: [Checklist] {
        checklists.filter { !$0.isDeleted }
    }

    var body: some View {
        ZStack {
            DSColors.canvasPrimary
                .ignoresSafeArea()

            if activeChecklists.isEmpty {
                emptyState
            } else {
                checklistGrid
            }
        }
        .navigationTitle("Checklists")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddChecklist = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.accentPrimary)
                }
                .accessibilityIdentifier("addChecklistButton")
            }
        }
        .sheet(isPresented: $showAddChecklist) {
            AddChecklistView()
                .environment(\.modelContext, modelContext)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))

            Text("No Checklists Yet")
                .font(DSFonts.title())
                .foregroundColor(DSColors.textPrimary)

            Text("Create reusable checklists for groceries, travel packing, bill payments, and more")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Create Your First Checklist") {
                showAddChecklist = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
    }

    // MARK: - Checklist Grid

    private var checklistGrid: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(activeChecklists) { checklist in
                    NavigationLink(destination: ChecklistDetailView(checklist: checklist)) {
                        ChecklistCardView(checklist: checklist)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contextMenu {
                        if checklist.totalCount > 0 {
                            Button {
                                checklist.resetAll()
                                try? modelContext.save()
                            } label: {
                                Label("Reset All Items", systemImage: "arrow.counterclockwise")
                            }
                        }

                        Button(role: .destructive) {
                            checklist.isDeleted = true
                            try? modelContext.save()
                        } label: {
                            Label("Delete Checklist", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Checklist Card View

struct ChecklistCardView: View {
    let checklist: Checklist

    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: checklist.icon)
                        .font(DSFonts.title())
                        .foregroundColor(checklist.color)

                    Spacer()

                    if checklist.totalCount > 0 {
                        ChecklistProgressView(
                            completed: checklist.completedCount,
                            total: checklist.totalCount
                        )
                    }
                }

                Text(checklist.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if checklist.isRecurring {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(DSFonts.caption())
                            Text("Recurring")
                                .font(DSFonts.caption())
                        }
                        .foregroundColor(DSColors.accentPrimary)
                    }

                    Spacer()

                    Text("\(checklist.totalCount) items")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }

                // Progress bar
                if checklist.totalCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Progress")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Text("\(Int(checklist.progress * 100))%")
                                .font(DSFonts.caption())
                                .fontWeight(.medium)
                                .foregroundColor(checklist.color)
                        }

                        ProgressView(value: checklist.progress)
                            .tint(checklist.color)
                            .frame(height: 4)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChecklistsView()
    }
    .modelContainer(for: [Checklist.self], inMemory: true)
}
