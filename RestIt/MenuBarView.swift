import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var reminders: ReminderManager

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

            if reminders.isPaused {
                Text("PAUSED")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(16)
    }

    private var nextBreak: some View {
        HStack(spacing: 11) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.mint)
                .frame(width: 30, height: 30)
                .background(Color.mint.opacity(0.12), in: Circle())

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

            HStack(spacing: 10) {
                SummaryTile(
                    icon: "eye.slash.fill",
                    color: .mint,
                    value: "\(reminders.restsToday)",
                    label: "Completed rests"
                )

                SummaryTile(
                    icon: "clock.fill",
                    color: .orange,
                    value: reminders.workedTimeText,
                    label: "Active work"
                )
            }

            habitDashboard
        }
        .padding(16)
    }

    private var consistencyDashboard: some View {
        let summary = reminders.habitConsistencySummary

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("28-day consistency", systemImage: "chart.line.uptrend.xyaxis")
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
            }
        }
        .padding(16)
    }

    private var habitDashboard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TickTick habits", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)

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
                        .foregroundStyle(.purple)

                    if reminders.selectedEyeDropsHabits.isEmpty {
                        HabitQuickAction(
                            title: "Eye drops",
                            icon: "eyedropper.halffull",
                            color: .purple,
                            habit: nil,
                            isWorking: false,
                            buttonTitle: "Check",
                            disableWhenComplete: true,
                            action: {}
                        )
                    } else {
                        ForEach(reminders.selectedEyeDropsHabits) { habit in
                            HabitQuickAction(
                                title: habit.name,
                                icon: "eyedropper.halffull",
                                color: .purple,
                                habit: habit,
                                isWorking: reminders.isCheckingHabit(habit),
                                buttonTitle: "Check",
                                disableWhenComplete: true,
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
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    reminders.startEyeBreakNow()
                } label: {
                    Label("Rest now", systemImage: "eye.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(reminders.isEyeBreakActive)

                if reminders.isPaused {
                    Button("Resume") {
                        reminders.resume()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Pause 30m") {
                        reminders.pause(for: 30)
                    }
                    .buttonStyle(.bordered)
                }
            }

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
        }
        .padding(16)
    }

    private var statusSubtitle: String {
        if reminders.isPaused { return reminders.nextEyeBreakText }
        if reminders.isEyeBreakActive { return "A short break is in progress" }
        return "Eye rests and focused work time"
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
        case .religious: .indigo
        case .selfCare: .pink
        case .contribution: .teal
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
