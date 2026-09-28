import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var reminders: ReminderManager
    @State private var isShowingConsistencyInfo = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    TickTickRefreshControls()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    Divider()
                    nextBreak
                    Divider()
                    consistencyDashboard
                    Divider()
                    todayDashboard
                }
            }
            Divider()
            controls
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 350, height: menuHeight)
        .tint(Color.accentColor)
    }

    private var menuHeight: CGFloat {
        // Use the display where the menu is opened, leaving room for the popover edges.
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
            ?? NSScreen.main
        return min(600, max(0, (screen?.visibleFrame.height ?? 700) - 32))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))

            VStack(alignment: .leading, spacing: 3) {
                Text("RestIt")
                    .font(.headline)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
    }

    private var nextBreak: some View {
        HStack(spacing: 11) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text("Next eye break")
                .font(.subheadline)

            Spacer()

            Text(reminders.nextEyeBreakText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var todayDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Resets daily")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            SummaryTile(
                icon: "eye.slash.fill",
                color: Color.accentColor,
                value: "\(reminders.restsToday)",
                label: "Completed rests"
            )

            habitDashboard
        }
        .padding(16)
    }

    private var consistencyDashboard: some View {
        let summary = reminders.habitConsistencySummary

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("7-day consistency", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let overall = summary.overallScore {
                    Text("\(overall)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !reminders.isTickTickConnected {
                HStack {
                    Text("Connect TickTick to see your habit scores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Connect…", action: showSettings)
                        .font(.caption)
                }
            } else if summary.configuredHabitCount == 0 {
                HStack {
                    Text("Categorize habits to build your score.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Set up…", action: showSettings)
                        .font(.caption)
                }
            } else {
                ForEach(summary.categoryScores) { metric in
                    ConsistencyRow(metric: metric)
                }

                Button {
                    isShowingConsistencyInfo.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "scope")
                        Text("Habit insights & weekly history")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .help("See each habit’s consistency and completed days over the last week")
                .popover(isPresented: $isShowingConsistencyInfo, arrowEdge: .bottom) {
                    HabitImpactPopover(summary: summary)
                }
            }
        }
        .padding(16)
    }

    private var habitDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TickTick habits", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                if reminders.isTickTickConnected {
                    Text("\(reminders.incompleteTickTickHabits.count) due")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                }
            }

            if reminders.isTickTickConnected {
                HabitQuickAction(
                    title: "Water",
                    icon: "drop.fill",
                    color: .blue,
                    habit: reminders.selectedWaterHabit,
                    isWorking: reminders.selectedWaterHabit.map(reminders.isCheckingHabit) ?? false,
                    buttonTitle: "Log",
                    disableWhenComplete: false,
                    action: reminders.logWaterHabit
                )
                .disabled(reminders.isTickTickSyncing || !reminders.checkingHabitIDs.isEmpty)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Eye drops", systemImage: "eyedropper.halffull")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    if reminders.selectedEyeDropsHabits.isEmpty {
                        HabitQuickAction(
                            title: "Eye drops",
                            icon: "eyedropper.halffull",
                            color: Color.accentColor,
                            habit: nil,
                            isWorking: false,
                            buttonTitle: "Log",
                            disableWhenComplete: false,
                            action: {}
                        )
                    } else {
                        ForEach(reminders.selectedEyeDropsHabits) { habit in
                            HabitQuickAction(
                                title: habit.name,
                                icon: "eyedropper.halffull",
                                color: Color.accentColor,
                                habit: habit,
                                isWorking: reminders.isCheckingHabit(habit),
                                buttonTitle: "Log",
                                disableWhenComplete: false,
                                action: { reminders.checkEyeDropsHabit(habit) }
                            )
                            .disabled(reminders.isTickTickSyncing || !reminders.checkingHabitIDs.isEmpty)
                        }
                    }
                }

                if reminders.selectedWaterHabit == nil || reminders.selectedEyeDropsHabits.isEmpty {
                    Button(action: showSettings) {
                        Label("Link habits in Settings", systemImage: "link")
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text("Connect TickTick to log water and eye drops.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: showSettings) {
                        Text("Connect…")
                    }
                        .font(.caption)
                }
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var controls: some View {
        HStack {
            Button("Skip next rest") {
                reminders.skipNextEyeBreak()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: showSettings) {
                Text("Settings…")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(16)
    }

    private var statusSubtitle: String {
        if reminders.isEyeBreakActive { return "A short break is in progress" }
        return "Eye-rest reminders and healthy habits"
    }

    private func showSettings() {
        SettingsWindowController.shared.show(reminders: reminders)
    }
}

struct TickTickRefreshControls: View {
    @EnvironmentObject private var reminders: ReminderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await reminders.syncTickTickHabits() }
            } label: {
                HStack(spacing: 8) {
                    Label(reminders.isTickTickSyncing ? "Refreshing TickTick…" : "Refresh all TickTick habits",
                          systemImage: "arrow.clockwise")
                    Spacer(minLength: 0)
                    if reminders.isTickTickSyncing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!reminders.isTickTickConnected || reminders.isTickTickSyncing || !reminders.checkingHabitIDs.isEmpty)
            .help("Refetch all TickTick habits and 13 weeks of check-ins, updating current progress and saving weekly snapshots.")

            if reminders.isTickTickSyncing {
                Text("Fetching habits and the last 7 days of check-ins…")
                    .foregroundStyle(.secondary)
            } else if let status = reminders.tickTickStatusMessage {
                Label(status, systemImage: reminders.tickTickStatusIsError
                      ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .foregroundStyle(reminders.tickTickStatusIsError ? Color.red : .secondary)
                    .lineLimit(2)
                    .help(status)
            } else {
                Text(reminders.isTickTickConnected
                     ? "Refreshes all habits and the last 7 days of check-ins."
                     : "Connect TickTick in Settings to refresh your habits.")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConsistencyRow: View {
    let metric: HabitConsistencyCategoryScore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.category.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 18)

            Text(metric.category.name)
                .font(.caption)
                .frame(width: 72, alignment: .leading)

            ProgressView(value: Double(metric.score ?? 0), total: 100)
                .tint(color)
                .opacity(metric.score == nil ? 0.35 : 1)

            Text(metric.score.map { "\($0)" } ?? "—")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(metric.score == nil ? .secondary : .primary)
                .frame(width: 26, alignment: .trailing)
        }
    }

    private var color: Color {
        switch metric.category {
        case .religious: Color.accentColor
        case .selfCare: .cyan
        }
    }
}

private struct HabitImpactPopover: View {
    @EnvironmentObject private var reminders: ReminderManager
    let summary: HabitConsistencySummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HabitsNeedingAttentionView(summary: reminders.habitsNeedingAttention)
                Divider()
                HabitWeeklyHistoryView(snapshots: reminders.weeklySnapshots)
                Divider()
                HabitConsistencyScoreCalculation(summary: summary)

                Divider()

                Text("Your habits this week")
                    .font(.headline)

                Text("Each row shows the last 7 days. Partial progress earns partial credit; days off are ignored.")
                    .foregroundStyle(.secondary)

                ForEach(summary.prioritizedHabitImpacts) { impact in
                    HabitConsistencyImpactRow(impact: impact, dayStamps: summary.dayStamps)
                    Divider()
                }

                DisclosureGroup("How weekly consistency is calculated") {
                    HabitConsistencyFormulaExplanation()
                        .padding(.top, 6)
                }
            }
            .padding(16)
        }
        .font(.caption)
        .frame(width: 440, height: 560)
    }
}

