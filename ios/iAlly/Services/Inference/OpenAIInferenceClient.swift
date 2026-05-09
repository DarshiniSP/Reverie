// OpenAIInferenceClient.swift
// iAlly
//
// Direct OpenAI API calls from iOS (also used as the base for Mercury).
// POST https://api.openai.com/v1/chat/completions
// SSE: data: {json} → choices[0].delta.content, sentinel: data: [DONE]

import Foundation

final class OpenAIInferenceClient: LuminaInferenceProvider, @unchecked Sendable {

    let providerID: InferenceProviderID
    private let baseURL: String

    var isConfigured: Bool {
        !(InferenceKeychain.get(key: providerID.keychainKey) ?? "").isEmpty
    }

    var apiKey: String {
        get { InferenceKeychain.get(key: providerID.keychainKey) ?? "" }
        set { InferenceKeychain.set(newValue, key: providerID.keychainKey) }
    }

    /// Use for both OpenAI and Mercury (same protocol, different base URL + model).
    init(providerID: InferenceProviderID, baseURL: String) {
        self.providerID = providerID
        self.baseURL = baseURL
    }

    // MARK: - Stream

    func stream(messages: [PAIChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard !self.apiKey.isEmpty else {
                    continuation.finish(throwing: InferenceError.notConfigured(self.providerID))
                    return
                }
                do {
                    let req = try self.buildRequest(messages: messages, stream: true)
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.finish(throwing: InferenceError.httpError(http.statusCode, ""))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if json == "[DONE]" { break }
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let text = delta["content"] as? String,
                              !text.isEmpty
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: InferenceError.networkError(error))
                }
            }
        }
    }

    // MARK: - Test Connection

    func testConnection() async -> Result<String, Error> {
        guard !apiKey.isEmpty else {
            return .failure(InferenceError.notConfigured(providerID))
        }
        do {
            let testMessages = [PAIChatMessage(role: "user", content: "Hi")]
            var req = try buildRequest(messages: testMessages, stream: false, maxTokens: 5)
            req.timeoutInterval = 10
            let start = Date()
            let (data, response) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            guard let http = response as? HTTPURLResponse else {
                return .failure(InferenceError.networkError(URLError(.badServerResponse)))
            }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                return .failure(InferenceError.httpError(http.statusCode, body))
            }
            return .success("\(providerID.modelName) · \(latency)ms")
        } catch {
            return .failure(InferenceError.networkError(error))
        }
    }

    // MARK: - Request Builder

    private func buildRequest(messages: [PAIChatMessage], stream: Bool, maxTokens: Int = 2048) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw InferenceError.decodingError("Invalid URL")
        }

        let body: [String: Any] = [
            "model": providerID.modelName,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": stream
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120
        return req
    }
}
