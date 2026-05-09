//
//  DomainsAndGoalsView.swift
//  Reverie
//
//  Combined Domains + Goals tab with a segmented picker.
//  Uses a single NavigationStack — no nesting.
//

import SwiftUI
import SwiftData

struct DomainsAndGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var segment: Int = 0

    // Domains
    @Query(sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @State private var showAddPlan = false
    @State private var showDeletePlan: Plan?

    // Goals
    @Query(sort: \Journey.createdAt, order: .reverse) private var journeys: [Journey]
    @State private var showAddJourney = false
    @State private var filterStatus: JourneyFilterStatus = .all

    private var activePlans: [Plan] { plans.filter { !$0.isDeleted } }

    private var filteredJourneys: [Journey] {
        switch filterStatus {
        case .all:        return journeys.filter { !$0.isDeleted }
        case .active:     return journeys.filter { j in
            guard let m = j.milestones, !m.isEmpty else { return false }
            let done = m.filter { $0.isCompleted }.count
            return done > 0 && done < m.count
        }
        case .completed:  return journeys.filter { j in
            guard let m = j.milestones, !m.isEmpty else { return false }
            return m.allSatisfy { $0.isCompleted }
        }
        case .notStarted: return journeys.filter { j in
            guard let m = j.milestones, !m.isEmpty else { return true }
            return m.allSatisfy { !$0.isCompleted }
        }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment picker
                Picker("", selection: $segment) {
                    Text("Domains").tag(0)
                    Text("Goals").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DSColors.canvasPrimary)

                Divider()

                ZStack {
                    DSColors.canvasPrimary.ignoresSafeArea()

                    if segment == 0 {
                        domainsContent
                    } else {
                        goalsContent
                    }
                }
            }
            .navigationTitle(segment == 0 ? "Domains" : "Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Filter / sort (Goals only)
                if segment == 1 {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Menu {
                            Picker("Filter", selection: $filterStatus) {
                                ForEach(JourneyFilterStatus.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if segment == 0 { showAddPlan = true }
                        else            { showAddJourney = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(DSFonts.headline())
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    .accessibilityIdentifier(segment == 0 ? "addPlanButton" : "addJourneyButton")
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView().environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showAddJourney) {
                AddJourneyView().environment(\.modelContext, modelContext)
            }
            .alert("Delete Domain", isPresented: Binding(
                get: { showDeletePlan != nil },
                set: { if !$0 { showDeletePlan = nil } }
            )) {
                Button("Cancel", role: .cancel) { showDeletePlan = nil }
                Button("Delete", role: .destructive) {
                    if let plan = showDeletePlan { deletePlan(plan) }
                    showDeletePlan = nil
                }
            } message: {
                Text("Delete this domain? Tasks will be moved to inbox.")
            }
        }
    }

    // MARK: - Domains

    @ViewBuilder
    private var domainsContent: some View {
        if activePlans.isEmpty {
            domainsEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(activePlans) { plan in
                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                            PlanCardView(plan: plan)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) { showDeletePlan = plan } label: {
                                Label("Delete Domain", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var domainsEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(DSColors.plan.opacity(0.12)).frame(width: 110, height: 110)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(
                        colors: [DSColors.plan, DSColors.accentSecondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            VStack(spacing: 8) {
                Text("No Domains Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)
                Text("Group your tasks by domain —\nAcademic, Health, Social, Rest and more.")
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button("Create Your First Domain") { showAddPlan = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
    }

    private func deletePlan(_ plan: Plan) {
        for task in plan.tasks ?? [] { task.plan = nil; task.isInbox = true }
        modelContext.delete(plan)
        try? modelContext.save()
    }

    // MARK: - Goals

    @ViewBuilder
    private var goalsContent: some View {
        if filteredJourneys.isEmpty {
            goalsEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredJourneys) { journey in
                        NavigationLink(destination: JourneyDetailView(journey: journey)) {
                            JourneyRowView(journey: journey)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
    }

    private var goalsEmptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(DSColors.journey.opacity(0.12)).frame(width: 110, height: 110)
                Image(systemName: "map.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient(
                        colors: [DSColors.journey, DSColors.accentPrimary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            VStack(spacing: 8) {
                Text("No Goals Yet")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(DSColors.textPrimary)
                Text("Big goals broken into milestones.\nStart your first goal.")
                    .font(DSFonts.body(15))
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Button("Create Your First Goal") { showAddJourney = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
        }
    }
}
