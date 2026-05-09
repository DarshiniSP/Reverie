import SwiftUI
import SwiftData

struct CompletedTasksView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(filter: #Predicate<TaskWork> { task in
        task.completedAt != nil
    }, sort: \TaskWork.completedAt, order: .reverse)
    private var completedTasks: [TaskWork]
    
    @State private var searchText = ""
    
    private var filteredTasks: [TaskWork] {
        if searchText.isEmpty {
            return completedTasks
        }
        return completedTasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var groupedTasks: [(String, [TaskWork])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredTasks) { task -> String in
            guard let completedAt = task.completedAt else { return "Unknown" }
            
            if calendar.isDateInToday(completedAt) {
                return "Today"
            } else if calendar.isDateInYesterday(completedAt) {
                return "Yesterday"
            } else if calendar.isDate(completedAt, equalTo: Date(), toGranularity: .weekOfYear) {
                return "This Week"
            } else if calendar.isDate(completedAt, equalTo: Date(), toGranularity: .month) {
                return "This Month"
            } else {
                return "Older"
            }
        }
        
        // Return in specific order
        let order = ["Today", "Yesterday", "This Week", "This Month", "Older"]
        return order.compactMap { section in
            guard let tasks = groups[section], !tasks.isEmpty else { return nil }
            return (section, tasks)
        }
    }
    
    var body: some View {
        List {
            if completedTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(DSColors.textSecondary.opacity(0.5))
                    
                    Text("No Completed Tasks")
                        .font(DSFonts.headline())
                        .foregroundColor(DSColors.textPrimary)
                    
                    Text("Complete some tasks to see them here")
                        .font(DSFonts.body())
                        .foregroundColor(DSColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedTasks, id: \.0) { section, tasks in
                    Section(section) {
                        ForEach(tasks) { task in
                            CompletedTaskRow(task: task)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search completed tasks")
        .navigationTitle("Completed Tasks")
        .navigationBarTitleDisplayMode(.large)
        .background(DSColors.canvasPrimary)
    }
}

struct CompletedTaskRow: View {
    let task: TaskWork
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(DSFonts.body())
                .foregroundColor(DSColors.textPrimary)
                .strikethrough()
            
            HStack(spacing: 8) {
                // Completion date
                if let completedAt = task.completedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(DSFonts.caption())
                        Text(completedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                }
                
                // Source (Plan or Journey)
                if let plan = task.plan {
                    HStack(spacing: 4) {
                        Image(systemName: plan.icon)
                            .font(DSFonts.caption())
                        Text(plan.name)
                    }
                    .font(DSFonts.caption())
                    .foregroundColor(Color(hex: plan.colorHex))
                } else if let journey = task.journey {
                    HStack(spacing: 4) {
                        Image(systemName: journey.icon)
                            .font(DSFonts.caption())
                        Text(journey.title)
                    }
                    .font(DSFonts.caption())
                    .foregroundColor(Color(hex: journey.colorHex))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(DSFonts.caption())
                        Text("Inbox")
                    }
                    .font(DSFonts.caption())
                    .foregroundColor(DSColors.textSecondary)
                }
            }
            
            // Completion reflection if exists
            if let reflection = task.completionReflection, !reflection.isEmpty {
                Text(reflection)
                    .font(DSFonts.body(13))
                    .foregroundColor(DSColors.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                modelContext.delete(task)
                try? modelContext.save()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    NavigationStack {
        CompletedTasksView()
            .modelContainer(for: [TaskWork.self, Plan.self, Journey.self], inMemory: true)
    }
}
