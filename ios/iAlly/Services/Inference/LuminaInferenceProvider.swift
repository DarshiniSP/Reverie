// LuminaInferenceProvider.swift
// iAlly
//
// Protocol and shared types for all direct inference providers.
// Each provider calls its API directly from the device — no PAIService needed.

import Foundation
import Security

// MARK: - Provider ID

enum InferenceProviderID: String, CaseIterable, Codable {
    case anthropic = "anthropic"
    case openai    = "openai"
    case gemini    = "gemini"
    case mercury   = "mercury"

    var displayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai:    return "ChatGPT"
        case .gemini:    return "Gemini"
        case .mercury:   return "Mercury"
        }
    }

    var providerLabel: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai:    return "OpenAI"
        case .gemini:    return "Google"
        case .mercury:   return "Inception Labs"
        }
    }

    var modelName: String {
        switch self {
        case .anthropic: return "claude-sonnet-4-6"
        case .openai:    return "gpt-4o"
        case .gemini:    return "gemini-2.0-flash"
        case .mercury:   return "mercury-2"
        }
    }

    var modelLabel: String {
        switch self {
        case .anthropic: return "Sonnet 4.6"
        case .openai:    return "GPT-4o"
        case .gemini:    return "2.0 Flash"
        case .mercury:   return "Mercury 2"
        }
    }

    var keychainKey: String {
        "com.irigam.iAlly.apiKey.\(rawValue)"
    }
}

// MARK: - Protocol

protocol LuminaInferenceProvider: AnyObject, Sendable {
    var providerID: InferenceProviderID { get }
    var isConfigured: Bool { get }

    /// Stream tokens from the provider. Each yielded String is a raw text chunk.
    func stream(messages: [PAIChatMessage]) -> AsyncThrowingStream<String, Error>

    /// Quick connectivity test. Returns model identifier string on success.
    func testConnection() async -> Result<String, Error>
}

// MARK: - Errors

enum InferenceError: LocalizedError {
    case notConfigured(InferenceProviderID)
    case httpError(Int, String)
    case networkError(Error)
    case decodingError(String)
    case streamInterrupted

    var errorDescription: String? {
        switch self {
        case .notConfigured(let p):   return "No API key configured for \(p.displayName)."
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .networkError(let e):    return e.localizedDescription
        case .decodingError(let s):   return "Decode error: \(s)"
        case .streamInterrupted:      return "Stream was interrupted."
        }
    }
}

// MARK: - Keychain Helpers (shared, internal)

enum InferenceKeychain {
    static func set(_ value: String, key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let del: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(del as CFDictionary)
        guard !value.isEmpty else { return }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    static func get(key: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
