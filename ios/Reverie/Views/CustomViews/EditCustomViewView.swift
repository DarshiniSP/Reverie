//
//  EditCustomViewView.swift
//  iAlly
//
//  Created on 12/12/2025.
//

import SwiftUI
import SwiftData

struct EditCustomViewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let view: CustomView?
    
    @State private var name: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var filterByCompleted: Bool
    @State private var filterByOverdue: Bool
    @State private var filterBySize: Set<TaskSize>
    @State private var filterByEnergy: Set<TaskEnergy>
    @State private var filterByLifeDomains: Set<LifeDomain>
    @State private var filterByDueDate: DueDateFilter?
    @State private var sortBy: TaskSortOption
    @State private var groupBy: TaskGroupOption?
    @State private var layoutType: ViewLayoutType
    
    init(view: CustomView?) {
        self.view = view
        
        _name = State(initialValue: view?.name ?? "")
        _icon = State(initialValue: view?.icon ?? "list.bullet")
        _colorHex = State(initialValue: view?.colorHex ?? "#007AFF")
        _filterByCompleted = State(initialValue: view?.filterByCompleted ?? false)
        _filterByOverdue = State(initialValue: view?.filterByOverdue ?? false)
        _filterBySize = State(initialValue: Set(view?.filterBySize ?? []))
        _filterByEnergy = State(initialValue: Set(view?.filterByEnergy ?? []))
        _filterByLifeDomains = State(initialValue: Set(view?.filterByLifeDomains ?? []))
        _filterByDueDate = State(initialValue: view?.filterByDueDate)
        _sortBy = State(initialValue: view?.sortBy ?? .dueDate)
        _groupBy = State(initialValue: view?.groupBy)
        _layoutType = State(initialValue: view?.layoutType ?? .list)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("View Name", text: $name)
                    
                    TextField("Icon (SF Symbol)", text: $icon)
                    
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { colorHex = $0.toHex() ?? "#007AFF" }
                    ))
                }
                
                Section("Filters") {
                    Toggle("Show Completed", isOn: $filterByCompleted)
                    Toggle("Overdue Only", isOn: $filterByOverdue)
                    
                    // Life Domains multi-select
                    NavigationLink {
                        LifeDomainSelectorView(selectedDomains: $filterByLifeDomains)
                    } label: {
                        HStack {
                            Text("Life Domains")
                            Spacer()
                            if filterByLifeDomains.isEmpty {
                                Text("All")
                                    .foregroundColor(DSColors.textSecondary)
                            } else {
                                Text("\(filterByLifeDomains.count) selected")
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                    
                    // Size multi-select
                    NavigationLink {
                        SizeSelectorView(selectedSizes: $filterBySize)
                    } label: {
                        HStack {
                            Text("Task Size")
                            Spacer()
                            if filterBySize.isEmpty {
                                Text("All")
                                    .foregroundColor(DSColors.textSecondary)
                            } else {
                                Text(filterBySize.map { $0.rawValue }.joined(separator: ", "))
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                    
                    // Energy multi-select
                    NavigationLink {
                        EnergySelectorView(selectedEnergy: $filterByEnergy)
                    } label: {
                        HStack {
                            Text("Energy Level")
                            Spacer()
                            if filterByEnergy.isEmpty {
                                Text("All")
                                    .foregroundColor(DSColors.textSecondary)
                            } else {
                                Text("\(filterByEnergy.count) selected")
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    }
                    
                    // Due Date picker
                    Picker("Due Date", selection: $filterByDueDate) {
                        Text("Any").tag(DueDateFilter?.none)
                        ForEach(DueDateFilter.allCases, id: \.self) { filter in
                            Text(filter.displayName).tag(Optional(filter))
                        }
                    }
                }
                
                Section("Sort & Group") {
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(TaskSortOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                    
                    Picker("Group By", selection: $groupBy) {
                        Text("None").tag(TaskGroupOption?.none)
                        ForEach(TaskGroupOption.allCases.filter { $0 != .none }, id: \.self) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(Optional(option))
                        }
                    }
                }
                
                Section("Layout") {
                    Picker("Layout Type", selection: $layoutType) {
                        ForEach(ViewLayoutType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(view == nil ? "New View" : "Edit View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveView()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveView() {
        if let existingView = view {
            // Update existing
            existingView.name = name
            existingView.icon = icon
            existingView.colorHex = colorHex
            existingView.filterByCompleted = filterByCompleted
            existingView.filterByOverdue = filterByOverdue
            existingView.filterBySize = Array(filterBySize)
            existingView.filterByEnergy = Array(filterByEnergy)
            existingView.filterByLifeDomains = Array(filterByLifeDomains)
            existingView.filterByDueDate = filterByDueDate
            existingView.sortBy = sortBy
            existingView.groupBy = groupBy
            existingView.layoutType = layoutType
            
            try? CustomViewService.shared.updateView(existingView, context: modelContext)
        } else {
            // Create new
            let newView = CustomView(
                name: name,
                icon: icon,
                colorHex: colorHex,
                isDefault: false,
                filterByCompleted: filterByCompleted,
                filterByOverdue: filterByOverdue,
                filterBySize: Array(filterBySize),
                filterByEnergy: Array(filterByEnergy),
                filterByLifeDomains: Array(filterByLifeDomains),
                filterByDueDate: filterByDueDate,
                sortBy: sortBy,
                groupBy: groupBy,
                layoutType: layoutType
            )
            
            try? CustomViewService.shared.createView(newView, context: modelContext)
        }
        
        dismiss()
    }
}

#Preview {
    EditCustomViewView(view: nil)
        .modelContainer(for: [CustomView.self], inMemory: true)
}

// MARK: - Selector Views

struct LifeDomainSelectorView: View {
    @Binding var selectedDomains: Set<LifeDomain>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(LifeDomain.allCases, id: \.self) { domain in
                Button {
                    if selectedDomains.contains(domain) {
                        selectedDomains.remove(domain)
                    } else {
                        selectedDomains.insert(domain)
                    }
                } label: {
                    HStack {
                        Label(domain.rawValue, systemImage: domain.icon)
                            .foregroundColor(selectedDomains.contains(domain) ? DSColors.accentPrimary : DSColors.textPrimary)
                        Spacer()
                        if selectedDomains.contains(domain) {
                            Image(systemName: "checkmark")
                                .foregroundColor(DSColors.accentPrimary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Life Domains")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All") {
                    selectedDomains.removeAll()
                }
                .disabled(selectedDomains.isEmpty)
            }
        }
    }
}

struct SizeSelectorView: View {
    @Binding var selectedSizes: Set<TaskSize>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(TaskSize.allCases, id: \.self) { size in
                Button {
                    if selectedSizes.contains(size) {
                        selectedSizes.remove(size)
                    } else {
                        selectedSizes.insert(size)
                    }
                } label: {
                    HStack {
                        Label(size.rawValue, systemImage: size.icon)
                            .foregroundColor(selectedSizes.contains(size) ? DSColors.accentPrimary : DSColors.textPrimary)
                        Spacer()
                        if selectedSizes.contains(size) {
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All") {
                    selectedSizes.removeAll()
                }
                .disabled(selectedSizes.isEmpty)
            }
        }
    }
}

struct EnergySelectorView: View {
    @Binding var selectedEnergy: Set<TaskEnergy>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(TaskEnergy.allCases, id: \.self) { energy in
                Button {
                    if selectedEnergy.contains(energy) {
                        selectedEnergy.remove(energy)
                    } else {
                        selectedEnergy.insert(energy)
                    }
                } label: {
                    HStack {
                        Label(energy.rawValue, systemImage: energy.icon)
                            .foregroundColor(selectedEnergy.contains(energy) ? DSColors.accentPrimary : DSColors.textPrimary)
                        Spacer()
                        if selectedEnergy.contains(energy) {
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
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear All") {
                    selectedEnergy.removeAll()
                }
                .disabled(selectedEnergy.isEmpty)
            }
        }
    }
}
