//
//  iAllyWidget.swift
//  iAlly
//
//  Created on 12/11/2025.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Widget Entry
struct TaskEntry: TimelineEntry {
    let date: Date
    let todayTasks: [TaskWidgetData]
    let overdueTasks: [TaskWidgetData]
    let completedCount: Int
    // Phase 4: Lumina AI insight from ProactiveIntelligenceEngine via shared UserDefaults
    let luminaInsight: String?
    let luminaFocusTask: String?
}

// MARK: - Lightweight Task Data for Widget
struct TaskWidgetData: Identifiable {
    let id: UUID
    let title: String
    let isOverdue: Bool
    let size: String
    let dueDate: Date?
}

// MARK: - Timeline Provider
struct TaskTimelineProvider: TimelineProvider {
    typealias Entry = TaskEntry
    
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(
            date: Date(),
            todayTasks: [
                TaskWidgetData(id: UUID(), title: "Review project proposal", isOverdue: false, size: "Medium", dueDate: Date()),
                TaskWidgetData(id: UUID(), title: "Team meeting prep", isOverdue: false, size: "Small", dueDate: Date())
            ],
            overdueTasks: [],
            completedCount: 3,
            luminaInsight: "Focus on what matters most today.",
            luminaFocusTask: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        // In snapshot mode show a rich placeholder with a Lumina insight
        let entry = TaskEntry(
            date: Date(),
            todayTasks: [
                TaskWidgetData(id: UUID(), title: "Review project proposal", isOverdue: false, size: "Medium", dueDate: Date()),
                TaskWidgetData(id: UUID(), title: "Team meeting prep", isOverdue: false, size: "Small", dueDate: Date())
            ],
            overdueTasks: [],
            completedCount: 3,
            luminaInsight: "Focus on what matters most today.",
            luminaFocusTask: "Review project proposal"
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        // Fetch tasks from SwiftData
        let tasks = fetchTodayTasks()
        let overdue = fetchOverdueTasks()
        let completed = fetchCompletedTodayCount()

        // Phase 4: Read Lumina insight from shared app group (written by ProactiveIntelligenceEngine)
        let appGroup = UserDefaults(suiteName: "group.Irigam-Innovations.iAlly")
        let luminaInsight = appGroup?.string(forKey: "lumina.widget.insight")
        let luminaFocusTask = appGroup?.string(forKey: "lumina.widget.focusTask")

        let entry = TaskEntry(
            date: Date(),
            todayTasks: tasks,
            overdueTasks: overdue,
            completedCount: completed,
            luminaInsight: luminaInsight,
            luminaFocusTask: luminaFocusTask
        )

        // Refresh every 15 minutes in production
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }
    
    // MARK: - Data Fetching
    private func fetchTodayTasks() -> [TaskWidgetData] {
        guard let modelContainer = try? ModelContainer(
            for: TaskWork.self,
            configurations: ModelConfiguration(
                schema: Schema([TaskWork.self]),
                groupContainer: .identifier("group.Irigam-Innovations.iAlly")
            )
        ) else {
            return []
        }
        
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let descriptor = FetchDescriptor<TaskWork>(
            predicate: #Predicate<TaskWork> { task in
                task.completedAt == nil &&
                task.dueDate != nil &&
                task.dueDate! >= today &&
                task.dueDate! < tomorrow
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        guard let tasks = try? context.fetch(descriptor) else {
            return []
        }
        
        return tasks.prefix(5).map { task in
            TaskWidgetData(
                id: task.id,
                title: task.title,
                isOverdue: false,
                size: task.size.rawValue,
                dueDate: task.dueDate
            )
        }
    }
    
    private func fetchOverdueTasks() -> [TaskWidgetData] {
        guard let modelContainer = try? ModelContainer(
            for: TaskWork.self,
            configurations: ModelConfiguration(
                schema: Schema([TaskWork.self]),
                groupContainer: .identifier("group.Irigam-Innovations.iAlly")
            )
        ) else {
            return []
        }
        
        let context = ModelContext(modelContainer)
        let now = Date()
        
        let descriptor = FetchDescriptor<TaskWork>(
            predicate: #Predicate<TaskWork> { task in
                task.completedAt == nil &&
                task.dueDate != nil &&
                task.dueDate! < now
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        
        guard let tasks = try? context.fetch(descriptor) else {
            return []
        }
        
        return tasks.prefix(3).map { task in
            TaskWidgetData(
                id: task.id,
                title: task.title,
                isOverdue: true,
                size: task.size.rawValue,
                dueDate: task.dueDate
            )
        }
    }
    
    private func fetchCompletedTodayCount() -> Int {
        guard let modelContainer = try? ModelContainer(
            for: TaskWork.self,
            configurations: ModelConfiguration(
                schema: Schema([TaskWork.self]),
                groupContainer: .identifier("group.Irigam-Innovations.iAlly")
            )
        ) else {
            return 0
        }
        
        let context = ModelContext(modelContainer)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let descriptor = FetchDescriptor<TaskWork>(
            predicate: #Predicate<TaskWork> { task in
                task.completedAt != nil &&
                task.completedAt! >= today &&
                task.completedAt! < tomorrow
            }
        )
        
        guard let tasks = try? context.fetch(descriptor) else {
            return 0
        }
        
        return tasks.count
    }
}

// MARK: - Widget Views
struct SmallWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.todayTasks.count)")
                        .font(.system(size: 36, weight: .bold))
                    Text("tasks today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if entry.completedCount > 0 {
                    HStack {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                        Text("\(entry.completedCount) done")
                            .font(.caption2)
                        Spacer()
                    }
                    .foregroundColor(.green)
                }
            }
            .padding()
        }
    }
}

