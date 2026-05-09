// PIICatalogManager.swift
// iAlly
//
// Loads, caches, and silently refreshes the PII pattern catalog.
// Strategy:
//   1. On loadCatalog(): load bundled JSON immediately (synchronous, always works offline)
//   2. In background: fetch remote catalog from GitHub if local cache is > 7 days old
//   3. If remote fetch succeeds and version is newer → persist to Application Support cache
//   4. PIIScrubber is notified to reload after any catalog update

import Foundation
import Observation

@Observable
@MainActor
final class PIICatalogManager {

    static let shared = PIICatalogManager()

    // Remote catalog refresh disabled for beta — embedded catalog is sufficient.
    // Post-beta: set a real GitHub raw URL here and remove the early-return in fetchRemote().
    static let remoteURL = ""

    private(set) var catalog: PIIPatternCatalog?
    private(set) var isLoading: Bool = false
    private(set) var catalogVersion: String = "bundled"
    private(set) var catalogUpdated: String = ""
    private(set) var lastFetchDate: Date? = {
        let ts = UserDefaults.standard.double(forKey: "pii.catalogFetchDate")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }()

    private let staleAfterDays: Double = 7

    private init() {}

    // MARK: - Public

    /// Call once on app launch. Loads catalog immediately (no network needed), then
    /// silently refreshes from remote in the background if the cache is stale.
    /// Priority: Application Support cache → bundle file → embedded Swift constant
    func loadCatalog() async {
        // Step 1: load catalog immediately (always succeeds — embedded fallback guarantees it)
        if let cached = loadCached() {
            apply(cached)
        } else if let bundled = loadBundled() {
            apply(bundled)
        } else {
            apply(Self.embedded)  // always available, no Xcode project setup needed
        }
        PIIScrubber.shared.reloadFromCatalog()

        // Step 2: refresh from remote in background if stale
        guard isCacheStale else { return }
        await fetchRemote()
    }

    // MARK: - Private: Loading

    private func loadBundled() -> PIIPatternCatalog? {
        guard let url = Bundle.main.url(forResource: "PIIPatternCatalog", withExtension: "json") else {
            return nil
        }
        return decode(from: url)
    }

    private func loadCached() -> PIIPatternCatalog? {
        guard let url = cachedCatalogURL else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return decode(from: url)
    }

    private func decode(from url: URL) -> PIIPatternCatalog? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PIIPatternCatalog.self, from: data)
    }

    // MARK: - Private: Remote Fetch

    private func fetchRemote() async {
        guard let url = URL(string: Self.remoteURL) else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let fetched = try JSONDecoder().decode(PIIPatternCatalog.self, from: data)

            // Only update if version is newer than what we have
            if isNewer(fetched.version, than: catalogVersion) || catalogVersion == "bundled" {
                persistToCache(data)
                apply(fetched)
                markFetchDate()
                // Notify scrubber to reload with new catalog
                PIIScrubber.shared.reloadFromCatalog()
            } else {
                // Same version — just update the fetch date so we don't re-check for 7 days
                markFetchDate()
            }
        } catch {
#if DEBUG
            print("[PIICatalogManager] Remote fetch failed: \(error.localizedDescription)")
#endif
        }
    }

    // MARK: - Private: Cache Management

    private var cachedCatalogURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("pii_catalog.json")
    }

    private func persistToCache(_ data: Data) {
        guard let url = cachedCatalogURL else { return }
        // Ensure the Application Support directory exists
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private var isCacheStale: Bool {
        guard let last = lastFetchDate else { return true }
        return Date().timeIntervalSince(last) > staleAfterDays * 86_400
    }

    private func markFetchDate() {
        let now = Date()
        lastFetchDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "pii.catalogFetchDate")
    }

    // MARK: - Private: Apply

    private func apply(_ newCatalog: PIIPatternCatalog) {
        catalog = newCatalog
        catalogVersion = newCatalog.version
        catalogUpdated = newCatalog.updated
    }

    // MARK: - Private: Version Comparison

    /// Returns true if `a` is a higher semantic version than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}

// MARK: - Embedded Catalog (Swift constant — always available, no bundle setup needed)
// This is the guaranteed fallback. The remote GitHub file is the source of truth for updates.
// When the remote fetch succeeds with a newer version, it replaces this in the local cache.

