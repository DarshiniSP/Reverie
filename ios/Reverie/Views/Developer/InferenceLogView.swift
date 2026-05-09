// InferenceLogView.swift
// iAlly
//
// Developer log page: shows every Lumina inference call with the full payload
// sent to the provider and the raw response received.
// Access: More tab → Developer → Inference Logs

import SwiftUI

// MARK: - Log List

struct InferenceLogView: View {

    @State private var logger = InferenceLogger.shared
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if logger.logs.isEmpty {
                emptyState
            } else {
                logList
            }
        }
        .navigationTitle("Inference Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !logger.logs.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(DSColors.error)
                    }
                }
            }
        }
        .confirmationDialog("Clear all logs?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                logger.clear()
            }
            Button("Cancel", role: .cancel) {}
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(DSColors.textSecondary.opacity(0.4))
            Text("No logs yet")
                .font(DSFonts.title())
                .foregroundColor(DSColors.textPrimary)
            Text("Send a message in Lumina to record the first inference call.")
                .font(DSFonts.body())
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Log List

    private var logList: some View {
        List {
            Section {
                Text("\(logger.logs.count) log\(logger.logs.count == 1 ? "" : "s") — cleared on restart")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }
            ForEach(logger.logs) { log in
                NavigationLink(destination: InferenceLogDetailView(log: log)) {
                    InferenceLogRow(log: log)
                }
                .listRowBackground(DSColors.canvasSecondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(DSColors.canvasPrimary)
    }
}

// MARK: - List Row

private struct InferenceLogRow: View {

    let log: InferenceLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Provider badge
                Text(log.provider)
                    .font(DSFonts.caption().weight(.semibold))
                    .foregroundColor(DSColors.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(providerColor)
                    .cornerRadius(UIConstants.CornerRadius.small)

                // Duration
                Text("\(log.durationMs) ms")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)

                Spacer()

                // Error chip
                if log.error != nil {
                    Text("ERROR")
                        .font(DSFonts.caption().weight(.bold))
                        .foregroundColor(DSColors.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DSColors.error)
                        .cornerRadius(4)
                }

                // Relative timestamp
                Text(log.timestamp.relativeShort)
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textTertiary)
            }

            // Message preview
            Text(log.userMsg.isEmpty ? "(no user message)" : log.userMsg)
                .font(DSFonts.body(15))
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(2)

            // Message count summary
            let sysCnt  = log.payload.filter { $0.role == "system" }.count
            let convCnt = log.payload.filter { $0.role != "system" }.count
            Text("\(sysCnt) system · \(convCnt) conv · \(log.payload.count) total")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var providerColor: Color {
        let name = log.provider.lowercased()
        if name.contains("mercury")   { return Color(red: 0.5, green: 0.2, blue: 0.9) }
        if name.contains("claude")    { return Color(red: 0.85, green: 0.45, blue: 0.2) }
        if name.contains("chatgpt") || name.contains("openai") { return Color(red: 0.1, green: 0.75, blue: 0.5) }
        if name.contains("gemini")    { return Color(red: 0.2, green: 0.5, blue: 0.95) }
        return DSColors.textSecondary
    }
}

// MARK: - Detail View

struct InferenceLogDetailView: View {

