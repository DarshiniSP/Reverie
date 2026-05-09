//
//  JourneysView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct JourneysView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showAddJourney = false
    @State private var showSearch = false
    @State private var showStats = false
    @State private var filterStatus: JourneyFilterStatus = .all
    
    private var filteredJourneys: [Journey] {
        switch filterStatus {
        case .all:
            return journeys.filter { !$0.isDeleted }
        case .active:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
                let completed = milestones.filter { $0.isCompleted }.count
                return completed > 0 && completed < milestones.count
            }
        case .completed:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return false }
                return milestones.allSatisfy { $0.isCompleted }
            }
        case .notStarted:
            return journeys.filter { journey in
                guard let milestones = journey.milestones, !milestones.isEmpty else { return true }
                return milestones.allSatisfy { !$0.isCompleted }
            }
        }
    }
    
    private var stats: JourneyStats {
        let activeJourneys = journeys.filter { !$0.isDeleted }
        var active = 0
        var completed = 0
        var totalProgress = 0.0
        
        for journey in activeJourneys {
            guard let milestones = journey.milestones, !milestones.isEmpty else { continue }
            let completedCount = milestones.filter { $0.isCompleted }.count
            let progress = Double(completedCount) / Double(milestones.count)
            totalProgress += progress
            
            if completedCount == milestones.count {
                completed += 1
            } else if completedCount > 0 {
                active += 1
            }
        }
        
        let avgProgress = activeJourneys.isEmpty ? 0 : totalProgress / Double(activeJourneys.count)
        return JourneyStats(total: activeJourneys.count, active: active, completed: completed, avgProgress: avgProgress)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary
                    .ignoresSafeArea()
                
                if filteredJourneys.isEmpty {
                    emptyState
                } else {
                    journeyList
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showStats.toggle() }) {
                            Label(showStats ? "Hide Statistics" : "Show Statistics", systemImage: showStats ? "chart.bar.fill" : "chart.bar")
                        }
                        
                        Divider()
                        
                        Picker("Filter by Status", selection: $filterStatus) {
                            ForEach(JourneyFilterStatus.allCases, id: \.self) { status in
                                Text(status.rawValue).tag(status)
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
                            showAddJourney = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityIdentifier("addJourneyButton")
                    }
                }
            }
            .sheet(isPresented: $showAddJourney) {
                AddJourneyView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showSearch) {
                SearchView(initialScope: .journeys)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DSColors.journey.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColors.journey, DSColors.accentPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("No Journeys Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)

                Text("Big goals broken into milestones.\nStart your first journey.")
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Button("Create Your First Journey") {
                showAddJourney = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
    }
    
    private var journeyList: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showStats && !journeys.isEmpty {
                    summaryStatsCard
                }
                
                LazyVStack(spacing: 12) { // Reverted to 12 to match Plans/Routines
                    ForEach(filteredJourneys) { journey in
                        NavigationLink(destination: JourneyDetailView(journey: journey)) {
                            JourneyRowView(journey: journey)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                    value: "\(stats.total)",
                    label: "Total Journeys",
                    icon: "flag.fill",
                    color: DSColors.accentPrimary
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: "\(stats.active)",
                    label: "Active",
                    icon: "flame.fill",
                    color: DSColors.warning
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: "\(Int(stats.avgProgress * 100))%",
                    label: "Avg Progress",
                    icon: "chart.line.uptrend.xyaxis",
                    color: DSColors.success
                )
            }
            .padding(.vertical, 8)
        }
    }
}

struct JourneyRowView: View {
    let journey: Journey

    var progressPercent: Double {
        guard let milestones = journey.milestones, !milestones.isEmpty else { return 0 }
        let completed = milestones.filter({ $0.isCompleted }).count
        return Double(completed) / Double(milestones.count)
    }

    var journeyColor: Color { Color(hex: journey.colorHex) }

    var body: some View {
        HStack(spacing: 0) {
            // Colored left accent strip
            RoundedCorner(radius: 16, corners: [.topLeft, .bottomLeft])
                .fill(
                    LinearGradient(
                        colors: [journeyColor, journeyColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)

            // Card content
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(journeyColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: journey.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(journeyColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(journey.title)
                            .font(DSFonts.label(15))
                            .foregroundColor(DSColors.textPrimary)
                            .lineLimit(1)

                        if let status = journey.status {
                            HStack(spacing: 4) {
                                Image(systemName: status.icon)
                                Text(status.rawValue)
                            }
                            .font(DSFonts.caption(11))
                            .foregroundColor(Color(hex: status.color))
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(progressPercent * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(journeyColor)
                        if let targetDate = journey.targetDate {
                            Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                                .font(DSFonts.caption(11))
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                }

                if let vision = journey.vision, !vision.isEmpty {
                    Text(vision)
                        .font(DSFonts.body(13))
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                if let milestones = journey.milestones, !milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("\(milestones.filter({ $0.isCompleted }).count) of \(milestones.count) milestones")
                                .font(DSFonts.caption(12))
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(journeyColor.opacity(0.15))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [journeyColor, journeyColor.opacity(0.7)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progressPercent, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(14)
            .background(DSColors.canvasSecondary)
            .clipShape(RoundedCorner(radius: 16, corners: [.topRight, .bottomRight]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: DSColors.shadow, radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DSColors.divider, lineWidth: 0.5)
        )
    }
}

#Preview {
    JourneysView()
        .modelContainer(for: [Journey.self, Milestone.self], inMemory: true)
}
