//
//  PlansView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct PlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Plan.createdAt, order: .reverse) private var plans: [Plan]
    @ObservedObject private var syncManager = CloudSyncManager.shared
    @State private var showAddPlan = false
    @State private var showSearch = false
    @State private var selectedDomain: LifeDomain? = nil
    @State private var sortOrder: PlanSortOrder = .createdDate
    @State private var showArchived = false
    @State private var showDeletePlan: Plan?
    
    private var filteredPlans: [Plan] {
        var filtered = plans.filter { !$0.isDeleted }
        
        // Filter by domain
        if let domain = selectedDomain {
            filtered = filtered.filter { $0.lifeDomain == domain }
        }
        
        // Sort
        switch sortOrder {
        case .createdDate:
            filtered.sort(by: { $0.createdAt > $1.createdAt })
        case .title:
            filtered.sort(by: { $0.name < $1.name })
        default:
            break
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DSColors.canvasPrimary
                    .ignoresSafeArea()
                
                if filteredPlans.isEmpty {
                    emptyState
                } else {
                    planGrid
                }
            }
            .navigationTitle("Domains")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { showArchived.toggle() }) {
                            Label(showArchived ? "Hide Archived" : "Show Archived", systemImage: showArchived ? "archivebox.fill" : "archivebox")
                        }
                        
                        Divider()
                        
                        Picker("Filter by Domain", selection: $selectedDomain) {
                            Text("All Domains").tag(nil as LifeDomain?)
                            ForEach(LifeDomain.allCases, id: \.self) { domain in
                                Label(domain.rawValue, systemImage: domain.icon).tag(domain as LifeDomain?)
                            }
                        }
                        
                        Divider()
                        
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(PlanSortOrder.allCases, id: \.self) { order in
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
                            showAddPlan = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.accentPrimary)
                        }
                        .accessibilityIdentifier("addPlanButton")
                    }
                }
            }
            .sheet(isPresented: $showAddPlan) {
                AddPlanView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showSearch) {
                SearchView(initialScope: .plans)
            }
            .alert("Delete Life Area", isPresented: Binding(
                get: { showDeletePlan != nil },
                set: { if !$0 { showDeletePlan = nil } }
            )) {
                Button("Cancel", role: .cancel) { showDeletePlan = nil }
                Button("Delete", role: .destructive) {
                    if let plan = showDeletePlan {
                        deletePlan(plan)
                    }
                    showDeletePlan = nil
                }
            } message: {
                Text("Are you sure you want to delete this plan? All tasks will be moved to inbox.")
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DSColors.plan.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColors.plan, DSColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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

            Button("Create Your First Domain") {
                showAddPlan = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
    }
    
    private var planGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Plans Section
                LazyVStack(spacing: 12) {
                    ForEach(filteredPlans) { plan in
                        NavigationLink(destination: PlanDetailView(plan: plan)) {
                            PlanCardView(plan: plan)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                showDeletePlan = plan
                            } label: {
                                Label("Delete Life Area", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            // Refresh will automatically update via @Query
        }
    }
    
    private func deletePlan(_ plan: Plan) {
        // Move all tasks to inbox before deleting the plan
        for task in plan.tasks ?? [] {
            task.plan = nil
            task.isInbox = true
        }
        modelContext.delete(plan)
        try? modelContext.save()
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(DSFonts.headline())
                .foregroundColor(color)
            
            Text(value)
                .font(DSFonts.headline(24))
                .foregroundColor(DSColors.textPrimary)
            
            Text(label)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PlanCardView: View {
    let plan: Plan

    var planColor: Color { Color(hex: plan.colorHex) }

    // Weekly activity: tasks completed in the last 7 days in this life area
    private var weeklyDone: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return plan.tasks?.filter {
            guard let completedAt = $0.completedAt else { return false }
            return completedAt >= cutoff
        }.count ?? 0
    }

    private var activeTasks: Int { plan.activeTaskCount }

    var body: some View {
        VStack(spacing: 0) {
            // Gradient header with icon + name
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [planColor, planColor.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 80)
                .clipShape(RoundedCorner(radius: 16, corners: [.topLeft, .topRight]))

                HStack(alignment: .center, spacing: 10) {
                    // Icon circle
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: plan.lifeDomain.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Plan name in gradient header
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        Text(plan.lifeDomain.rawValue)
                            .font(DSFonts.caption(12))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    // Active task count badge
                    if activeTasks > 0 {
                        Text("\(activeTasks) active")
                            .font(DSFonts.caption(11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding(14)
            }

            // Card body — weekly activity only
            if weeklyDone > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(planColor)
                    Text("\(weeklyDone) done this week")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(planColor)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(DSColors.canvasSecondary)
                .clipShape(RoundedCorner(radius: 16, corners: [.bottomLeft, .bottomRight]))
            } else {
                // thin spacer so the card doesn't look clipped
                Color.clear
                    .frame(height: 0)
            }
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
    PlansView()
        .modelContainer(for: [Plan.self, TaskWork.self], inMemory: true)
}
