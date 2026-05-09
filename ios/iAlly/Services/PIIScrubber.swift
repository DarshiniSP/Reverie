// PIIScrubber.swift
// iAlly
//
// 3-layer PII scrubbing engine.
// Layer 1: Universal patterns (always ON — phone, email, CC, address, DOB, passport, IP)
// Layer 2: Jurisdictional patterns (auto-selected from device locale)
// Layer 3: Custom user-defined regex patterns
//
// Universal and regional protections are always active and cannot be disabled.
// Users can add custom patterns via Settings for organisation-specific identifiers.
//
// Integration point: LuminaConversationService calls scrub() on each user message
// before sending to pai.chatStream() — data never leaves the device in plaintext.

import Foundation
import Observation

@Observable
@MainActor
final class PIIScrubber {

    static let shared = PIIScrubber()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let selectedRegion = "pii.selectedRegion"
        static let customPatterns = "pii.customPatterns"  // JSON [CustomPIIPattern]
    }

    // MARK: - Persisted State

    /// ISO 3166-1 alpha-2 region code. Auto-detected from device locale.
    private(set) var selectedRegion: String

    /// User-defined custom patterns.
    var customPatterns: [CustomPIIPattern] {
        didSet {
            if let data = try? JSONEncoder().encode(customPatterns) {
                UserDefaults.standard.set(data, forKey: Keys.customPatterns)
            }
            rebuildCache()
        }
    }

    // MARK: - In-Memory Audit Log (resets on app restart, capped at 100)

    private(set) var auditLog: [ScrubAuditEntry] = []
    private let auditLogCap = 100

    var sessionRedactionTotal: Int {
        auditLog.reduce(0) { $0 + $1.totalRedactions }
    }

    // MARK: - Compiled Pattern Cache

    // Tuple of (label, compiled regex, replacement)
    private var compiledPatterns: [(label: String, regex: NSRegularExpression, replacement: String)] = []

    // MARK: - Init

    private init() {
        // Auto-detect region from device locale (or use cached value)
        let stored = UserDefaults.standard.string(forKey: Keys.selectedRegion) ?? ""
        if stored.isEmpty {
            let detected = Locale.current.region?.identifier ?? "US"
            selectedRegion = detected
            UserDefaults.standard.set(detected, forKey: Keys.selectedRegion)
        } else {
            selectedRegion = stored
        }

        // Load custom user patterns
        if let data = UserDefaults.standard.data(forKey: Keys.customPatterns),
           let patterns = try? JSONDecoder().decode([CustomPIIPattern].self, from: data) {
            customPatterns = patterns
        } else {
            customPatterns = []
        }

        rebuildCache()
    }

    // MARK: - Public API

    /// Scrub PII from `text`. Returns the cleaned string and a summary of what was redacted.
    /// Only user-role messages should be scrubbed; system messages are not passed here.
    func scrub(_ text: String) -> ScrubResult {
        guard !compiledPatterns.isEmpty else {
            return ScrubResult(scrubbed: text, redactions: [])
        }

        var result = text
        var redactions: [(category: String, count: Int)] = []

        for (label, regex, replacement) in compiledPatterns {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range)
            guard !matches.isEmpty else { continue }

            // Replace in reverse order to preserve string indices
            let nsResult = NSMutableString(string: result)
            for match in matches.reversed() {
                nsResult.replaceCharacters(in: match.range, with: replacement)
            }
            result = nsResult as String
            redactions.append((category: label, count: matches.count))
        }

        let scrubResult = ScrubResult(scrubbed: result, redactions: redactions)

        // Append to audit log
        if !redactions.isEmpty {
            appendToAuditLog(ScrubAuditEntry(timestamp: Date(), redactions: redactions))
        }

        return scrubResult
    }

    /// Called by PIICatalogManager after a new catalog is downloaded.
    func reloadFromCatalog() {
        rebuildCache()
    }

    /// Returns the active region info from the catalog (nil if catalog not yet loaded).
    func activeRegionInfo() -> PIIRegion? {
        PIICatalogManager.shared.catalog?.regions[selectedRegion]
    }

    // MARK: - Cache Build

    private func rebuildCache() {
        guard let catalog = PIICatalogManager.shared.catalog else {
            compiledPatterns = []
            return
        }

        var patterns: [(label: String, regex: NSRegularExpression, replacement: String)] = []

        // Layer 1: Universal (always active)
        for p in catalog.universal {
            if let regex = compileRegex(p.regex) {
                patterns.append((label: p.label, regex: regex, replacement: p.replacement))
            }
        }

        // Layer 2: Regional (always active for auto-detected region)
        if let region = catalog.regions[selectedRegion] {
            for p in region.patterns {
                if let regex = compileRegex(p.regex) {
                    patterns.append((label: p.label, regex: regex, replacement: p.replacement))
                }
            }
        }

        // Layer 3: Custom user patterns (only enabled ones)
        for p in customPatterns where p.enabled {
            if let regex = compileRegex(p.regex) {
                patterns.append((label: p.label, regex: regex, replacement: p.replacement))
            }
        }

        compiledPatterns = patterns
    }

    // MARK: - Regex Compilation (with basic validation)

    private var regexCache: [String: NSRegularExpression] = [:]

    private func compileRegex(_ pattern: String) -> NSRegularExpression? {
        if let cached = regexCache[pattern] { return cached }
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            regexCache[pattern] = regex
            return regex
        } catch {
#if DEBUG
            print("[PIIScrubber] Invalid regex '\(pattern)': \(error.localizedDescription)")
#endif
            return nil
        }
    }

    // MARK: - Audit Log

    private func appendToAuditLog(_ entry: ScrubAuditEntry) {
        auditLog.append(entry)
        if auditLog.count > auditLogCap {
            auditLog.removeFirst(auditLog.count - auditLogCap)
        }
    }

}

// MARK: - Custom Pattern Validation

extension PIIScrubber {
    /// Returns nil if the regex is valid, or an error description if invalid.
    func validateRegex(_ pattern: String) -> String? {
        do {
            _ = try NSRegularExpression(pattern: pattern)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
