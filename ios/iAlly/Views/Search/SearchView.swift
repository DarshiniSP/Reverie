//
//  SearchView.swift
//  iAlly
//
//  Phase 2: extended with Knowledge scope (SwiftData) and
//  Memories scope (local memory search via LocalMemoryService).
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedScope: SearchScope
    @State private var showFilters = false
    @State private var searchFilters = SearchFilters()
    @State private var recentSearches: [String] = []

    // Local memory search state (used when scope == .memories)
    @State private var memoryResults: [LocalMemoryItem] = []
    @State private var isSearchingMemory = false
    @State private var memorySearchTask: Task<Void, Never>?

    init(initialScope: SearchScope = .all) {
        _selectedScope = State(initialValue: initialScope)
    }

    var searchResults: [SearchResult] {
        guard selectedScope != .memories else { return [] }
        return SearchService.shared.search(query: searchText, in: selectedScope, context: modelContext)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scope Picker — scrollable so all scopes fit on small screens
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Button {
                                selectedScope = scope
                            } label: {
                                Text(scope.rawValue)
                                    .font(DSFonts.body(14))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedScope == scope
                                            ? DSColors.accentPrimary
                                            : Color.clear
                                    )
                                    .foregroundColor(
                                        selectedScope == scope ? DSColors.onAccent : DSColors.textSecondary
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(DSColors.canvasSecondary)

                if searchText.isEmpty {
                    recentSearchesView
                } else if selectedScope == .memories {
                    memoryResultsView
                } else {
                    searchResultsView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search tasks, knowledge, memories…")
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }
            .onChange(of: selectedScope) { _, _ in
                if selectedScope == .memories && !searchText.isEmpty {
                    scheduleMemorySearch(searchText)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: searchFilters.hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .disabled(selectedScope == .memories)
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(filters: $searchFilters)
            }
            .onAppear {
                recentSearches = SearchService.shared.getRecentSearches()
            }
        }
    }

    // MARK: - Recent searches

    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent Searches")
                                .font(DSFonts.headline())
                                .foregroundColor(DSColors.textPrimary)

                            Spacer()

                            Button("Clear") {
                                SearchService.shared.clearRecentSearches()
                                recentSearches = []
                            }
                            .font(DSFonts.body(14))
                            .foregroundColor(DSColors.accentPrimary)
                        }
                        .padding(.horizontal)

                        ForEach(recentSearches, id: \.self) { query in
                            Button {
                                searchText = query
                            } label: {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(DSColors.textSecondary)
                                    Text(query)
                                        .foregroundColor(DSColors.textPrimary)
                                    Spacer()
                                }
                                .padding()
                                .background(DSColors.canvasSecondary)
                                .cornerRadius(UIConstants.CornerRadius.standard)
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Search tips
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Tips")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                        .padding(.horizontal)

                    SearchTipRow(icon: "magnifyingglass", tip: "Search tasks, knowledge, and notes")
                    SearchTipRow(icon: "brain.head.profile", tip: "Use Memories scope to search Lumina's mind")
                    SearchTipRow(icon: "scope", tip: "Switch scope to narrow results")
                }
                .padding(.top)
            }
            .padding(.vertical)
        }
    }

    // MARK: - App search results (tasks / knowledge / journeys / plans)

    private var searchResultsView: some View {
        List {
            if searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("Try different keywords or adjust your filters")
                )
            } else {
                ForEach(searchResults) { result in
                    searchResultDestination(for: result)
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func searchResultDestination(for result: SearchResult) -> some View {
        switch result.type {
        case .task:
            if let task = result.relevantObject as? TaskWork {
                NavigationLink { TaskDetailView(task: task) } label: { SearchResultRow(result: result) }
            }
        case .journey:
            if let journey = result.relevantObject as? Journey {
                NavigationLink { JourneyDetailView(journey: journey) } label: { SearchResultRow(result: result) }
            }
        case .plan:
            if let plan = result.relevantObject as? Plan {
                NavigationLink { PlanDetailView(plan: plan) } label: { SearchResultRow(result: result) }
            }
        case .routine:
            if let routine = result.relevantObject as? Routine {
                NavigationLink { RoutineDetailView(routine: routine) } label: { SearchResultRow(result: result) }
            }
        case .knowledge, .memory:
            SearchResultRow(result: result)
        }
    }

    // MARK: - Local Memory results

    private var memoryResultsView: some View {
        Group {
            if isSearchingMemory {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Searching Lumina's memory…")
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                    Spacer()
                }
            } else if memoryResults.isEmpty {
                ContentUnavailableView(
                    "No Memories Found",
                    systemImage: "brain.head.profile",
                    description: Text("Lumina hasn't stored anything matching \"\(searchText)\" yet.")
                )
            } else {
                List {
                    ForEach(memoryResults) { memory in
                        MemorySearchResultRow(memory: memory)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func handleSearchTextChange(_ newValue: String) {
        guard !newValue.isEmpty else { return }
        if selectedScope == .memories {
            scheduleMemorySearch(newValue)
        } else if !searchResults.isEmpty {
            SearchService.shared.saveRecentSearch(newValue)
            recentSearches = SearchService.shared.getRecentSearches()
        }
    }

    private func scheduleMemorySearch(_ query: String) {
        memorySearchTask?.cancel()
        memorySearchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run { isSearchingMemory = true }
            let items = await fetchMemories(query: query)
            await MainActor.run {
                memoryResults = items
                isSearchingMemory = false
                if !items.isEmpty {
                    SearchService.shared.saveRecentSearch(query)
                    recentSearches = SearchService.shared.getRecentSearches()
                }
            }
        }
    }

    private func fetchMemories(query: String) async -> [LocalMemoryItem] {
        return LocalMemoryService.shared.search(query: query, limit: 30)
    }
}

// MARK: - App search result row

struct SearchResultRow: View {
    let result: SearchResult

    private var typeLabel: String {
        switch result.type {
        case .task:      return "Task"
        case .journey:   return "Journey"
        case .plan:      return "Plan"
        case .routine:   return "Routine"
        case .knowledge: return "Knowledge"
        case .memory:    return "Memory"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: result.icon)
                .font(DSFonts.headline())
                .foregroundColor(Color(hex: result.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(hex: result.colorHex).opacity(0.1))
                .cornerRadius(UIConstants.CornerRadius.standard)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(DSFonts.body())
                    .foregroundColor(DSColors.textPrimary)

                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                        .lineLimit(2)
                }

                Text(typeLabel)
                    .font(DSFonts.caption())
                    .foregroundColor(Color(hex: result.colorHex))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DSFonts.caption())
                .foregroundColor(DSColors.textSecondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Local memory result row

struct MemorySearchResultRow: View {
    let memory: LocalMemoryItem

    private var memoryTypeInfo: (label: String, color: Color, icon: String) {
        switch memory.memoryType {
        case "episodic":  return ("Episodic", .blue, "clock.fill")
        case "semantic":  return ("Semantic", .purple, "lightbulb.fill")
        case "working":   return ("Working", .orange, "bolt.fill")
        default:          return ("Memory", DSColors.accentPrimary, "brain.head.profile")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: memoryTypeInfo.icon)
                .font(.system(size: 14))
                .foregroundColor(memoryTypeInfo.color)
                .frame(width: 36, height: 36)
                .background(memoryTypeInfo.color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.standard))

            VStack(alignment: .leading, spacing: 4) {
                Text(memory.content)
                    .font(DSFonts.body(14))
                    .foregroundColor(DSColors.textPrimary)
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Text(memoryTypeInfo.label)
                        .font(DSFonts.caption())
                        .foregroundColor(memoryTypeInfo.color)

                    Text("·")
                        .foregroundColor(DSColors.textSecondary)

                    Text(memory.createdAt.formatted(.relative(presentation: .named)))
                        .font(DSFonts.caption())
                        .foregroundColor(DSColors.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Filters sheet

struct SearchFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filters: SearchFilters
    @Query private var tags: [Tag]

    @State private var showDateRangePicker = false
    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    if let range = filters.dateRange {
                        HStack {
                            Text("\(range.start.formatted(date: .abbreviated, time: .omitted)) - \(range.end.formatted(date: .abbreviated, time: .omitted))")
                            Spacer()
                            Button("Clear") {
                                filters.dateRange = nil
                            }
                        }
                    } else {
                        Button("Set Date Range") {
                            showDateRangePicker = true
                        }
                    }
                }

                Section("Tags") {
                    ForEach(tags) { tag in
                        Button {
                            toggleTag(tag)
                        } label: {
                            HStack {
                                Image(systemName: tag.icon)
                                    .foregroundColor(Color(hex: tag.colorHex))
                                Text(tag.name)
                                    .foregroundColor(DSColors.textPrimary)
                                Spacer()
                                if filters.tags.contains(where: { $0.id == tag.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DSColors.accentPrimary)
                                }
                            }
                        }
                    }
                }

                Section("Task Size") {
                    Picker("Size", selection: $filters.size) {
                        Text("Any").tag(nil as TaskSize?)
                        ForEach(TaskSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size as TaskSize?)
                        }
                    }
                }

                Section("Task Status") {
                    Toggle("Only Completed", isOn: Binding(
                        get: { filters.completed == true },
                        set: { filters.completed = $0 ? true : nil }
                    ))

                    Toggle("Only Overdue", isOn: Binding(
                        get: { filters.overdue == true },
                        set: { filters.overdue = $0 ? true : nil }
                    ))
                }

                if filters.hasActiveFilters {
                    Section {
                        Button("Clear All Filters", role: .destructive) {
                            filters = SearchFilters()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showDateRangePicker) {
                DateRangePickerView(startDate: $startDate, endDate: $endDate) {
                    filters.dateRange = DateRange(start: startDate, end: endDate)
                }
            }
        }
    }

    private func toggleTag(_ tag: Tag) {
        if let index = filters.tags.firstIndex(where: { $0.id == tag.id }) {
            filters.tags.remove(at: index)
        } else {
            filters.tags.append(tag)
        }
    }
}

// MARK: - Date range picker

struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, displayedComponents: .date)
            }
            .navigationTitle("Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(); dismiss() }
                }
            }
        }
    }
}

// MARK: - Search tip row

struct SearchTipRow: View {
    let icon: String
    let tip: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(DSColors.accentPrimary)
                .frame(width: 24)
            Text(tip)
                .font(DSFonts.body(14))
                .foregroundColor(DSColors.textSecondary)
        }
        .padding(.horizontal)
    }
}

#Preview {
    SearchView()
        .modelContainer(for: [TaskWork.self, Tag.self, Knowledge.self], inMemory: true)
}
