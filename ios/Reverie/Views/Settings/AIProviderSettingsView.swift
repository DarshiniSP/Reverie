// AIProviderSettingsView.swift
// iAlly
//
// Settings screen for selecting and configuring AI inference providers.
// Each provider card shows: selection radio, model label, API key input, Test button.

import SwiftUI

struct AIProviderSettingsView: View {

    @State private var router = LuminaInferenceRouter.shared
    @State private var testResults: [InferenceProviderID: TestResult] = [:]
    @State private var isTesting: [InferenceProviderID: Bool] = [:]
    @State private var apiKeyDrafts: [InferenceProviderID: String] = [:]
    @State private var showKeyFor: InferenceProviderID? = nil

    private struct TestResult: Equatable {
        let success: Bool
        let message: String
    }

    var body: some View {
        List {
            Section {
                Text("Lumina will use the selected provider for all conversations. Your API key is stored securely in the device Keychain and never shared.")
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
            }

            ForEach(InferenceProviderID.allCases, id: \.self) { id in
                providerCard(for: id)
            }

            Section {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(DSColors.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PAIService (Memory)")
                            .font(DSFonts.body())
                        Text("Used for memory search only — not for inference")
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                    }
                }
            } header: {
                Text("Memory Layer")
                    .font(DSFonts.label())
                    .textCase(nil)
            } footer: {
                Text("Configure PAIService connection in the PAIService Memory section below.")
                    .font(DSFonts.body(13))
            }
        }
        .navigationTitle("AI Provider")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Pre-populate key drafts with masked indicators
            for id in InferenceProviderID.allCases {
                let key = router.apiKey(for: id)
                apiKeyDrafts[id] = key.isEmpty ? "" : key
            }
        }
    }

    // MARK: - Provider Card

    @ViewBuilder
    private func providerCard(for id: InferenceProviderID) -> some View {
        let isSelected = router.selectedProviderID == id
        let isKeySet = router.isConfigured(id)
        let result = testResults[id]
        let testing = isTesting[id] == true

        Section {
            // Selection row
            Button {
                if isKeySet {
                    router.switchProvider(to: id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? DSColors.accentPrimary : DSColors.textSecondary)
                        .font(DSFonts.headline())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(id.displayName)
                                .font(DSFonts.body())
                                .foregroundColor(DSColors.textPrimary)
                            Text(id.providerLabel)
                                .font(DSFonts.caption(11))
                                .foregroundColor(DSColors.textSecondary)
                        }
                        Text(id.modelLabel)
                            .font(DSFonts.caption(12))
                            .foregroundColor(DSColors.textSecondary)
                    }

                    Spacer()

                    if isSelected {
                        Text("Active")
                            .font(DSFonts.caption(11))
                            .fontWeight(.semibold)
                            .foregroundColor(DSColors.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DSColors.accentPrimary)
                            .cornerRadius(UIConstants.CornerRadius.small)
                    } else if !isKeySet {
                        Text("No key")
                            .font(DSFonts.caption(11))
                            .foregroundColor(DSColors.warning)
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(isKeySet || isSelected ? 1.0 : 0.6)

            // API Key row
            HStack(spacing: 8) {
                Group {
                    if showKeyFor == id {
                        TextField("API Key", text: apiKeyBinding(for: id))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Enter API key…", text: apiKeyBinding(for: id))
                    }
                }
                .font(.system(size: 13, design: .monospaced))
                .onSubmit { saveKey(for: id) }

                // Show/hide toggle
                Button {
                    showKeyFor = showKeyFor == id ? nil : id
                } label: {
                    Image(systemName: showKeyFor == id ? "eye.slash" : "eye")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
                .buttonStyle(.plain)

                // Test button
                Button {
                    saveKey(for: id)
                    runTest(for: id)
                } label: {
                    if testing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Test")
                            .font(DSFonts.caption(12))
                            .fontWeight(.medium)
                            .foregroundColor(DSColors.accentPrimary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(testing || (apiKeyDrafts[id] ?? "").isEmpty)
            }

            // Test result
            if let result {
                HStack(spacing: 4) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(DSFonts.caption())
                        .foregroundColor(result.success ? .green : .red)
                    Text(result.message)
                        .font(DSFonts.caption(12))
                        .foregroundColor(result.success ? .green : .red)
                        .lineLimit(2)
                }
            }
        } header: {
            Text("\(id.displayName) · \(id.modelLabel)")
                .font(DSFonts.label())
                .textCase(nil)
        }
    }

    // MARK: - Helpers

    private func apiKeyBinding(for id: InferenceProviderID) -> Binding<String> {
        Binding(
            get: { apiKeyDrafts[id] ?? "" },
            set: { apiKeyDrafts[id] = $0 }
        )
    }

    private func saveKey(for id: InferenceProviderID) {
        let key = (apiKeyDrafts[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        router.setAPIKey(key, for: id)
    }

    private func runTest(for id: InferenceProviderID) {
        isTesting[id] = true
        testResults[id] = nil
        Task {
            let provider: any LuminaInferenceProvider
            switch id {
            case .anthropic: provider = router.claude
            case .openai:    provider = router.openai
            case .gemini:    provider = router.gemini
            case .mercury:   provider = router.mercury
            }
            let result = await provider.testConnection()
            await MainActor.run {
                isTesting[id] = false
                switch result {
                case .success(let msg):
                    testResults[id] = TestResult(success: true, message: msg)
                case .failure(let err):
                    testResults[id] = TestResult(success: false, message: err.localizedDescription)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AIProviderSettingsView()
    }
}
