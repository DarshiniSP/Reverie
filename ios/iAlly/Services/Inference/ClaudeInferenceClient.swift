// ClaudeInferenceClient.swift
// iAlly
//
// Direct Anthropic Claude API calls from iOS.
// POST https://api.anthropic.com/v1/messages
// SSE: parse content_block_delta events → delta.text

import Foundation

final class ClaudeInferenceClient: LuminaInferenceProvider, @unchecked Sendable {

    let providerID: InferenceProviderID = .anthropic

    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let anthropicVersion = "2023-06-01"

    var isConfigured: Bool {
        !(InferenceKeychain.get(key: providerID.keychainKey) ?? "").isEmpty
    }

    var apiKey: String {
        get { InferenceKeychain.get(key: providerID.keychainKey) ?? "" }
        set { InferenceKeychain.set(newValue, key: providerID.keychainKey) }
    }

    // MARK: - Stream

    func stream(messages: [PAIChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard !self.apiKey.isEmpty else {
                    continuation.finish(throwing: InferenceError.notConfigured(.anthropic))
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
                        guard json != "[DONE]",
                              let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        else { continue }

                        // content_block_delta → delta.text
                        if let type = obj["type"] as? String, type == "content_block_delta",
                           let delta = obj["delta"] as? [String: Any],
                           let text = delta["text"] as? String, !text.isEmpty {
                            continuation.yield(text)
                        }

                        // message_stop ends stream
                        if let type = obj["type"] as? String, type == "message_stop" {
                            break
                        }
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
            return .failure(InferenceError.notConfigured(.anthropic))
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
                return .failure(parseAnthropicError(data: data, statusCode: http.statusCode))
            }
            return .success("\(providerID.modelName) · \(latency)ms")
        } catch {
            return .failure(InferenceError.networkError(error))
        }
    }

    /// Parse Anthropic's standard error envelope into a human-readable InferenceError.
    /// Anthropic returns: { "type": "error", "error": { "type": "...", "message": "..." } }
    private func parseAnthropicError(data: Data, statusCode: Int) -> InferenceError {
        // Extract the human-readable message from Anthropic's error envelope
        let anthropicMessage: String? = {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let err  = json["error"] as? [String: Any],
                  let msg  = err["message"] as? String else { return nil }
            return msg
        }()

        // Credit / billing errors come back as 400 from Anthropic with a specific message
        let isCreditError = anthropicMessage?.lowercased().contains("credit") == true
                         || anthropicMessage?.lowercased().contains("billing") == true
                         || anthropicMessage?.lowercased().contains("balance") == true

        switch statusCode {
        case 400 where isCreditError:
            return .httpError(400,
                "Insufficient Anthropic API credits. " +
                "Add credits at console.anthropic.com → Billing. " +
                "Note: PAI subscription and Anthropic API credits are separate."
            )
        case 400:
            return .httpError(400, anthropicMessage ?? "Bad request — check your API key format.")
        case 401:
            return .httpError(401, "Invalid API key — check it at console.anthropic.com → API Keys.")
        case 403:
            return .httpError(403, anthropicMessage ?? "Access denied — your key may lack permissions.")
        case 429:
            return .httpError(429,
                "Rate limit reached. Wait ~60 seconds and try again, " +
                "or check your usage limits at console.anthropic.com."
            )
        default:
            return .httpError(statusCode, anthropicMessage ?? (String(data: data, encoding: .utf8) ?? "Unknown error"))
        }
    }

    // MARK: - Request Builder

    private func buildRequest(messages: [PAIChatMessage], stream: Bool, maxTokens: Int = 2048) throws -> URLRequest {
        guard let url = URL(string: endpoint) else {
            throw InferenceError.decodingError("Invalid URL")
        }

        // Separate system messages from conversation
        let systemContent = messages
            .filter { $0.role == "system" }
            .map { $0.content }
            .joined(separator: "\n\n")

        let conversationMessages = messages
            .filter { $0.role != "system" }
            .map { ["role": $0.role, "content": $0.content] }

        var body: [String: Any] = [
            "model": providerID.modelName,
            "max_tokens": maxTokens,
            "messages": conversationMessages,
            "stream": stream
        ]
        if !systemContent.isEmpty {
            body["system"] = systemContent
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120
        return req
    }
}
