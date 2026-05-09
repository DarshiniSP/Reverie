//
//  AddPlanView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct AddPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var lifeDomain = LifeDomain.personal
    @State private var goal = ""

    // PAI domain inference
    @State private var suggestedDomain: LifeDomain? = nil
    @State private var inferenceTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter plan name", text: $name)
                        .onChange(of: name) { _, newValue in
                            scheduleInference(for: newValue)
                        }
                } header: {
                    Text("Plan Name")
                } footer: {
                    Text("Give your plan a clear, descriptive name")
                        .font(DSFonts.caption())
                }

                Section {
                    Picker("Domain", selection: $lifeDomain) {
                        ForEach(LifeDomain.allCases, id: \.self) { domain in
                            Label(domain.rawValue, systemImage: domain.icon)
                                .tag(domain)
                        }
                    }
                    // Lumina domain suggestion
                    if let suggestion = suggestedDomain, suggestion != lifeDomain {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.accentPrimary)
                            Text("Lumina suggests: \(suggestion.rawValue)")
                                .font(DSFonts.body(13))
                                .foregroundColor(DSColors.textSecondary)
                            Spacer()
                            Button("Apply") {
                                withAnimation { lifeDomain = suggestion; suggestedDomain = nil }
                            }
                            .font(DSFonts.caption().weight(.semibold))
                            .foregroundColor(DSColors.accentPrimary)
                        }
                        .transition(.opacity)
                    }
                } header: {
                    Text("Life Domain")
                } footer: {
                    Text("Choose the area of life this plan focuses on")
                        .font(DSFonts.caption())
                }
                
                Section {
                    TextField("Describe what you want to achieve...", text: $goal, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description (Optional)")
                } footer: {
                    Text("Add context about what this plan is for and what success looks like")
                        .font(DSFonts.caption())
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePlan()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func scheduleInference(for text: String) {
        inferenceTask?.cancel()
        guard text.count > 5 else { suggestedDomain = nil; return }
        inferenceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 600ms debounce
            guard !Task.isCancelled else { return }
            if let domain = await LifeDomain.infer(from: text) {
                await MainActor.run {
                    withAnimation { suggestedDomain = domain }
                }
            }
        }
    }

    private func savePlan() {
        let plan = Plan(
            name: name,
            lifeDomain: lifeDomain,
            icon: lifeDomain.icon,
            colorHex: lifeDomain.defaultColor,
            goal: goal.isEmpty ? nil : goal,
            targetMetric: nil,
            status: .active
        )
        modelContext.insert(plan)
        try? modelContext.save()
        dismiss()
    }
}
