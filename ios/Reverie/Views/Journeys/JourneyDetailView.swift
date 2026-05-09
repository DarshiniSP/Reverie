//
//  JourneyDetailView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct JourneyDetailView: View {
    @Bindable var journey: Journey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationManager = NotificationManager.shared
    
    @State private var showAddMilestone = false
    @State private var newMilestoneTitle = ""
    @State private var showDeleteAlert = false
    @State private var showAddTask = false
    // Phase 3: PAI Journey Narrative
    @State private var showNarrative = false
    
    private var sortedMilestones: [Milestone] {
        journey.milestones?.sorted(by: {
            switch ($0.targetDate, $1.targetDate) {
            case let (a?, b?): return a < b         // both dated: sort ascending
            case (_?, nil):    return true           // dated before undated
            case (nil, _?):    return false          // undated after dated
            default:           return $0.order < $1.order  // both undated: fall back to insertion order
            }
        }) ?? []
    }
    
    private var journeyTasks: [TaskWork] {
        journey.tasks ?? []
    }
    
    private var unassignedTasks: [TaskWork] {
        journeyTasks.filter { $0.milestone == nil }
    }
    
    var body: some View {
        ZStack {
            DSColors.canvasPrimary
                .ignoresSafeArea()
            
            // Phase 1: Removed expense tab, showing overview only
            overviewScrollView
        }
        .navigationTitle(journey.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Phase 3: PAI Journey Narrative
                    Button {
                        showNarrative = true
                    } label: {
                        Label("Lumina Narrative", systemImage: "brain.head.profile")
                            .labelStyle(.iconOnly)
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DSColors.error)
                    }
                }
            }
        }
        .sheet(isPresented: $showNarrative) {
            JourneyNarrativeView(journey: journey)
        }
        .alert("Delete Journey", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                try? AttachmentService.shared.deleteAllAttachments(for: journey.id, context: modelContext)
                modelContext.delete(journey)
                try? modelContext.save()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this journey? All milestones will be deleted.")
        }
        .alert("New Milestone", isPresented: $showAddMilestone) {
            TextField("Milestone title", text: $newMilestoneTitle)
            Button("Cancel", role: .cancel) {
                newMilestoneTitle = ""
            }
            Button("Add") {
                addMilestone()
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(preselectedJourney: journey)
                .environment(\.modelContext, modelContext)
        }
    }
    
    // MARK: - Overview Content
    
    private var overviewScrollView: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: journey.icon)
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: journey.colorHex))
                            
                            Spacer()
                        }
                        
                        TextField("Journey title", text: $journey.title)
                            .font(DSFonts.title())
                            .foregroundColor(DSColors.textPrimary)
                            .textFieldStyle(.plain)
                        
                        TextField("Describe your vision", text: Binding(
                            get: { journey.vision ?? "" },
                            set: { journey.vision = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.textSecondary)
                            .textFieldStyle(.plain)
                            .lineLimit(2...4)
                        
                        // Target Date Editor
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundColor(DSColors.textSecondary)
                            
                            if let targetDate = journey.targetDate {
                                DatePicker(
                                    "Target",
                                    selection: Binding(
                                        get: { targetDate },
                                        set: { journey.targetDate = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                
                                Button {
                                    journey.targetDate = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(DSColors.textSecondary)
                                }
                            } else {
                                Button("Set target date") {
                                    journey.targetDate = Date()
                                }
                                .font(DSFonts.body(15))
                                .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                    .padding()
                    
                    // Journey Timeline
                    if !sortedMilestones.isEmpty {
                        JourneyTimelineView(journey: journey, milestones: sortedMilestones)
                            .padding(.horizontal)
                    }
                    
                    // Progress
                    if !sortedMilestones.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            
                            let completed = sortedMilestones.filter({ $0.isCompleted }).count
                            let total = sortedMilestones.count
                            let progress = Double(completed) / Double(total)
                            
                            HStack {
                                ProgressView(value: progress)
                                    .tint(Color(hex: journey.colorHex))
                                
                                Text("\(completed)/\(total)")
                                    .font(DSFonts.body(15))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Milestones with Tasks
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Milestones & Tasks")
                                .font(DSFonts.label())
                                .foregroundColor(DSColors.textSecondary)
                            
                            Spacer()
                            
                            Button {
                                showAddMilestone = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                        .padding(.horizontal)
                        
                        if sortedMilestones.isEmpty {
                            Text("No milestones yet")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(sortedMilestones) { milestone in
                                MilestoneWithTasksView(
                                    milestone: milestone,
                                    journey: journey,
                                    tasks: journeyTasks.filter { $0.milestone?.id == milestone.id }
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Unassigned Tasks
                    if !unassignedTasks.isEmpty {
                        unassignedTasksSection
                    }
                    
                    // Attachments
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attachments")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)
                            .padding(.horizontal)
                        
                        AttachmentsView(itemId: journey.id, itemType: .journey)
                    }
                }
            }
        }
    
    private var unassignedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unassigned Tasks")
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
            
            ForEach(unassignedTasks) { task in
                NavigationLink(destination: TaskDetailView(task: task)) {
                    TaskRowView(task: task)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func addMilestone() {
        let milestone = Milestone(
            title: newMilestoneTitle,
            order: sortedMilestones.count
        )
        milestone.journey = journey
        modelContext.insert(milestone)
        try? modelContext.save()
        
        // Schedule notification if milestone has target date
        if let targetDate = milestone.targetDate {
            _Concurrency.Task {
                await notificationManager.scheduleMilestoneReminder(
                    milestoneId: milestone.id.uuidString,
                    milestoneTitle: newMilestoneTitle,
                    targetDate: targetDate,
                    journeyTitle: journey.title
                )
            }
        }
        
        newMilestoneTitle = ""
    }
}

// Integrated Milestone Card with Tasks
struct MilestoneWithTasksView: View {
    @Bindable var milestone: Milestone
    let journey: Journey
    let tasks: [TaskWork]
    @Environment(\.modelContext) private var modelContext

    @State private var isExpanded: Bool = true
    @State private var showAddMilestoneTask = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Milestone Header Card
            Card {
                HStack(spacing: 12) {
                    // Completion toggle — standalone, no navigation
                    Button { toggleComplete() } label: {
                        Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(DSFonts.headline())
                            .foregroundColor(milestone.isCompleted
                                ? Color(hex: journey.colorHex)
                                : DSColors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    // Title + metadata → navigates to MilestoneDetailView
                    NavigationLink(destination: MilestoneDetailView(milestone: milestone, journey: journey)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(milestone.title.isEmpty ? "Untitled Milestone" : milestone.title)
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                                .strikethrough(milestone.isCompleted)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 10) {
                                if let targetDate = milestone.targetDate {
                                    Label(
                                        targetDate.formatted(date: .abbreviated, time: .omitted),
                                        systemImage: "calendar"
                                    )
                                    .font(DSFonts.body(12))
                                    .foregroundColor(milestone.isOverdue ? .red : DSColors.textSecondary)
                                } else {
                                    Label("No date", systemImage: "calendar.badge.plus")
                                        .font(DSFonts.body(12))
                                        .foregroundColor(DSColors.textSecondary.opacity(0.6))
                                }

                                if !tasks.isEmpty {
                                    let completed = tasks.filter { $0.isCompleted }.count
                                    Label("\(completed)/\(tasks.count)", systemImage: "checkmark.square")
                                        .font(DSFonts.body(12))
                                        .foregroundColor(DSColors.textSecondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    // Expand/collapse inline tasks
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
            }

            // Inline task list (collapsible preview)
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(tasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                    }

                    // Add Task button always visible when expanded
                    Button {
                        showAddMilestoneTask = true
                    } label: {
                        Label("Add Task", systemImage: "plus.circle")
                            .font(DSFonts.body(13))
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .padding(.top, 6)
            }
        }
        .sheet(isPresented: $showAddMilestoneTask) {
            AddTaskView(preselectedJourney: journey, preselectedMilestone: milestone)
                .environment(\.modelContext, modelContext)
        }
    }

    private func toggleComplete() {
        withAnimation {
            if milestone.isCompleted {
                milestone.completedAt = nil
                // If uncompleting, revert journey to inProgress if it was completed
                if journey.status == .completed {
                    journey.status = .inProgress
                }
            } else {
                if milestone.canBeCompleted {
                    milestone.completedAt = Date()
                    // Transition journey from notStarted → inProgress on first activity
                    if journey.status == .notStarted || journey.status == nil {
                        journey.status = .inProgress
                    }
                    // Auto-complete journey if all milestones are now done
                    if let milestones = journey.milestones, milestones.allSatisfy({ $0.isCompleted || $0.id == milestone.id }) {
                        journey.status = .completed
                    }
                    PAIMemoryBridge.shared.recordMilestoneCompleted(milestone: milestone, journey: journey)
                    WidgetHelper.shared.reloadAllWidgets()
                }
            }
            try? modelContext.save()
        }
    }
}

struct MilestoneRowView: View {
    @Bindable var milestone: Milestone
    let journey: Journey
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Card {
            HStack(spacing: 12) {
                Button {
                    toggleComplete()
                } label: {
                    Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(DSFonts.headline())
                        .foregroundColor(milestone.isCompleted ? Color(hex: journey.colorHex) : DSColors.textSecondary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                        .strikethrough(milestone.isCompleted)
                    
                    if let targetDate = milestone.targetDate {
                        Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(4)
        }
    }
    
    private func toggleComplete() {
        withAnimation {
            if milestone.isCompleted {
                // Allow uncompleting
                milestone.completedAt = nil
                // If uncompleting, revert journey to inProgress if it was completed
                if journey.status == .completed {
                    journey.status = .inProgress
                }
            } else {
                // Only allow completing if all tasks are done
                if milestone.canBeCompleted {
                    milestone.completedAt = Date()
                    // Transition journey from notStarted → inProgress on first activity
                    if journey.status == .notStarted || journey.status == nil {
                        journey.status = .inProgress
                    }
                    // Auto-complete journey if all milestones are now done
                    if let milestones = journey.milestones, milestones.allSatisfy({ $0.isCompleted || $0.id == milestone.id }) {
                        journey.status = .completed
                    }

                    // Record to PAI episodic memory so Lumina learns about journey progress.
                    PAIMemoryBridge.shared.recordMilestoneCompleted(milestone: milestone, journey: journey)

                    // Refresh widgets to reflect journey progress.
                    WidgetHelper.shared.reloadAllWidgets()
                }
            }
            try? modelContext.save()
        }
    }
}

// Journey Timeline Visualization
struct JourneyTimelineView: View {
    let journey: Journey
    let milestones: [Milestone]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                        // Milestone Node
                        VStack(spacing: 8) {
                            // Date label above
                            if let targetDate = milestone.targetDate {
                                Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 10))
                                    .foregroundColor(DSColors.textSecondary)
                            } else {
                                Text("No date")
                                    .font(.system(size: 10))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            
                            // Node circle
                            ZStack {
                                Circle()
                                    .fill(milestone.isCompleted ? Color(hex: journey.colorHex) : DSColors.canvasSecondary)
                                    .frame(width: 24, height: 24)
                                
                                if milestone.isCompleted {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(DSColors.onAccent)
                                } else {
                                    Circle()
                                        .stroke(Color(hex: journey.colorHex), lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                }
                            }
                            
                            // Milestone title below
                            Text(milestone.title)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(DSColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                                .lineLimit(2)
                        }
                        .frame(width: 100)
                        
                        // Connecting line (except for last milestone)
                        if index < milestones.count - 1 {
                            Rectangle()
                                .fill(milestone.isCompleted && milestones[index + 1].isCompleted 
                                      ? Color(hex: journey.colorHex) 
                                      : DSColors.textSecondary.opacity(0.3))
                                .frame(width: 40, height: 2)
                                .padding(.bottom, 50)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.large)
    }
}