struct HabitConsistencyScoreCalculation: View {
    let summary: HabitConsistencySummary
    @State private var isShowingWeighting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly consistency")
                        .font(.headline)
                    Text("Last \(summary.days) days · includes today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(summary.overallScore.map { "\($0)%" } ?? "—")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }

            ForEach(summary.categoryScores) { metric in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(metric.category.name, systemImage: metric.category.icon)
                        Text("\(metric.habitCount) habits")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let score = metric.score {
                        Text("\(score)%")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("No scheduled data · excluded")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }

            if let points = summary.totalHabitPoints, let adjustment = summary.roundingAdjustment,
               let overall = summary.overallScore {
                DisclosureGroup("Score weighting details", isExpanded: $isShowingWeighting) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(summary.categoryScores) { metric in
                            if let score = metric.score {
                                Text("\(metric.category.name): \(score) × \(100 / summary.scoredCategoryCount)% = \(consistencyPoints(Double(score) / Double(summary.scoredCategoryCount))) points")
                            }
                        }
                        Text("\(consistencyPoints(points)) habit points \(adjustment < 0 ? "−" : "+") \(consistencyPoints(abs(adjustment))) rounding → \(overall)%")
                            .fontWeight(.semibold)
                        Text("Points are shares of the 100-point total, not days. Each category is rounded first, then their average is rounded to the final score.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
            } else {
                Text("A score appears when a categorized habit has a scheduled day in this window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct HabitConsistencyFormulaExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("How it’s calculated")
                .font(.subheadline.weight(.semibold))
            Text("1. Daily progress: recorded amount ÷ goal, capped at 100%. A completed check-in gets 100%.")
            Text("2. Habit consistency: average progress across that habit’s scheduled days.")
            Text("3. Category score: average the habits due each day, then average those daily results.")
            Text("4. Overall score: average the rounded category scores, giving each category with data equal weight, then round again.")
            Text("A habit’s point share depends on how many habits are due alongside it each day. Its consistency percentage alone is not its weight in the final score.")
            Text("Today uses progress so far. A scheduled day without a check-in counts as 0%; unscheduled days, uncategorized habits, and categories without scheduled data are excluded.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HabitConsistencyImpactRow: View {
    let impact: HabitConsistencyHabitImpact
    let dayStamps: [Int]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: impact.category.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(categoryColor)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(impact.habitName)
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(impact.category.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(impact.score.map { "\($0)%" } ?? "—")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("Consistency")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            weeklyHistory

            if impact.score != nil {
                HStack {
                    Text("\(impact.completedDayCount) of \(impact.scheduledDayCount) \(impact.scheduledDayCount == dayStamps.count ? "days" : "scheduled days") met goal")
                        .fontWeight(.semibold)
                    Spacer()
                    if impact.partialDayCount > 0 {
                        Text("\(impact.partialDayCount) partial")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                DisclosureGroup("Score contribution details", isExpanded: $isExpanded) {
                    dailyCalculation
                        .padding(.top, 6)
                }
                .font(.caption)
            } else {
                Text("No scheduled days in this window. This habit contributes no points and does not affect the score.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weeklyHistory: some View {
        HStack(spacing: 6) {
            ForEach(dayStamps, id: \.self) { stamp in
                let day = impact.dayContributions.first { $0.stamp == stamp }
                let date = date(for: stamp)
                let status = day.map { $0.progress >= 1 ? "Goal met" : $0.progress > 0 ? "Partial progress" : "Not completed" }
                    ?? "No scheduled data"
                let icon = day.map { $0.progress >= 1 ? "checkmark.circle.fill" : $0.progress > 0 ? "circle.lefthalf.filled" : "circle" }
                    ?? "minus"

                VStack(spacing: 5) {
                    Text(date?.formatted(.dateTime.weekday(.abbreviated)) ?? "—")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(day.map { $0.progress > 0 ? categoryColor : .secondary } ?? .secondary)
                    Text("\(stamp % 100)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                .help("\(dateText(stamp)): \(status)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(dateText(stamp)): \(status)")
            }
        }
    }

    private var dailyCalculation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly consistency averages progress on the \(impact.scheduledDayCount) scheduled days shown above. Partial days count proportionally.")

            if let points = impact.overallPoints, let possible = impact.possibleOverallPoints {
                Text("Contribution: \(consistencyPoints(points)) of \(consistencyPoints(possible)) possible points toward the overall score. These are weighted points, not a number of days.")
            }

            if let day = impact.dayContributions.first {
                Text("Daily points: progress × 100 ÷ habits due in \(impact.category.name) ÷ \(day.categoryDayCount) scored days ÷ \(day.scoredCategoryCount) scored categories.")
            }

            ForEach(impact.dayContributions) { day in
                HStack(alignment: .firstTextBaseline) {
                    Text(dateText(day.stamp))
                    Spacer(minLength: 8)
                    Text("\(consistencyPoints(day.progress * 100)) ÷ \(day.scheduledHabitCount) ÷ \(day.categoryDayCount) ÷ \(day.scoredCategoryCount) = \(consistencyPoints(day.overallPoints)) pts")
                        .monospacedDigit()
                }
                .font(.caption2)
            }

            Text("Possible points use 100% progress on every scheduled day with the same schedule and weights.")

            Divider()

            if let without = impact.overallScoreWithoutHabit {
                HStack {
                    Text("Overall without this habit: \(without) / 100")
                    Spacer()
                    Label(effectText, systemImage: effectIcon)
                        .foregroundStyle(effectColor)
                }
                Text("This comparison recalculates the averages after removing the habit. These effects do not add up to the total.")
            } else {
                Text("This is the only habit with scheduled data. Removing it leaves no overall score.")
            }
        }
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func date(for stamp: Int) -> Date? {
        DateComponents(calendar: Calendar(identifier: .gregorian), year: stamp / 10_000,
                       month: (stamp / 100) % 100, day: stamp % 100).date
    }

    private func dateText(_ stamp: Int) -> String {
        date(for: stamp)?.formatted(.dateTime.month(.abbreviated).day()) ?? String(stamp)
    }

    private var effectText: String {
        guard let value = impact.overallScoreImpact else {
            return impact.score == nil ? "No data" : "Sets score"
        }
        let pointLabel = abs(value) == 1 ? "pt" : "pts"
        if value > 0 { return "Lifts +\(value) \(pointLabel)" }
        if value < 0 { return "Lowers \(abs(value)) \(pointLabel)" }
        return "No change"
    }

    private var effectIcon: String {
        guard let value = impact.overallScoreImpact else { return "minus" }
        if value > 0 { return "arrow.up.right" }
        if value < 0 { return "arrow.down.right" }
        return "equal"
    }

    private var effectColor: Color {
        guard let value = impact.overallScoreImpact else { return .secondary }
        if value > 0 { return .green }
        if value < 0 { return .orange }
        return .secondary
    }

    private var categoryColor: Color {
        switch impact.category {
        case .religious: Color.accentColor
        case .selfCare: .cyan
        }
    }
}

private func consistencyPoints(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(2)))
}

private struct SummaryTile: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct HabitQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let habit: TickTickHabit?
    let isWorking: Bool
    let buttonTitle: String
    let disableWhenComplete: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(habit?.name ?? title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(habit?.progressText ?? "Not linked")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if habit?.isCompletedToday == true {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            Button {
                action()
            } label: {
                if isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Text(habit?.isCompletedToday == true && disableWhenComplete ? "Done" : buttonTitle)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(habit == nil || isWorking || (disableWhenComplete && habit?.isCompletedToday == true))
        }
    }
}