    let log: InferenceLog
    @State private var selectedTab: Int = 0
    @State private var copyFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Segment picker
            Picker("", selection: $selectedTab) {
                Text("Payload (\(log.payload.count))").tag(0)
                Text("Response").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            if selectedTab == 0 {
                payloadTab
            } else {
                responseTab
            }
        }
        .navigationTitle(log.timestamp.logTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Label(copyFeedback ? "Copied!" : "Copy JSON",
                          systemImage: copyFeedback ? "checkmark" : "doc.on.clipboard")
                        .foregroundColor(copyFeedback ? DSColors.success : DSColors.accentPrimary)
                }
            }
        }
        .background(DSColors.canvasPrimary.ignoresSafeArea())
    }

    // MARK: Payload Tab

    private var payloadTab: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                // Summary header
                HStack {
                    let sys  = log.payload.filter { $0.role == "system" }.count
                    let usr  = log.payload.filter { $0.role == "user" }.count
                    let ast  = log.payload.filter { $0.role == "assistant" }.count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Payload summary")
                            .font(DSFonts.label().weight(.semibold))
                            .foregroundColor(DSColors.textPrimary)
                        Text("\(sys) system  ·  \(usr) user  ·  \(ast) assistant  ·  \(log.payload.count) total")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                        Text("Provider: \(log.provider)  ·  \(log.durationMs) ms")
                            .font(DSFonts.caption())
                            .foregroundColor(DSColors.textSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(DSColors.canvasSecondary)
                .cornerRadius(UIConstants.CornerRadius.large)
                .padding(.horizontal)

                // Each message
                ForEach(Array(log.payload.enumerated()), id: \.offset) { idx, msg in
                    MessageCard(index: idx + 1, message: msg)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: Response Tab

    private var responseTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let err = log.error {
                    // Error banner
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DSColors.error)
                        Text("Call failed: \(err)")
                            .font(DSFonts.body())
                            .foregroundColor(DSColors.error)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DSColors.error.opacity(0.1))
                    .cornerRadius(UIConstants.CornerRadius.medium)
                    .padding(.horizontal)
                } else if log.response.isEmpty {
                    Text("(empty response)")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .padding()
                } else {
                    // Highlighted response text
                    Text(highlightedResponse)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(DSColors.textPrimary)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DSColors.canvasSecondary)
                        .cornerRadius(UIConstants.CornerRadius.medium)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: Helpers

    private var highlightedResponse: AttributedString {
        var result = AttributedString(log.response)
        let markers = [
            "[TASK_PROPOSAL:",
            "[ROUTINE_PROPOSAL:",
            "[JOURNEY_PROPOSAL:",
            "[PLAN_PROPOSAL:",
            "[MILESTONE_PROPOSAL:"
        ]
        for marker in markers {
            var searchRange = result.startIndex..<result.endIndex
            while let range = result[searchRange].range(of: marker) {
                result[range].foregroundColor = .orange
                result[range].font = .system(.body, design: .monospaced).bold()
                searchRange = range.upperBound..<result.endIndex
            }
        }
        return result
    }

    private func copyToClipboard() {
        struct JSONLog: Codable {
            let timestamp: String
            let provider: String
            let durationMs: Int
            let error: String?
            let payload: [[String: String]]
            let response: String
        }
        let iso = ISO8601DateFormatter()
        let jl = JSONLog(
            timestamp: iso.string(from: log.timestamp),
            provider: log.provider,
            durationMs: log.durationMs,
            error: log.error,
            payload: log.payload.map { ["role": $0.role, "content": $0.content] },
            response: log.response
        )
        if let data = try? JSONEncoder().encode(jl),
           let str  = String(data: data, encoding: .utf8) {
            // Pretty-print
            if let pretty = try? JSONSerialization.jsonObject(with: data),
               let prettyData = try? JSONSerialization.data(withJSONObject: pretty, options: .prettyPrinted),
               let prettyStr = String(data: prettyData, encoding: .utf8) {
                UIPasteboard.general.string = prettyStr
            } else {
                UIPasteboard.general.string = str
            }
        }
        withAnimation { copyFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copyFeedback = false }
        }
    }
}

// MARK: - Message Card

private struct MessageCard: View {

    let index: Int
    let message: PAIChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Index
                Text("#\(index)")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textTertiary)
                    .frame(minWidth: 28, alignment: .leading)

                // Role badge
                Text(message.role.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(DSColors.onAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(roleBadgeColor)
                    .cornerRadius(5)

                // Character count
                Text("\(message.content.count) chars")
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textTertiary)

                Spacer()
            }

            // Content
            Text(message.content)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(DSColors.textPrimary)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(DSColors.canvasSecondary)
        .cornerRadius(UIConstants.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.medium)
                .stroke(roleBadgeColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var roleBadgeColor: Color {
        switch message.role {
        case "system":    return DSColors.accentSecondary  // purple
        case "user":      return DSColors.accentPrimary    // blue
        case "assistant": return DSColors.success           // green
        default:          return DSColors.textSecondary
        }
    }
}

// MARK: - Date Extensions

private extension Date {
    var relativeShort: String {
        let diff = Int(Date().timeIntervalSince(self))
        if diff < 60        { return "\(diff)s ago" }
        if diff < 3600      { return "\(diff / 60)m ago" }
        if diff < 86400     { return "\(diff / 3600)h ago" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: self)
    }

    var logTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d · HH:mm:ss"
        return fmt.string(from: self)
    }
}
