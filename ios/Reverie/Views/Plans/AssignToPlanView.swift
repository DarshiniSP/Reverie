//
//  AssignToPlanView.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import SwiftUI
import SwiftData

struct AssignToPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let task: TaskWork
    let plans: [Plan]
    
    @State private var selectedPlan: Plan?
    @State private var searchText = ""
    
    private var filteredPlans: [Plan] {
        let activePlans = plans.filter { !$0.isDeleted }
        if searchText.isEmpty {
            return activePlans
        }
        return activePlans.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var groupedPlans: [LifeDomain: [Plan]] {
        Dictionary(grouping: filteredPlans) { $0.lifeDomain }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assign to Plan")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text(task.title)
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                }
                .padding()
                
                if plans.isEmpty {
                    emptyState
                } else {
                    planList
                }
            }
            .background(DSColors.canvasPrimary)
            .navigationTitle("Select Plan")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search plans...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        assignToPlan()
                    }
                    .disabled(selectedPlan == nil)
                    .bold()
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))
            
            Text("No Plans Yet")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            Text("Create a plan first to organize your tasks")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var planList: some View {
        List {
            ForEach(Array(LifeDomain.allCases), id: \.self) { domain in
                if let domainPlans = groupedPlans[domain], !domainPlans.isEmpty {
                    Section {
                        ForEach(domainPlans) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.name)
                                            .foregroundColor(DSColors.textPrimary)
                                            .font(DSFonts.body())
                                        
                                        if let goal = plan.goal {
                                            Text(goal)
                                                .font(DSFonts.caption())
                                                .foregroundColor(DSColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedPlan?.id == plan.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(DSColors.accentPrimary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Label(domain.rawValue, systemImage: domain.icon)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.canvasPrimary)
    }
    
    private func assignToPlan() {
        guard let plan = selectedPlan else { return }
        
        task.plan = plan
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Silently fail - error handling can be improved with user feedback
        }
    }
}
