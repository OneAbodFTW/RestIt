import SwiftUI
import Charts

struct HabitsNeedingAttentionView: View {
    let summary: HabitConsistencySummary
    @State private var sortByGap = false

    private var ranked: [HabitConsistencyHabitImpact] {
        let habits = summary.prioritizedHabitImpacts.filter { ($0.score ?? 100) < 100 }
        return sortByGap ? habits.sorted {
            if $0.unearnedPoints != $1.unearnedPoints { return $0.unearnedPoints > $1.unearnedPoints }
            return $0.habitName.localizedCaseInsensitiveCompare($1.habitName) == .orderedAscending
        } : habits
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Habits needing attention", systemImage: "scope")
                .font(.headline)
            Text("Last 7 completed days • today is excluded")
                .font(.caption).foregroundStyle(.secondary)
            if summary.overallScore == nil {
                Text("Connect TickTick and categorize your habits to see where goals were missed.")
                    .foregroundStyle(.secondary)
            } else if ranked.isEmpty {
                Label("Every scheduled goal was met.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Picker("Rank habits by", selection: $sortByGap) {
                    Text("Lowest consistency").tag(false)
                    Text("Biggest score gap").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                ForEach(Array(ranked.prefix(5).enumerated()), id: \.element.id) { index, habit in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 16)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(habit.habitName).fontWeight(.medium)
                            Text("\(habit.missedGoalCount) of \(habit.scheduledDayCount) goals missed · \(habit.zeroProgressDayCount) no progress · \(habit.partialDayCount) partial")
                                .font(.caption).foregroundStyle(.secondary)
                            if sortByGap {
                                Text("\(habit.unearnedPoints.formatted(.number.precision(.fractionLength(1)))) unearned points toward the overall score")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 4)
                        Text("\(habit.score ?? 0)%").monospacedDigit().fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .combine)
                }
                if ranked.count > 5 {
                    DisclosureGroup("All \(ranked.count) habits below goal") {
                        ForEach(ranked.dropFirst(5)) { habit in
                            HabitConsistencyImpactRow(impact: habit, dayStamps: summary.dayStamps)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
    }
}

struct HabitWeeklyHistoryView: View {
    let snapshots: [HabitWeekSnapshot]
    @State private var selectedWeek: Int?
    @State private var selectedDate: Date?
    @State private var metric = "overall"

    private var visible: [HabitWeekSnapshot] { Array(snapshots.suffix(13)) }
    private var selected: HabitWeekSnapshot? {
        if let selectedDate, let closest = visible.min(by: {
            abs($0.startDate.timeIntervalSince(selectedDate)) < abs($1.startDate.timeIntervalSince(selectedDate))
        }) { return closest }
        return snapshots.first { $0.id == selectedWeek } ?? snapshots.last
    }

    private func score(_ snapshot: HabitWeekSnapshot) -> Int? {
        if metric == "overall" { return snapshot.summary.overallScore }
        return snapshot.summary.categoryScores.first { $0.category.rawValue == metric }?.score
    }

    private func dateRange(_ snapshot: HabitWeekSnapshot) -> String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: snapshot.endDate) ?? snapshot.endDate
        return "\(snapshot.startDate.formatted(.dateTime.month(.abbreviated).day())) – \(lastDay.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly score history", systemImage: "chart.bar.xaxis")
                .font(.headline)
            Text("Monday–Sunday · completed weeks are saved on this Mac")
                .font(.caption).foregroundStyle(.secondary)
            if snapshots.isEmpty {
                Text("Refresh TickTick after categorizing your habits to load up to 12 previous weeks and start saving snapshots.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Score", selection: $metric) {
                    Text("Overall").tag("overall")
                    ForEach(HabitConsistencyCategory.allCases) { category in
                        Text(category.name).tag(category.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Chart(visible) { snapshot in
                    if let value = score(snapshot) {
                        BarMark(x: .value("Week starting", snapshot.startDate),
                                y: .value("Score", value), width: .fixed(14))
                            .foregroundStyle(snapshot.id == selected?.id ? Color.accentColor : Color.accentColor.opacity(0.4))
                            .opacity(snapshot.isFinal ? 1 : 0.6)
                            .annotation(position: .top) {
                                Text("\(value)").font(.system(size: 9)).foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("\(dateRange(snapshot)), \(snapshot.isFinal ? "saved" : "week to date")")
                            .accessibilityValue("\(value) percent")
                    }
                }
                .chartXScale(range: .plotDimension(padding: 20))
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 25, 50, 75, 100]) }
                .chartXAxis { AxisMarks(values: .stride(by: .weekOfYear, count: 3)) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                } }
                .chartXSelection(value: $selectedDate)
                .frame(height: 170)
                Text("Latest \(visible.count) saved weeks. Select a bar or choose a week below. Missing scores are not zero.")
                    .font(.caption).foregroundStyle(.secondary)

                Picker("Inspect week", selection: Binding(
                    get: { selected?.id ?? snapshots.last!.id },
                    set: { selectedDate = nil; selectedWeek = $0 }
                )) {
                    ForEach(snapshots.reversed()) { snapshot in
                        Text(dateRange(snapshot)).tag(snapshot.id)
                    }
                }

                if let snapshot = selected {
                    snapshotDetails(snapshot)
                }
            }
        }
    }

    private func snapshotDetails(_ snapshot: HabitWeekSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dateRange(snapshot)).font(.headline)
            Text(snapshot.isFinal ? (snapshot.isReconstructed ? "Reconstructed snapshot · fixed" : "Completed snapshot · fixed") : (snapshot.endDate <= Date() ? "Incomplete snapshot · last captured before this week ended" : "Week to date · includes today’s unfinished goals"))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                scoreLabel("Overall", score: snapshot.summary.overallScore)
                ForEach(snapshot.summary.categoryScores) { category in
                    Spacer()
                    scoreLabel(category.category.name, score: category.score)
                }
            }
            Text("Captured \(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2).foregroundStyle(.secondary)
            if snapshot.isReconstructed {
                Text("Reconstructed from TickTick check-ins using the goals, schedules and categories available when captured. Deleted habits and earlier configuration changes may not be reflected.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DisclosureGroup("Habit breakdown · lowest consistency first") {
                ForEach(snapshot.summary.prioritizedHabitImpacts) { habit in
                    HabitConsistencyImpactRow(impact: habit, dayStamps: snapshot.summary.dayStamps)
                        .padding(.vertical, 6)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private func scoreLabel(_ label: String, score: Int?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(score.map { "\($0)%" } ?? "—").font(.title3.weight(.semibold)).monospacedDigit()
        }
    }
}
