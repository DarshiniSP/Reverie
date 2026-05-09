import SwiftUI
import SwiftData

struct ActivityGridView: View {
    let completionsByDay: [Date: Int]

    private let columns = 16
    private let cellSize: CGFloat = 14
    private let cellSpacing: CGFloat = 3

    private var weeks: [[Date]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let totalDays = columns * 7
        let startDate = cal.date(byAdding: .day, value: -(totalDays - 1), to: today)!

        var days: [Date] = []
        for i in 0..<totalDays {
            days.append(cal.date(byAdding: .day, value: i, to: startDate)!)
        }

        // Pad so the grid starts on Sunday
        var grid = days
        let firstWeekday = cal.component(.weekday, from: days[0]) - 1
        let leading = Array(repeating: Date.distantPast, count: firstWeekday)
        grid = leading + grid

        return stride(from: 0, to: grid.count, by: 7).map {
            Array(grid[$0..<min($0 + 7, grid.count)])
        }
    }

    private var maxCount: Int {
        completionsByDay.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(DSColors.accentPrimary)
                Text("Activity")
                    .font(DSFonts.headline())
                    .foregroundColor(DSColors.textPrimary)
                Spacer()
                legendView
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: cellSpacing) {
                    ForEach(0..<weeks.count, id: \.self) { col in
                        VStack(spacing: cellSpacing) {
                            ForEach(0..<7, id: \.self) { row in
                                let date = weeks[col][safe: row] ?? Date.distantPast
                                cellView(for: date)
                            }
                        }
                    }
                }
            }

            HStack {
                dayLabel("Sun")
                Spacer()
                dayLabel("Mon")
                Spacer()
                dayLabel("Wed")
                Spacer()
                dayLabel("Fri")
                Spacer()
                dayLabel("Sat")
            }
            .padding(.horizontal, 2)
        }
        .padding(16)
        .background(DSColors.canvasSecondary)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DSColors.divider, lineWidth: 0.5))
        .shadow(color: DSColors.shadow, radius: 10, x: 0, y: 3)
    }

    private func cellView(for date: Date) -> some View {
        let isPlaceholder = date == Date.distantPast
        let count = completionsByDay[Calendar.current.startOfDay(for: date)] ?? 0
        let intensity = isPlaceholder ? 0.0 : min(1.0, Double(count) / Double(max(1, maxCount)))
        let isToday = Calendar.current.isDateInToday(date)

        return RoundedRectangle(cornerRadius: 3)
            .fill(cellColor(intensity: intensity, isPlaceholder: isPlaceholder))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: 3).stroke(DSColors.accentPrimary, lineWidth: 1.5)
                    : nil
            )
            .opacity(isPlaceholder ? 0 : 1)
    }

    private func cellColor(intensity: Double, isPlaceholder: Bool) -> Color {
        if isPlaceholder { return .clear }
        if intensity == 0 { return DSColors.accentPrimary.opacity(0.07) }
        return DSColors.accentPrimary.opacity(0.2 + intensity * 0.8)
    }

    private var legendView: some View {
        HStack(spacing: 3) {
            Text("Less")
                .font(DSFonts.caption(10))
                .foregroundColor(DSColors.textSecondary)
            ForEach([0.1, 0.3, 0.55, 0.8, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DSColors.accentPrimary.opacity(0.1 + intensity * 0.85))
                    .frame(width: 11, height: 11)
            }
            Text("More")
                .font(DSFonts.caption(10))
                .foregroundColor(DSColors.textSecondary)
        }
    }

    private func dayLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundColor(DSColors.textSecondary)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ActivityGridCard: View {
    @Environment(\.modelContext) private var modelContext

    @State private var completionsByDay: [Date: Int] = [:]

    var body: some View {
        ActivityGridView(completionsByDay: completionsByDay)
            .onAppear { loadData() }
    }

    private func loadData() {
        let cal = Calendar.current
        let allTasks = (try? modelContext.fetch(FetchDescriptor<TaskWork>())) ?? []
        var map: [Date: Int] = [:]
        for task in allTasks {
            guard let completed = task.completedAt else { continue }
            let day = cal.startOfDay(for: completed)
            map[day, default: 0] += 1
        }
        completionsByDay = map
    }
}
