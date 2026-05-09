//
//  LockScreenWidget.swift
//  iAllyWidget
//
//  P4-B: Lock Screen and accessory-family widgets for iPhone / iPad lock screen.
//
//  Supported families:
//    .accessoryCircular   — task count ring
//    .accessoryRectangular — today summary: tasks + overdue + focus task
//    .accessoryInline     — single-line status
//
//  Data source: same TaskTimelineProvider used by the home screen widgets,
//  reading from the shared App Group UserDefaults + SwiftData.
//

import WidgetKit
import SwiftUI

// MARK: - P4-B: Lock Screen Widget

struct LockScreenWidget: Widget {
    let kind: String = "iAllyLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaskTimelineProvider()) { entry in
            LockScreenWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("iAlly Lock Screen")
        .description("See today's tasks, overdue count, and Lumina focus at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Lock Screen Widget Views

struct LockScreenWidgetEntryView: View {
    var entry: TaskTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {

        // ● Circular: task count badge
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(entry.todayTasks.count)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
            .accessibilityLabel("iAlly: \(entry.todayTasks.count) tasks today")

        // ▬ Rectangular: summary line + focus task
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                    Text("iAlly")
                        .font(.caption2.bold())
                }
                HStack(spacing: 6) {
                    Label("\(entry.todayTasks.count)", systemImage: "calendar")
                        .font(.caption2)
                    if !entry.overdueTasks.isEmpty {
                        Label("\(entry.overdueTasks.count) overdue", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                if let focus = entry.luminaFocusTask, !focus.isEmpty {
                    Text(focus)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("lockScreenRectangularWidget")

        // — Inline: single-line summary
        case .accessoryInline:
            Label(
                "\(entry.todayTasks.count) tasks · \(entry.overdueTasks.count) overdue",
                systemImage: "checkmark.circle.fill"
            )

        default:
            Text("\(entry.todayTasks.count)")
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    LockScreenWidget()
} timeline: {
    TaskEntry(
        date: Date(),
        todayTasks: [
            TaskWidgetData(id: UUID(), title: "Review proposal", isOverdue: false, size: "Medium", dueDate: Date()),
            TaskWidgetData(id: UUID(), title: "Team meeting", isOverdue: false, size: "Small", dueDate: Date())
        ],
        overdueTasks: [
            TaskWidgetData(id: UUID(), title: "Submit invoice", isOverdue: true, size: "Small", dueDate: Date().addingTimeInterval(-86400))
        ],
        completedCount: 3,
        luminaInsight: nil,
        luminaFocusTask: "Review proposal"
    )
}
