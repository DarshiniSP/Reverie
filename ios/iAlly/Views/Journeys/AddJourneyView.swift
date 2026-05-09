//
//  AddJourneyView.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData

struct AddJourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var vision = ""
    @State private var targetDate: Date?
    @State private var showDatePicker = false
    @State private var lifeDomain: LifeDomain = .personal

    // PAI domain inference
    @State private var suggestedDomain: LifeDomain? = nil
    @State private var inferenceTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("Journey Title") {
                    TextField("What journey are you starting?", text: $title)
                        .onChange(of: title) { _, newValue in
                            scheduleInference(for: newValue)
                        }
                }

                Section("Vision") {
                    TextField("Describe your vision", text: $vision, axis: .vertical)
                        .lineLimit(3...6)
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
                    Text("Choose the area of life this journey focuses on")
                        .font(DSFonts.caption())
                }

                Section("Target Date") {
                    if let date = targetDate {
                        HStack {
                            Text(date.formatted(date: .long, time: .omitted))
                            Spacer()
                            Button {
                                targetDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DSColors.textSecondary)
                            }
                        }
                    } else {
                        Button("Set target date") {
                            showDatePicker = true
                        }
                    }
                }
            }
            .navigationTitle("New Journey")
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
                        saveJourney()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("Target Date", selection: Binding(
                        get: { targetDate ?? Date().addingTimeInterval(86400 * 365) },
                        set: { targetDate = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - PAI Inference

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

    // MARK: - Save

    private func saveJourney() {
        let journey = Journey(
            title: title,
            vision: vision.isEmpty ? nil : vision,
            targetDate: targetDate,
            colorHex: lifeDomain.defaultColor,
            icon: lifeDomain.icon,
            lifeDomain: lifeDomain
        )
        modelContext.insert(journey)

        // Auto-create first milestone
        let firstMilestone = Milestone(title: "Milestone 1", order: 1)
        firstMilestone.journey = journey
        modelContext.insert(firstMilestone)

        try? modelContext.save()
        dismiss()
    }
}
