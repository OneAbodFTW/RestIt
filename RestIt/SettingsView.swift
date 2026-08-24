import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var reminders: ReminderManager

    private let eyeIntervals = [20, 30, 45, 60]
    private let breakDurations = [20, 30, 60]
    private let waterIntervals = [30, 45, 60, 90, 120]

    var body: some View {
        Form {
            Section {
                Toggle("Eye-break reminders", isOn: $reminders.eyeRemindersEnabled)

                Picker("Remind me every", selection: $reminders.eyeIntervalMinutes) {
                    ForEach(eyeIntervals, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
                .disabled(!reminders.eyeRemindersEnabled)

                Picker("Break duration", selection: $reminders.eyeBreakSeconds) {
                    ForEach(breakDurations, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .disabled(!reminders.eyeRemindersEnabled)
            } header: {
                Label("Eyes", systemImage: "eye")
            } footer: {
                Text("The default follows the 20-20 rhythm: rest every 20 minutes for 20 seconds.")
            }

            Section {
                Toggle("Water reminders", isOn: $reminders.waterRemindersEnabled)

                Picker("Remind me every", selection: $reminders.waterIntervalMinutes) {
                    ForEach(waterIntervals, id: \.self) { minutes in
                        Text(intervalLabel(minutes)).tag(minutes)
                    }
                }
                .disabled(!reminders.waterRemindersEnabled)

                Button("Allow notifications") {
                    reminders.requestNotificationPermission()
                }
                .disabled(!reminders.waterRemindersEnabled)
            } header: {
                Label("Water", systemImage: "drop")
            } footer: {
                Text("Water reminders are delivered through macOS notifications.")
            }

            Section {
                Toggle("Audio cues", isOn: $reminders.audioCuesEnabled)

                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: $reminders.audioCueVolume, in: 0.1...1)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
                .disabled(!reminders.audioCuesEnabled)

                Button("Preview sound") {
                    reminders.previewAudioCue()
                }
                .disabled(!reminders.audioCuesEnabled)
            } header: {
                Label("Sound", systemImage: "speaker.wave.2")
            } footer: {
                Text("A gentle cue plays when a break starts, when it ends, and when it is time for water.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 590)
        .navigationTitle("RestIt Settings")
    }

    private func intervalLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        if minutes == 60 { return "1 hour" }
        if minutes % 60 == 0 { return "\(minutes / 60) hours" }
        return "1 hour \(minutes - 60) minutes"
    }
}
