//
//  AssignToJourneyView.swift
//  iAlly
//
//  Created by Irigam Developer on 9/12/25.
//

import SwiftUI
import SwiftData

struct AssignToJourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let task: TaskWork
    let journeys: [Journey]
    
    @State private var selectedJourney: Journey?
    @State private var selectedMilestone: Milestone?
    @State private var searchText = ""
    
    private var filteredJourneys: [Journey] {
        if searchText.isEmpty {
            return journeys
        }
        return journeys.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Link to Journey")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text(task.title)
                        .font(DSFonts.label())
                        .foregroundColor(DSColors.textPrimary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                }
                .padding()
                
                if journeys.isEmpty {
                    emptyState
                } else {
                    journeyList
                }
            }
            .background(DSColors.canvasPrimary)
            .navigationTitle("Select Journey")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search journeys...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") {
                        linkToJourney()
                    }
                    .disabled(selectedJourney == nil)
                    .bold()
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag")
                .font(.system(size: 64))
                .foregroundColor(DSColors.textSecondary.opacity(0.5))
            
            Text("No Journeys Yet")
                .font(DSFonts.headline())
                .foregroundColor(DSColors.textPrimary)
            
            Text("Create a journey first to link your tasks")
                .font(DSFonts.label())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxHeight: .infinity)
    }
    
    private var journeyList: some View {
        List {
            ForEach(filteredJourneys) { journey in
                Section {
                    // Journey header row
                    Button {
                        if selectedJourney?.id == journey.id && selectedMilestone == nil {
                            selectedJourney = nil
                        } else {
                            selectedJourney = journey
                            selectedMilestone = nil
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(journey.title)
                                    .foregroundColor(DSColors.textPrimary)
                                    .font(DSFonts.body())
                                    .bold()
                                
                                if let vision = journey.vision {
                                    Text(vision)
                                        .font(DSFonts.caption())
                                        .foregroundColor(DSColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if selectedJourney?.id == journey.id && selectedMilestone == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DSColors.accentPrimary)
                            }
                        }
                    }
                    
                    // Milestones (if any)
                    if let milestones = journey.milestones, !milestones.isEmpty {
                        ForEach(milestones) { milestone in
                            Button {
                                selectedJourney = journey
                                selectedMilestone = milestone
                            } label: {
                                HStack {
                                    Image(systemName: "signpost.right")
                                        .font(DSFonts.caption())
                                        .foregroundColor(DSColors.textSecondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(milestone.title)
                                            .foregroundColor(DSColors.textPrimary)
                                            .font(DSFonts.label())
                                        
                                        if milestone.isCompleted {
                                            Text("Completed")
                                                .font(DSFonts.caption())
                                                .foregroundColor(DSColors.success)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedJourney?.id == journey.id && selectedMilestone?.id == milestone.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(DSColors.accentPrimary)
                                    }
                                }
                                .padding(.leading, 12)
                            }
                        }
                    }
                } header: {
                    if journey.milestones?.isEmpty == false {
                        Text("Tap journey or specific milestone")
                            .font(DSFonts.caption())
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.canvasPrimary)
    }
    
    private func linkToJourney() {
        guard let journey = selectedJourney else { return }
        
        task.journey = journey
        task.milestone = selectedMilestone
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Silently fail - error handling can be improved with user feedback
        }
    }
}
