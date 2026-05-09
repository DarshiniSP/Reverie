// MercuryInferenceClient.swift
// iAlly
//
// Direct Inception Labs Mercury API calls from iOS.
// POST https://api.inceptionlabs.ai/v1/chat/completions
// OpenAI-compatible format. Auth: Authorization: Bearer {key}

import Foundation

/// Mercury uses the same OpenAI-compatible chat completions protocol.
/// This is a thin wrapper around OpenAIInferenceClient with the Inception Labs base URL.
final class MercuryInferenceClient: LuminaInferenceProvider, @unchecked Sendable {

    let providerID: InferenceProviderID = .mercury

    private let inner: OpenAIInferenceClient

    init() {
        self.inner = OpenAIInferenceClient(
            providerID: .mercury,
            baseURL: "https://api.inceptionlabs.ai/v1"
        )
    }

    var isConfigured: Bool { inner.isConfigured }

    var apiKey: String {
        get { inner.apiKey }
        set { inner.apiKey = newValue }
    }

    func stream(messages: [PAIChatMessage]) -> AsyncThrowingStream<String, Error> {
        inner.stream(messages: messages)
    }

    func testConnection() async -> Result<String, Error> {
        await inner.testConnection()
    }
}
