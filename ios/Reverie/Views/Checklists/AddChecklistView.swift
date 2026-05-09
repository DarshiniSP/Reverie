//
//  AddChecklistView.swift
//  iAlly
//
//  Create a new standalone checklist with title, icon, color, and optional template.
//

import SwiftUI
import SwiftData

struct AddChecklistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var selectedIcon = "checklist"
    @State private var selectedColorHex = "#4C8BF5"
    @State private var isRecurring = false
    @State private var showTemplatePicker = false
    @State private var initialItems: [ChecklistItem] = []

    private let iconOptions = [
        "checklist", "cart.fill", "airplane", "book.fill",
        "creditcard.fill", "house.fill", "heart.fill", "briefcase.fill",
        "fork.knife", "wrench.and.screwdriver.fill", "gift.fill", "graduationcap.fill",
        "figure.run", "car.fill", "stethoscope", "leaf.fill"
    ]

    private let colorOptions = [
        "#4C8BF5", "#34C759", "#FF9500", "#FF3B30",
        "#AF52DE", "#5856D6", "#FF2D55", "#00C7BE",
        "#007AFF", "#FFD60A", "#8E8E93", "#30B0C7"
    ]

    // Quick-start templates
    private let quickTemplates: [(name: String, icon: String, color: String, items: [String])] = [
        (
            name: "Grocery List",
            icon: "cart.fill",
            color: "#34C759",
            items: ["Fruits & Vegetables", "Dairy & Eggs", "Bread & Bakery", "Meat & Seafood", "Snacks", "Beverages", "Household Items"]
        ),
        (
            name: "Travel Packing",
            icon: "airplane",
            color: "#007AFF",
            items: ["Passport & Documents", "Clothes", "Toiletries", "Chargers & Electronics", "Medications", "Snacks", "Travel Pillow"]
        ),
        (
            name: "Exam Prep",
            icon: "graduationcap.fill",
            color: "#AF52DE",
            items: ["Review Lecture Notes", "Practice Problems", "Study Group Session", "Review Past Papers", "Prepare Summary Sheet", "Get Good Sleep"]
        ),
        (
            name: "Monthly Bills",
            icon: "creditcard.fill",
            color: "#FF9500",
            items: ["Rent/Mortgage", "Electricity", "Water", "Internet", "Phone", "Insurance", "Subscriptions"]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Title")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        TextField("e.g. Weekly Groceries", text: $title)
                            .font(DSFonts.body())
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .accessibilityIdentifier("checklistTitleField")
                    }

                    // Quick-start Templates
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Start")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickTemplates, id: \.name) { template in
                                    Button {
                                        applyQuickTemplate(template)
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: template.icon)
                                                .font(.system(size: 24))
                                                .foregroundColor(Color(hex: template.color))
                                                .frame(width: 48, height: 48)
                                                .background(Color(hex: template.color).opacity(0.12))
                                                .cornerRadius(UIConstants.CornerRadius.standard)

                                            Text(template.name)
                                                .font(DSFonts.caption())
                                                .foregroundColor(DSColors.textPrimary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 80)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? DSColors.onAccent : DSColors.textPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color(hex: selectedColorHex) : DSColors.canvasSecondary)
                                        .cornerRadius(UIConstants.CornerRadius.standard)
                                }
                            }
                        }
                    }

                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(DSFonts.label())
                            .foregroundColor(DSColors.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(colorOptions, id: \.self) { colorHex in
                                Button {
                                    selectedColorHex = colorHex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(DSColors.textPrimary, lineWidth: selectedColorHex == colorHex ? 3 : 0)
                                        )
                                }
                            }
                        }
                    }

                    // Recurring toggle
                    Toggle(isOn: $isRecurring) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recurring Checklist")
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            Text("Can be reset and reused periodically")
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.textSecondary)
                        }
                    }
                    .tint(DSColors.accentPrimary)

                    // Pre-loaded items preview
                    if !initialItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Items (\(initialItems.count))")
                                    .font(DSFonts.label())
                                    .foregroundColor(DSColors.textSecondary)
                                Spacer()
                                Button("Clear") {
                                    initialItems = []
                                }
                                .font(DSFonts.caption())
                                .foregroundColor(DSColors.error)
                            }

                            VStack(spacing: 4) {
                                ForEach(initialItems) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(DSColors.textSecondary)
                                        Text(item.title)
                                            .font(DSFonts.body())
                                            .foregroundColor(DSColors.textPrimary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(12)
                            .background(DSColors.canvasSecondary)
                            .cornerRadius(UIConstants.CornerRadius.standard)
                        }
                    }

                    // Use Template button
                    Button {
                        showTemplatePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Use Saved Template")
                        }
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.accentSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.standard)
                    }
                }
                .padding()
            }
            .background(DSColors.canvasPrimary.ignoresSafeArea())
            .navigationTitle("New Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChecklist()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("saveChecklistButton")
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                ChecklistTemplatePickerView { templateItems in
                    applyTemplateItems(templateItems)
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Actions

    private func applyQuickTemplate(_ template: (name: String, icon: String, color: String, items: [String])) {
        title = template.name
        selectedIcon = template.icon
        selectedColorHex = template.color
        isRecurring = true
        initialItems = template.items.enumerated().map { index, itemTitle in
            ChecklistItem(title: itemTitle, order: index)
        }
    }

    private func applyTemplateItems(_ templateItems: [String]) {
        let startOrder = initialItems.count
        for (i, itemTitle) in templateItems.enumerated() {
            initialItems.append(ChecklistItem(title: itemTitle, order: startOrder + i))
        }
    }

    private func saveChecklist() {
        let checklist = Checklist(
            title: title.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorHex: selectedColorHex,
            items: initialItems,
            isRecurring: isRecurring
        )
        modelContext.insert(checklist)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddChecklistView()
        .modelContainer(for: [Checklist.self, ChecklistTemplate.self], inMemory: true)
}
