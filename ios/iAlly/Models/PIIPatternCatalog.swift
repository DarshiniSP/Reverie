// PIIPatternCatalog.swift
// iAlly
//
// Codable models for the PII pattern catalog.
// The catalog is bundled as PIIPatternCatalog.json and refreshed weekly from GitHub.

import Foundation

// MARK: - Catalog Root

struct PIIPatternCatalog: Codable {
    let version: String                     // e.g. "1.0.0"
    let updated: String                     // e.g. "2026-03-02"
    let universal: [PIIPattern]             // always-on, applied regardless of region
    let regions: [String: PIIRegion]        // keyed by ISO 3166-1 alpha-2 region code
}

// MARK: - Region

struct PIIRegion: Codable {
    let label: String           // "United States (CCPA)"
    let regulation: String      // "CCPA"
    let patterns: [PIIPattern]
}

// MARK: - Pattern

struct PIIPattern: Codable, Identifiable {
    let id: String              // "us_ssn", "phone", "in_aadhaar", etc.
    let label: String           // "Social Security Number"
    let regex: String           // raw regex string (not yet compiled)
    let replacement: String     // "[SSN]", "[EMAIL]", etc.
}

// MARK: - Custom Pattern (user-defined)

struct CustomPIIPattern: Codable, Identifiable {
    var id: UUID
    var label: String           // user-assigned name, e.g. "Employee ID"
    var regex: String           // raw regex
    var replacement: String     // e.g. "[EMPLOYEE_ID]"
    var enabled: Bool
}

// MARK: - Scrub Result

struct ScrubResult {
    let scrubbed: String
    let redactions: [(category: String, count: Int)]

    var totalRedactions: Int {
        redactions.reduce(0) { $0 + $1.count }
    }

    var wasModified: Bool { scrubbed.count != redactions.reduce(0) { $0 + $1.count } || !redactions.isEmpty }
}

// MARK: - Audit Entry

struct ScrubAuditEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let redactions: [(category: String, count: Int)]

    var totalRedactions: Int {
        redactions.reduce(0) { $0 + $1.count }
    }
}
