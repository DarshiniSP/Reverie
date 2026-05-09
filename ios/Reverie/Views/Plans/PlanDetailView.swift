//
//  PlanDetailView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct PlanDetailView: View {
    @Bindable var plan: Plan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Journey.createdAt, order: .reverse) private var allJourneys: [Journey]

    @State private var showAddTask = false
    @State private var showDeleteAlert = false

    /// Goals that belong to the same life domain as this Life Area
    private var linkedGoals: [Journey] {
        allJourneys.filter { $0.lifeDomain == plan.lifeDomain }
    }
    
    private var planTasks: [TaskWork] {
        let tasks = plan.tasks ?? []
        return tasks.sorted(by: { !$0.isCompleted && $1.isCompleted })
    }
    
    var body: some View {
        ZStack {
            DSColors.canvasPrimary
                .ignoresSafeArea()
            
            overviewScrollView
        }
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(DSColors.error)
                }
            }
        }
        .alert("Delete Plan", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Move all tasks to inbox before deleting the plan
                for task in plan.tasks ?? [] {
                    task.plan = nil
                    task.isInbox = true
                }
                modelContext.delete(plan)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this plan? All tasks will be moved to inbox.")
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(preselectedPlan: plan)
                .environment(\.modelContext, modelContext)
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewScrollView: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    HStack {
                        Image(systemName: plan.lifeDomain.icon)
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: plan.colorHex))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Plan name", text: $plan.name)
                                .font(DSFonts.title())
                                .foregroundColor(DSColors.textPrimary)
                                .textFieldStyle(.plain)
                            
                            Text(plan.lifeDomain.rawValue)
                                .font(DSFonts.body(15))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Description Section
                    if let goal = plan.goal {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            
                            Text(goal)
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            
                            if let targetMetric = plan.targetMetric {
                                Text("Target: \(targetMetric)")
                                    .font(DSFonts.body(15))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.large)
                        .padding(.horizontal)
                    }
                    
                    // Progress Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Progress")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            
                            Spacer()
                            
                            if let status = plan.status {
                                Label(status.rawValue, systemImage: status.icon)
                                    .font(DSFonts.body(14))
                                    .foregroundColor(Color(hex: status.color))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: status.color).opacity(0.1))
                                    .cornerRadius(UIConstants.CornerRadius.standard)
                            }
                        }
                        
                        // Progress bar
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(Int(plan.completionRate * 100))%")
                                    .font(DSFonts.title(16))
                                    .foregroundColor(DSColors.textPrimary)
                                
                                Spacer()
                                
                                Text("\(plan.completedTaskCount) of \(plan.activeTaskCount + plan.completedTaskCount) tasks")
                                    .font(DSFonts.body(14))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(DSColors.canvasSecondary)
                                        .frame(height: 8)
                                        .cornerRadius(4)
                                    
                                    Rectangle()
                                        .fill(Color(hex: plan.colorHex))
                                        .frame(width: geometry.size.width * plan.completionRate, height: 8)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding()
                    
                    // Stats
                    HStack(spacing: 16) {
                        PlanStatCard(
                            value: "\(plan.activeTaskCount)",
                            label: "Active"
                        )
                        PlanStatCard(
                            value: "\(plan.completedTaskCount)",
                            label: "Completed"
                        )
                        PlanStatCard(
                            value: "\(planTasks.count)",
                            label: "Total"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Linked Goals
                    if !linkedGoals.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(DSColors.accentSecondary)
                                Text("Goals in this Area")
                                    .font(DSFonts.label(14))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            .padding(.horizontal)

                            ForEach(linkedGoals) { goal in
                                NavigationLink(destination: JourneyDetailView(journey: goal)) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(hex: goal.colorHex).opacity(0.12))
                                                .frame(width: 34, height: 34)
                                            Image(systemName: goal.icon)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(hex: goal.colorHex))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(goal.title)
                                                .font(DSFonts.label(14))
                                                .foregroundColor(DSColors.textPrimary)
                                                .lineLimit(1)
                                            if let milestones = goal.milestones, !milestones.isEmpty {
                                                let done = milestones.filter { $0.isCompleted }.count
                                                Text("\(done)/\(milestones.count) milestones")
                                                    .font(DSFonts.caption(11))
                                                    .foregroundColor(DSColors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        // Progress bar
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(DSColors.divider)
                                                .frame(width: 48, height: 5)
                                            Capsule()
                                                .fill(Color(hex: goal.colorHex))
                                                .frame(width: 48 * goal.progress, height: 5)
                                        }
                                    }
                                    .padding(12)
                                    .background(DSColors.canvasSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DSColors.divider, lineWidth: 0.5))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Tasks")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            
                            Spacer()
                            
                            Button {
                                showAddTask = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if planTasks.isEmpty {
                            Text("No tasks yet")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(planTasks) { task in
                                NavigationLink(destination: TaskDetailView(task: task)) {
                                    TaskRowView(task: task)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
}

struct PlanStatCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DSFonts.headline(24))
                .foregroundColor(DSColors.textPrimary)
            
            Text(label)
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}
