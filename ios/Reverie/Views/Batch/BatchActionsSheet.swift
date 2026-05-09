//
//  BatchActionsSheet.swift
//  iAlly
//
//  Created by Irigam Developer on 12/12/25.
//

import SwiftUI
import SwiftData

struct BatchActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selectedTasks: [TaskWork]
    let modelContext: ModelContext
    let onComplete: () -> Void
    
    @Query private var tags: [Tag]
    @Query private var plans: [Plan]
    
    @State private var showEnergyPicker = false
    @State private var selectedEnergy: TaskEnergy = .medium
    @State private var showSizePicker = false
    @State private var selectedSize: TaskSize = .medium
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var showTagPicker = false
    @State private var showPlanPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(selectedTasks.count) tasks selected")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                }
                
                Section("Complete") {
                    Button {
                        showEnergyPicker = true
                    } label: {
                        Label("Complete Tasks", systemImage: "checkmark.circle.fill")
                            .foregroundColor(DSColors.success)
                    }
                }
                
                Section("Organize") {
                    Button {
                        showDatePicker = true
                    } label: {
                        Label("Set Due Date", systemImage: "calendar")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    
                    Button {
                        showTagPicker = true
                    } label: {
                        Label("Add Tags", systemImage: "tag.fill")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    
                    Button {
                        showPlanPicker = true
                    } label: {
                        Label("Assign to Plan", systemImage: "folder.fill")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                    
                    Button {
                        showSizePicker = true
                    } label: {
                        Label("Change Size", systemImage: "square.stack")
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
                
                Section("Actions") {
                    Button {
                        clearDueDates()
                    } label: {
                        Label("Clear Due Dates", systemImage: "calendar.badge.minus")
                            .foregroundColor(DSColors.warning)
                    }
                    
                    Button(role: .destructive) {
                        deleteTasks()
                    } label: {
                        Label("Delete Tasks", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Batch Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEnergyPicker) {
                EnergyPickerView(selectedEnergy: $selectedEnergy) {
                    completeTasks(with: selectedEnergy)
                }
            }
            .sheet(isPresented: $showSizePicker) {
                SizePickerView(selectedSize: $selectedSize) {
                    changeSize(to: selectedSize)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerView(selectedDate: $selectedDate) {
                    setDueDate(to: selectedDate)
                }
            }
            .sheet(isPresented: $showTagPicker) {
                TagPickerView(tags: tags) { selectedTags in
                    addTags(selectedTags)
                }
            }
            .sheet(isPresented: $showPlanPicker) {
                PlanPickerView(plans: plans) { selectedPlan in
                    assignToPlan(selectedPlan)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func completeTasks(with energy: TaskEnergy) {
        BatchOperationService.shared.completeTasks(selectedTasks, energy: energy, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func changeSize(to size: TaskSize) {
        BatchOperationService.shared.changeSize(of: selectedTasks, to: size, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func setDueDate(to date: Date) {
        BatchOperationService.shared.rescheduleTasks(selectedTasks, to: date, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func addTags(_ tags: [Tag]) {
        BatchOperationService.shared.addTags(tags, to: selectedTasks, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func assignToPlan(_ plan: Plan) {
        BatchOperationService.shared.moveTasks(selectedTasks, to: plan, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func clearDueDates() {
        BatchOperationService.shared.clearDueDates(from: selectedTasks, context: modelContext)
        onComplete()
        dismiss()
    }
    
    private func deleteTasks() {
        BatchOperationService.shared.deleteTasks(selectedTasks, context: modelContext)
        onComplete()
        dismiss()
    }
}

// MARK: - Picker Views

struct EnergyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEnergy: TaskEnergy
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TaskEnergy.allCases, id: \.self) { energy in
                    Button {
                        selectedEnergy = energy
                    } label: {
                        HStack {
                            Image(systemName: energy.icon)
                                .foregroundColor(DSColors.accentPrimary)
                            Text(energy.rawValue)
                                .foregroundColor(DSColors.textPrimary)
                            Spacer()
                            if selectedEnergy == energy {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Energy Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SizePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSize: TaskSize
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TaskSize.allCases, id: \.self) { size in
                    Button {
                        selectedSize = size
                    } label: {
                        HStack {
                            Image(systemName: size.icon)
                            VStack(alignment: .leading) {
                                Text(size.rawValue)
                                    .foregroundColor(DSColors.textPrimary)
                                Text(size.timeDescription)
                                    .font(DSFonts.caption())
                                    .foregroundColor(DSColors.textSecondary)
                            }
                            Spacer()
                            if selectedSize == size {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Task Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            DatePicker("Due Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Spacer()
            
            .navigationTitle("Set Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let tags: [Tag]
    let onSave: ([Tag]) -> Void
    
    @State private var selectedTags: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tags) { tag in
                    Button {
                        if selectedTags.contains(tag.id) {
                            selectedTags.remove(tag.id)
                        } else {
                            selectedTags.insert(tag.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: tag.icon)
                                .foregroundColor(Color(hex: tag.colorHex))
                            Text(tag.name)
                                .foregroundColor(DSColors.textPrimary)
                            Spacer()
                            if selectedTags.contains(tag.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let selected = tags.filter { selectedTags.contains($0.id) }
                        onSave(selected)
                        dismiss()
                    }
                    .disabled(selectedTags.isEmpty)
                }
            }
        }
    }
}

struct PlanPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let plans: [Plan]
    let onSave: (Plan) -> Void
    
    @State private var selectedPlan: Plan?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(plans) { plan in
                    Button {
                        selectedPlan = plan
                    } label: {
                        HStack {
                            Image(systemName: plan.lifeDomain.icon)
                                .foregroundColor(Color(hex: plan.colorHex))
                            Text(plan.lifeDomain.rawValue)
                                .foregroundColor(DSColors.textPrimary)
                            Spacer()
                            if selectedPlan?.id == plan.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let plan = selectedPlan {
                            onSave(plan)
                        }
                        dismiss()
                    }
                    .disabled(selectedPlan == nil)
                }
            }
        }
    }
}

#Preview {
    BatchActionsSheet(
        selectedTasks: [],
        modelContext: ModelContext(try! ModelContainer(for: TaskWork.self)),
        onComplete: {}
    )
}