extension PIICatalogManager {
    static let embedded = PIIPatternCatalog(
        version: "1.0.0",
        updated: "2026-03-02",
        universal: [
            PIIPattern(id: "phone",          label: "Phone Numbers",       regex: #"(\+?\d{1,3}[\s.\-]?)?\(?\d{3}\)?[\s.\-]?\d{3}[\s.\-]?\d{4}"#,                                          replacement: "[PHONE]"),
            PIIPattern(id: "email",          label: "Email Addresses",     regex: #"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#,                                                   replacement: "[EMAIL]"),
            PIIPattern(id: "credit_card",    label: "Credit Card Numbers", regex: #"\b(?:\d{4}[\s\-]?){3}\d{4}\b"#,                                                                        replacement: "[CARD]"),
            PIIPattern(id: "dob",            label: "Dates of Birth",      regex: #"\b(0?[1-9]|1[0-2])[\/.\-](0?[1-9]|[12]\d|3[01])[\/.\-](\d{2}|\d{4})\b"#,                            replacement: "[DOB]"),
            PIIPattern(id: "passport",       label: "Passport Numbers",    regex: #"\b[A-Z]{1,2}\d{6,9}\b"#,                                                                               replacement: "[PASSPORT]"),
            PIIPattern(id: "ip_address",     label: "IP Addresses",        regex: #"\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b"#,                     replacement: "[IP]"),
            PIIPattern(id: "street_address", label: "Street Addresses",    regex: #"\b\d+\s+[A-Za-z][A-Za-z\s]{2,}(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Court|Ct|Way|Place|Pl|Circle|Cir|Highway|Hwy|Parkway|Pkwy)\.?\b"#, replacement: "[ADDRESS]")
        ],
        regions: [
            "US": PIIRegion(label: "United States (CCPA)", regulation: "CCPA", patterns: [
                PIIPattern(id: "us_ssn", label: "Social Security Number", regex: #"\b\d{3}-\d{2}-\d{4}\b"#,  replacement: "[SSN]"),
                PIIPattern(id: "us_ein", label: "Employer ID Number",     regex: #"\b\d{2}-\d{7}\b"#,          replacement: "[EIN]"),
                PIIPattern(id: "us_zip", label: "ZIP Codes",              regex: #"\b\d{5}(?:-\d{4})?\b"#,     replacement: "[ZIP]")
            ]),
            "GB": PIIRegion(label: "United Kingdom (UK GDPR)", regulation: "UK GDPR", patterns: [
                PIIPattern(id: "gb_ni",       label: "National Insurance Number", regex: #"\b[A-CEGHJ-PR-TW-Z]{2}\s?\d{2}\s?\d{2}\s?\d{2}\s?[A-D]\b"#, replacement: "[NI]"),
                PIIPattern(id: "gb_nhs",      label: "NHS Number",                regex: #"\b\d{3}[\s\-]\d{3}[\s\-]\d{4}\b"#,                            replacement: "[NHS]"),
                PIIPattern(id: "gb_postcode", label: "UK Postcode",               regex: #"\b[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}\b"#,                      replacement: "[POSTCODE]")
            ]),
            "AU": PIIRegion(label: "Australia (Privacy Act)", regulation: "Privacy Act 1988", patterns: [
                PIIPattern(id: "au_tfn",      label: "Tax File Number",              regex: #"\b\d{3}\s?\d{3}\s?\d{3}\b"#,         replacement: "[TFN]"),
                PIIPattern(id: "au_medicare", label: "Medicare Number",              regex: #"\b[2-6]\d{3}\s?\d{5}\s?\d\b"#,       replacement: "[MEDICARE]"),
                PIIPattern(id: "au_abn",      label: "Australian Business Number",   regex: #"\b\d{2}\s?\d{3}\s?\d{3}\s?\d{3}\b"#, replacement: "[ABN]")
            ]),
            "IN": PIIRegion(label: "India (DPDP Act)", regulation: "DPDP 2023", patterns: [
                PIIPattern(id: "in_aadhaar", label: "Aadhaar Number",  regex: #"\b[2-9]\d{3}\s?\d{4}\s?\d{4}\b"#,  replacement: "[AADHAAR]"),
                PIIPattern(id: "in_pan",     label: "PAN Card Number", regex: #"\b[A-Z]{5}[0-9]{4}[A-Z]\b"#,       replacement: "[PAN]"),
                PIIPattern(id: "in_voter",   label: "Voter ID",        regex: #"\b[A-Z]{3}[0-9]{7}\b"#,            replacement: "[VOTER_ID]"),
                PIIPattern(id: "in_pincode", label: "PIN Code",        regex: #"\b[1-9][0-9]{5}\b"#,               replacement: "[PINCODE]")
            ]),
            "SG": PIIRegion(label: "Singapore (PDPA)", regulation: "PDPA", patterns: [
                PIIPattern(id: "sg_nric",   label: "NRIC / FIN Number",      regex: #"\b[STFGM]\d{7}[A-Z]\b"#, replacement: "[NRIC]"),
                PIIPattern(id: "sg_postal", label: "Singapore Postal Code",   regex: #"\b[0-9]{6}\b"#,          replacement: "[POSTAL]")
            ]),
            "BR": PIIRegion(label: "Brazil (LGPD)", regulation: "LGPD", patterns: [
                PIIPattern(id: "br_cpf",  label: "CPF Number",  regex: #"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"#,          replacement: "[CPF]"),
                PIIPattern(id: "br_cnpj", label: "CNPJ Number", regex: #"\b\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}\b"#,  replacement: "[CNPJ]"),
                PIIPattern(id: "br_cep",  label: "CEP",         regex: #"\b\d{5}-?\d{3}\b"#,                           replacement: "[CEP]")
            ]),
            "CA": PIIRegion(label: "Canada (PIPEDA)", regulation: "PIPEDA", patterns: [
                PIIPattern(id: "ca_sin",    label: "Social Insurance Number", regex: #"\b\d{3}[\s\-]\d{3}[\s\-]\d{3}\b"#, replacement: "[SIN]"),
                PIIPattern(id: "ca_postal", label: "Canadian Postal Code",    regex: #"\b[A-Z]\d[A-Z]\s?\d[A-Z]\d\b"#,   replacement: "[POSTAL]")
            ]),
            "ZA": PIIRegion(label: "South Africa (POPIA)", regulation: "POPIA", patterns: [
                PIIPattern(id: "za_id", label: "SA Identity Number", regex: #"\b[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])[0-9]{4}[01][89][0-9]\b"#, replacement: "[SA_ID]")
            ]),
            "DE": PIIRegion(label: "Germany (GDPR)", regulation: "GDPR", patterns: [
                PIIPattern(id: "de_steuer", label: "Tax ID",  regex: #"\b[1-9]\d{10}\b"#,                                                                   replacement: "[TAX_ID]"),
                PIIPattern(id: "eu_iban",   label: "IBAN",    regex: #"\b[A-Z]{2}\d{2}[\s\-]?(?:[A-Z0-9]{4}[\s\-]?){4,7}[A-Z0-9]{0,4}\b"#,               replacement: "[IBAN]")
            ]),
            "FR": PIIRegion(label: "France (GDPR)", regulation: "GDPR", patterns: [
                PIIPattern(id: "fr_nir",  label: "NIR (Social Security)", regex: #"\b[12][0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[1-9][0-9]|9[0-5])[0-9]{6}[0-9]{2}\b"#, replacement: "[NIR]"),
                PIIPattern(id: "eu_iban", label: "IBAN",                  regex: #"\b[A-Z]{2}\d{2}[\s\-]?(?:[A-Z0-9]{4}[\s\-]?){4,7}[A-Z0-9]{0,4}\b"#,          replacement: "[IBAN]")
            ]),
            "AE": PIIRegion(label: "UAE (PDPL)", regulation: "PDPL 2021", patterns: [
                PIIPattern(id: "ae_eid", label: "Emirates ID", regex: #"\b784-[0-9]{4}-[0-9]{7}-[0-9]\b"#, replacement: "[EMIRATES_ID]")
            ]),
            "MY": PIIRegion(label: "Malaysia (PDPA)", regulation: "PDPA 2010", patterns: [
                PIIPattern(id: "my_nric", label: "MyKad (NRIC)", regex: #"\b\d{6}-\d{2}-\d{4}\b"#, replacement: "[MYKAD]")
            ])
        ]
    )
}
