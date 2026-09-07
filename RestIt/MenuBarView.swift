import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var reminders: ReminderManager
    @State private var isShowingConsistencyInfo = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            nextBreak
            Divider()
            consistencyDashboard
            Divider()
            todayDashboard
            Divider()
            controls
        }
        .frame(width: 350)
        .tint(Color.accentColor)
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
                        Text("See what’s affecting your score")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .help("Compare each habit’s 7-day score and effect")
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

                    Button {
                        Task { await reminders.syncTickTickHabits(showSuccess: false) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(reminders.isTickTickSyncing)
                    .help("Sync TickTick habits")
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
    let summary: HabitConsistencySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What’s affecting your score", systemImage: "scope")
                .font(.headline)

            Text("Habit score is average progress on scheduled days. Effect compares your overall score with that habit left out.")
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(summary.prioritizedHabitImpacts.enumerated()), id: \.element.id) { index, impact in
                        HabitConsistencyImpactRow(impact: impact)
                            .padding(.vertical, 8)

                        if index < summary.prioritizedHabitImpacts.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 280)

            Divider()

            Text("Negative effects show the clearest room to improve. Effects are not additive because habits share daily and category averages.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 340, alignment: .leading)
        .padding(16)
    }
}

struct HabitConsistencyImpactRow: View {
    let impact: HabitConsistencyHabitImpact

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: impact.category.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(impact.habitName)
                    .lineLimit(1)

                Text("\(impact.category.name) · \(scheduledDaysText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(impact.score.map { "\($0)%" } ?? "—")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()

                Label(effectText, systemImage: effectIcon)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(effectColor)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var scheduledDaysText: String {
        "\(impact.scheduledDayCount) scheduled day\(impact.scheduledDayCount == 1 ? "" : "s")"
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
