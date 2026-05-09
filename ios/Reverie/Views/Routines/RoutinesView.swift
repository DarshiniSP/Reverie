//
//  RoutinesView.swift
//  iAlly
//
//  Created on 9/12/2025.
//

import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @State private var showAddRoutine = false
    @State private var showFocusMode = false
    @State private var showSearch = false
    @State private var selectedFrequency: RoutineFrequency? = nil
    @State private var sortOrder: RoutineSortOrder = .streak
    @State private var showArchived = false
    
    private var filteredRoutines: [Routine] {
        var filtered = routines.filter { !$0.isDeleted }
        
        // Filter by frequency
        if let frequency = selectedFrequency {
            filtered = filtered.filter { $0.frequency == frequency }
        }
        
        // Sort
        switch sortOrder {
        case .streak:
            filtered.sort { $0.currentStreak > $1.currentStreak }
        case .name:
            filtered.sort { $0.title < $1.title }
        case .frequency:
            filtered.sort { $0.frequency.sortOrder < $1.frequency.sortOrder }
        case .lastCompleted:
            filtered.sort { 
                ($0.lastCompletedDate ?? .distantPast) > ($1.lastCompletedDate ?? .distantPast)
            }
        }
        
        return filtered
    }
    
    private var stats: RoutineStats {
        let activeRoutines = routines.filter { !$0.isDeleted }
        let today = Calendar.current.startOfDay(for: Date())
        let completedToday = activeRoutines.filter { routine in
            guard let lastCompleted = routine.lastCompletedDate else { return false }
            return Calendar.current.isDate(lastCompleted, inSameDayAs: today)
        }.count
        
        let totalStreak = activeRoutines.reduce(0) { $0 + $1.currentStreak }
        let avgStreak = activeRoutines.isEmpty ? 0.0 : Double(totalStreak) / Double(activeRoutines.count)
        let longestStreak = activeRoutines.map { $0.longestStreak }.max() ?? 0
        
        return RoutineStats(
            total: activeRoutines.count,
            active: activeRoutines.count,
            completedToday: completedToday,
            avgStreak: avgStreak,
            longestStreak: longestStreak
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary
                    .ignoresSafeArea()
                
                if filteredRoutines.isEmpty {
                    emptyState
                } else {
                    routineGrid
                }
            }
            .navigationTitle("Daily Anchors")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showArchived.toggle() }) {
                            Label(showArchived ? "Hide Archived" : "Show Archived", systemImage: showArchived ? "archivebox.fill" : "archivebox")
                        }
                        
                        Divider()
                        
                        Picker("Filter by Frequency", selection: $selectedFrequency) {
                            Text("All Frequencies").tag(nil as RoutineFrequency?)
                            ForEach(RoutineFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq as RoutineFrequency?)
                            }
                        }
                        
                        Divider()
                        
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(RoutineSortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showSearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        
                        Button {
                            showFocusMode = true
                        } label: {
                            Image(systemName: "target")
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        
                        Button {
                            showAddRoutine = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityIdentifier("addRoutineButton")
                    }
                }
            }
            .sheet(isPresented: $showAddRoutine) {
                AddRoutineView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showFocusMode) {
                FocusModeView()
            }
            .sheet(isPresented: $showSearch) {
                SearchView(initialScope: .tasks)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 64))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))
            
            Text("No Routines Yet")
                .font(DSFonts.title())
                .foregroundColor(DSColors.textPrimary)
            
            Text("Create repeating habits to build consistency and track streaks")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Create Your First Routine") {
                showAddRoutine = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
    }
    
    private var routineGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Stats
                if !routines.isEmpty {
                    summaryStatsCard
                }
                LazyVStack(spacing: 12) {
                    ForEach(filteredRoutines) { routine in
                        NavigationLink(destination: RoutineDetailView(routine: routine)) {
                            RoutineCardView(routine: routine)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button {
                                // Use RoutineManager for proper streak logic, completionDates, and PAI memory
                                RoutineManager.shared.updateStreakForRoutine(routine, completionDate: Date(), context: modelContext)
                            } label: {
                                Label("Complete Today", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                modelContext.delete(routine)
                                try? modelContext.save()
                            } label: {
                                Label("Delete Routine", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var summaryStatsCard: some View {
        Card {
            HStack(spacing: 20) {
                StatItem(
                    value: "\(stats.active)",
                    label: "Active",
                    icon: "repeat.circle.fill",
                    color: DSColors.accentPrimary
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: "\(stats.longestStreak)",
                    label: "Best Streak",
                    icon: "flame.fill",
                    color: DSColors.warning
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: "\(Int(stats.avgStreak))",
                    label: "Avg Streak",
                    icon: "chart.line.uptrend.xyaxis",
                    color: DSColors.success
                )
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Routine Card View
struct RoutineCardView: View {
    let routine: Routine
    
    var body: some View {
        Card(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: routine.icon)
                        .font(DSFonts.title())
                        .foregroundColor(Color(hex: routine.colorHex))
                    
                    Spacer()
                    
                    // Streak badge
                    if routine.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(DSFonts.caption())
                            Text("\(routine.currentStreak)")
                                .font(DSFonts.caption())
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(DSColors.warning)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DSColors.warning.opacity(0.15))
                        .cornerRadius(UIConstants.CornerRadius.standard)
                    }
                }
                
                Text(routine.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: routine.frequency.icon)
                        .font(DSFonts.caption())
                    Text(routine.frequency.rawValue)
                        .font(DSFonts.caption())
                    
                    Spacer()
                    
                    Text(routine.lifeDomain.rawValue)
                        .font(DSFonts.caption())
                }
                .foregroundColor(DSColors.textSecondary)
                
                // Consistency rate (last 30 days)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Consistency")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                        Spacer()
                        HStack(spacing: 2) {
                            Text("\(Int(routine.completionRate * 100))%")
                                .font(DSFonts.caption())
                                .fontWeight(.medium)
                            if routine.longestStreak > 0 {
                                Text("• 🏆\(routine.longestStreak)")
                                    .font(DSFonts.caption())
                            }
                        }
                        .foregroundColor(Color(hex: routine.colorHex))
                    }
                    
                    ProgressView(value: routine.completionRate)
                        .tint(Color(hex: routine.colorHex))
                        .frame(height: 4)
                }
            }
        }
        .frame(minHeight: 160)
        .opacity(routine.isActive ? 1.0 : 0.6)
    }
}

// MARK: - StatItem Component (reused from PlansView)
// Already defined in PlansView.swift

#Preview {
    RoutinesView()
        .modelContainer(for: [Routine.self], inMemory: true)
}