struct MediumWidgetView: View {
    let entry: TaskEntry

    var body: some View {
        ZStack {
            Color(.systemBackground)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.headline)
                        Text("\(entry.todayTasks.count) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if entry.completedCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("\(entry.completedCount)")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.green)
                    }
                }

                // Task List
                if entry.todayTasks.isEmpty {
                    Text("No tasks scheduled")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.todayTasks.prefix(2)) { task in
                            HStack(spacing: 8) {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(width: 16, height: 16)
                                Text(task.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                sizeIndicator(task.size)
                            }
                        }
                    }
                }

                // Phase 4: Lumina AI insight strip
                if let insight = entry.luminaInsight, !insight.isEmpty {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                        Text(insight)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
        }
    }
    
    func sizeIndicator(_ size: String) -> some View {
        let icon: String
        let color: Color
        
        switch size {
        case "Small":
            icon = "circle.fill"
            color = .green
        case "Large":
            icon = "circle.hexagongrid.fill"
            color = .orange
        default:
            icon = "circle.circle.fill"
            color = .blue
        }
        
        return Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(color)
    }
}

struct LargeWidgetView: View {
    let entry: TaskEntry
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
            
            VStack(alignment: .leading, spacing: 12) {
                // Header with stats
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Tasks")
                            .font(.headline)
                        HStack(spacing: 12) {
                            Label("\(entry.todayTasks.count) due", systemImage: "calendar")
                            if !entry.overdueTasks.isEmpty {
                                Label("\(entry.overdueTasks.count) overdue", systemImage: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if entry.completedCount > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(entry.completedCount)")
                                    .font(.title3.bold())
                            }
                            .foregroundColor(.green)
                            Text("completed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Divider()
                
                // Overdue tasks (if any)
                if !entry.overdueTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                        
                        ForEach(entry.overdueTasks.prefix(2)) { task in
                            taskRow(task, isOverdue: true)
                        }
                    }
                    
                    Divider()
                }
                
                // Today's tasks
                if entry.todayTasks.isEmpty {
                    Text("No tasks scheduled for today")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Due Today", systemImage: "calendar")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        
                        ForEach(entry.todayTasks.prefix(4)) { task in
                            taskRow(task, isOverdue: false)
                        }
                        
                        if entry.todayTasks.count > 4 {
                            Text("+\(entry.todayTasks.count - 4) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 24)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    func taskRow(_ task: TaskWidgetData, isOverdue: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .stroke(isOverdue ? Color.red : Color.blue, lineWidth: 2)
                .frame(width: 16, height: 16)
            
            Text(task.title)
                .font(.subheadline)
                .lineLimit(1)
            
            Spacer()
            
            sizeIndicator(task.size)
        }
    }
    
    func sizeIndicator(_ size: String) -> some View {
        let icon: String
        let color: Color
        
        switch size {
        case "Small":
            icon = "circle.fill"
            color = .green
        case "Large":
            icon = "circle.hexagongrid.fill"
            color = .orange
        default:
            icon = "circle.circle.fill"
            color = .blue
        }
        
        return Image(systemName: icon)
            .font(.caption2)
            .foregroundColor(color)
    }
}

// MARK: - Widget Configuration
struct iAllyWidget: Widget {
    let kind: String = "iAllyWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                iAllyWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                iAllyWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Today's Tasks")
        .description("See your tasks for today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct iAllyWidgetEntryView: View {
    var entry: TaskTimelineProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    iAllyWidget()
} timeline: {
    TaskEntry(
        date: Date(),
        todayTasks: [
            TaskWidgetData(id: UUID(), title: "Review project proposal", isOverdue: false, size: "Medium", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Team meeting", isOverdue: false, size: "Small", dueDate: Date())
        ],
        overdueTasks: [],
        completedCount: 3,
        luminaInsight: nil,
        luminaFocusTask: nil
    )
}

#Preview(as: .systemMedium) {
    iAllyWidget()
} timeline: {
    TaskEntry(
        date: Date(),
        todayTasks: [
            TaskWidgetData(id: UUID(), title: "Review project proposal", isOverdue: false, size: "Medium", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Team meeting", isOverdue: false, size: "Small", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Code review", isOverdue: false, size: "Large", dueDate: Date())
        ],
        overdueTasks: [],
        completedCount: 5,
        luminaInsight: "Your energy peaks late morning — schedule your most important work now.",
        luminaFocusTask: "Review project proposal"
    )
}

#Preview(as: .systemLarge) {
    iAllyWidget()
} timeline: {
    TaskEntry(
        date: Date(),
        todayTasks: [
            TaskWidgetData(id: UUID(), title: "Review project proposal", isOverdue: false, size: "Medium", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Team meeting", isOverdue: false, size: "Small", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Code review", isOverdue: false, size: "Large", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Write documentation", isOverdue: false, size: "Medium", dueDate: Date())
        ],
        overdueTasks: [
            TaskWidgetData(id: UUID(), title: "Submit timesheet", isOverdue: true, size: "Small", dueDate: Date().addingTimeInterval(-86400))
        ],
        completedCount: 7,
        luminaInsight: "Your journey 'Learn Swift' hasn't had activity in 5 days — a small step today keeps momentum.",
        luminaFocusTask: "Review project proposal"
    )
}
