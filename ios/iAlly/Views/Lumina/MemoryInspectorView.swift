//
//  MemoryInspectorView.swift
//  iAlly
//
//  Browse what Lumina knows about the user — scrollable local memory browser
//  powered by LocalMemoryService (SwiftData).
//

import SwiftUI
import SwiftData

struct MemoryInspectorView: View {

    @State private var selectedCategory: MemoryCategory = .all
    @State private var searchQuery = ""
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \LocalMemoryItem.createdAt, order: .reverse)
    private var allMemories: [LocalMemoryItem]

    private var filteredMemories: [LocalMemoryItem] {
        var items = allMemories

        // Filter by category
        if selectedCategory != .all {
            let type = selectedCategory.rawValue
            items = items.filter { $0.memoryType == type }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            let lower = searchQuery.lowercased()
            items = items.filter { $0.content.lowercased().contains(lower) }
        }

        return Array(items.prefix(200))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker
                content
            }
            .navigationTitle("Memory Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchQuery, prompt: "Search Lumina's memories...")
        }
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MemoryCategory.allCases) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        Label(cat.label, systemImage: cat.icon)
                            .font(DSFonts.body(13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == cat
                                    ? DSColors.accentPrimary
                                    : DSColors.canvasSecondary
                            )
                            .foregroundColor(selectedCategory == cat ? DSColors.onAccent : DSColors.textPrimary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("\(cat.label) memories\(selectedCategory == cat ? ", selected" : "")")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(DSColors.canvasPrimary)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if filteredMemories.isEmpty {
            ContentUnavailableView(
                "No Memories Yet",
                systemImage: "brain.head.profile",
                description: Text("Lumina builds up memories as you capture tasks, complete journeys, and have conversations.")
            )
        } else {
            List(filteredMemories) { memory in
                LocalMemoryRowView(memory: memory)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Memory row

struct LocalMemoryRowView: View {
    let memory: LocalMemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                typeChip
                Spacer()
                Text(memory.createdAt.formatted(.relative(presentation: .named)))
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
            }

            Text(memory.content)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
                .lineLimit(4)

            if let eventType = memory.metadata["event_type"] {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 10))
                    Text(eventType.replacingOccurrences(of: "_", with: " "))
                        .font(DSFonts.caption())
                }
                .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(memory.memoryType) memory: \(memory.content)")
    }

    @ViewBuilder
    private var typeChip: some View {
        let (label, color) = memoryTypeDisplay(memory.memoryType)
        Text(label)
            .font(DSFonts.caption())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func memoryTypeDisplay(_ type: String) -> (String, Color) {
        switch type.lowercased() {
        case "episodic":  return ("Episodic",  .blue)
        case "semantic":  return ("Semantic",  .purple)
        case "working":   return ("Working",   .orange)
        default:          return ("Memory",    DSColors.accentPrimary)
        }
    }
}

// MARK: - Category enum

enum MemoryCategory: String, CaseIterable, Identifiable {
    case all       = "all"
    case episodic  = "episodic"
    case semantic  = "semantic"
    case working   = "working"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:      return "All"
        case .episodic: return "Episodic"
        case .semantic: return "Semantic"
        case .working:  return "Working"
        }
    }

    var icon: String {
        switch self {
        case .all:      return "brain.head.profile"
        case .episodic: return "clock.arrow.circlepath"
        case .semantic: return "tag.fill"
        case .working:  return "bolt.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryInspectorView()
}
