//
//  TodayView.swift
//  Reverie
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var showSearch = false
    @State private var showFocusMode = false
    @State private var showQuickCapture = false
    @State private var showCountdowns = false
    @State private var showChecklists = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                DSColors.canvasPrimary.ignoresSafeArea()

                ScrollView {
                    TodayContentView()
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 14) {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(DSColors.accentPrimary)
                        }

                        Menu {
                            Button {
                                showQuickCapture = true
                            } label: {
                                Label("Quick Add", systemImage: "bolt.fill")
                            }
                            Button {
                                showChecklists = true
                            } label: {
                                Label("Checklists", systemImage: "checklist")
                            }
                            Button {
                                showCountdowns = true
                            } label: {
                                Label("Countdowns & Deadlines", systemImage: "calendar.badge.clock")
                            }
                            Divider()
                            Button {
                                showFocusMode = true
                            } label: {
                                Label("Focus Mode", systemImage: "timer")
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityIdentifier("addTaskButton")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .sheet(isPresented: $showFocusMode) {
                FocusModeView()
            }
            .sheet(isPresented: $showQuickCapture) {
                QuickCaptureView()
            }
            .sheet(isPresented: $showCountdowns) {
                CountdownView()
            }
            .sheet(isPresented: $showChecklists) {
                ChecklistsView()
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [TaskWork.self, Routine.self], inMemory: true)
}
