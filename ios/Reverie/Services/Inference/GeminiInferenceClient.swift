// GeminiInferenceClient.swift
// iAlly
//
// Direct Google Gemini API calls from iOS.
// POST https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent
// Auth: ?key={apiKey} query param
// SSE: data: {json} → candidates[0].content.parts[0].text

import Foundation

final class GeminiInferenceClient: LuminaInferenceProvider, @unchecked Sendable {

    let providerID: InferenceProviderID = .gemini

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

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
                    continuation.finish(throwing: InferenceError.notConfigured(.gemini))
                    return
                }
                do {
                    let req = try self.buildRequest(messages: messages)
                    let (bytes, response) = try await URLSession.shared.bytes(for: req)

                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        continuation.finish(throwing: InferenceError.httpError(http.statusCode, ""))
                        return
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let json = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        guard let data = json.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let candidates = obj["candidates"] as? [[String: Any]],
                              let content = candidates.first?["content"] as? [String: Any],
                              let parts = content["parts"] as? [[String: Any]],
                              let text = parts.first?["text"] as? String,
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
            return .failure(InferenceError.notConfigured(.gemini))
        }
        do {
            // Use the non-streaming generateContent endpoint for connectivity tests.
            // streamGenerateContent?alt=sse is for real inference only — using it here
            // adds SSE overhead and wastes a rate-limit slot unnecessarily.
            let body: [String: Any] = [
                "contents": [["role": "user", "parts": [["text": "Hi"]]]],
                "generationConfig": ["maxOutputTokens": 5]
            ]
            let urlString = "\(baseURL)/\(providerID.modelName):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else {
                return .failure(InferenceError.decodingError("Invalid Gemini URL"))
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.timeoutInterval = 10

            let start = Date()
            let (data, response) = try await URLSession.shared.data(for: req)
            let latency = Int(Date().timeIntervalSince(start) * 1000)

            guard let http = response as? HTTPURLResponse else {
                return .failure(InferenceError.networkError(URLError(.badServerResponse)))
            }
            guard http.statusCode == 200 else {
                return .failure(parseGeminiError(data: data, statusCode: http.statusCode))
            }
            return .success("\(providerID.modelName) · \(latency)ms")
        } catch {
            return .failure(InferenceError.networkError(error))
        }
    }

    /// Parse Google's standard error envelope into a human-readable InferenceError.
    /// Google returns: { "error": { "code": 429, "message": "...", "status": "RESOURCE_EXHAUSTED" } }
    private func parseGeminiError(data: Data, statusCode: Int) -> InferenceError {
        // Extract the human-readable message from Google's error JSON
        let googleMessage: String? = {
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let err  = json["error"] as? [String: Any],
                  let msg  = err["message"] as? String else { return nil }
            return msg
        }()

        switch statusCode {
        case 429:
            // Rate limit — tell the user WHY and what to do, not just "HTTP 429"
            return .httpError(429,
                "Rate limit reached (free tier: 15 req/min). " +
                "Wait ~60 seconds and try again, or upgrade your Google AI Studio plan."
            )
        case 400:
            return .httpError(400, googleMessage ?? "Bad request — check the API key format.")
        case 401, 403:
            return .httpError(statusCode, googleMessage ?? "Invalid or unauthorised API key.")
        default:
            return .httpError(statusCode, googleMessage ?? (String(data: data, encoding: .utf8) ?? "Unknown error"))
        }
    }

    // MARK: - Request Builder

    private func buildRequest(messages: [PAIChatMessage], maxTokens: Int = 2048) throws -> URLRequest {
        // Separate system instructions from conversation
        let systemParts = messages
            .filter { $0.role == "system" }
            .map { ["text": $0.content] }

        // Gemini: user → "user", assistant → "model"
        let contents: [[String: Any]] = messages
            .filter { $0.role != "system" }
            .map { msg in
                let role = msg.role == "assistant" ? "model" : "user"
                return ["role": role, "parts": [["text": msg.content]]]
            }

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": ["maxOutputTokens": maxTokens]
        ]
        if !systemParts.isEmpty {
            body["systemInstruction"] = ["parts": systemParts]
        }

        // Streaming endpoint with key param and alt=sse for SSE format
        let urlString = "\(baseURL)/\(providerID.modelName):streamGenerateContent?key=\(apiKey)&alt=sse"
        guard let url = URL(string: urlString) else {
            throw InferenceError.decodingError("Invalid URL")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120
        return req
    }
}
