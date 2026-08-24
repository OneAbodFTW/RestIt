import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var reminders: ReminderManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            schedule
            Divider()
            controls
        }
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                Image(systemName: "eye.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 46, height: 46)

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

    private var schedule: some View {
        VStack(spacing: 12) {
            ReminderRow(
                icon: "eye",
                color: .mint,
                title: "Next eye break",
                value: reminders.nextEyeBreakText
            )

            ReminderRow(
                icon: "drop.fill",
                color: .blue,
                title: "Drink water",
                value: reminders.nextWaterReminderText
            )

            if reminders.lastWaterReminder != nil {
                HStack(spacing: 8) {
                    Image(systemName: "drop.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Water reminder sent")
                        .font(.caption.weight(.medium))
                    Spacer()
                    Button("Done") { reminders.recordWater() }
                        .buttonStyle(.borderless)
                    Button("10m") { reminders.snoozeWater() }
                        .buttonStyle(.borderless)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(16)
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

                Menu {
                    if reminders.isPaused {
                        Button("Resume reminders") { reminders.resume() }
                    } else {
                        Button("Pause for 30 minutes") { reminders.pause(for: 30) }
                        Button("Pause for 1 hour") { reminders.pause(for: 60) }
                        Button("Pause for 2 hours") { reminders.pause(for: 120) }
                    }
                    Divider()
                    Button("Skip next eye break") { reminders.skipNextEyeBreak() }
                    Button("I drank water") { reminders.recordWater() }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 24)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            HStack {
                Button("Settings…") { openSettings() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Quit RestIt") { NSApp.terminate(nil) }
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
        return "Healthy reminders, quietly in your menu bar"
    }
}

private struct ReminderRow: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.12), in: Circle())

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

