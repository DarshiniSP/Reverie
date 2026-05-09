// LuminaInferenceRouter.swift
// iAlly
//
// Routes Lumina inference to the user-selected provider.
// Selected provider persisted in UserDefaults.
// All inference goes directly from device to cloud — no PAIService dependency.

import Foundation
import Observation

@Observable
@MainActor
final class LuminaInferenceRouter {

    static let shared = LuminaInferenceRouter()

    private enum Keys {
        static let selectedProvider = "lumina.selectedProvider"
    }

    // MARK: - State

    /// Currently selected provider ID (persisted).
    var selectedProviderID: InferenceProviderID {
        didSet {
            UserDefaults.standard.set(selectedProviderID.rawValue, forKey: Keys.selectedProvider)
        }
    }

    /// All instantiated providers keyed by ID.
    let claude   = ClaudeInferenceClient()
    let openai   = OpenAIInferenceClient(providerID: .openai, baseURL: "https://api.openai.com/v1")
    let gemini   = GeminiInferenceClient()
    let mercury  = MercuryInferenceClient()

    var activeProvider: any LuminaInferenceProvider {
        switch selectedProviderID {
        case .anthropic: return claude
        case .openai:    return openai
        case .gemini:    return gemini
        case .mercury:   return mercury
        }
    }

    /// Returns all providers in display order.
    var allProviders: [any LuminaInferenceProvider] {
        [claude, openai, gemini, mercury]
    }

    // MARK: - Init

    private init() {
        let stored = UserDefaults.standard.string(forKey: Keys.selectedProvider) ?? ""
        selectedProviderID = InferenceProviderID(rawValue: stored) ?? .anthropic
    }

    // MARK: - Public API

    /// Stream tokens from the active provider.
    func stream(messages: [PAIChatMessage]) -> AsyncThrowingStream<String, Error> {
        activeProvider.stream(messages: messages)
    }

    /// Switch the active provider. No-op if already selected.
    func switchProvider(to id: InferenceProviderID) {
        guard id != selectedProviderID else { return }
        selectedProviderID = id
    }

    /// Convenience: API key for a given provider.
    func apiKey(for id: InferenceProviderID) -> String {
        InferenceKeychain.get(key: id.keychainKey) ?? ""
    }

    func setAPIKey(_ key: String, for id: InferenceProviderID) {
        InferenceKeychain.set(key, key: id.keychainKey)
    }

    func isConfigured(_ id: InferenceProviderID) -> Bool {
        !apiKey(for: id).isEmpty
    }

    /// Whether the currently selected provider has an API key configured.
    var isActiveProviderConfigured: Bool {
        isConfigured(selectedProviderID)
    }

    // MARK: - Non-streaming convenience

    /// Collect the full streamed response into a single string.
    /// Use this where callers previously called `PAIServiceClient.shared.chat()`.
    func generate(messages: [PAIChatMessage]) async throws -> String {
        var result = ""
        for try await chunk in stream(messages: messages) {
            result += chunk
        }
        return result
    }
}
