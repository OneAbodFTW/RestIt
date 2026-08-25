import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var reminders: ReminderManager
    @State private var tickTickToken = ""
    @State private var habitSearch = ""
    @State private var consistencySearch = ""

    private let eyeIntervals = [20, 30, 45, 60]
    private let breakDurations = [20, 30, 60]

    var body: some View {
        TabView {
            reminderSettings
                .tabItem { Label("Reminders", systemImage: "eye") }

            tickTickSettings
                .tabItem { Label("TickTick Habits", systemImage: "checkmark.circle") }

            consistencySettings
                .tabItem { Label("Consistency", systemImage: "chart.line.uptrend.xyaxis") }

            soundSettings
                .tabItem { Label("Sound", systemImage: "speaker.wave.2") }
        }
        .frame(width: 560, height: 520)
        .navigationTitle("RestIt Settings")
    }

    private var reminderSettings: some View {
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
                Label("Eye Breaks", systemImage: "eye")
            } footer: {
                Text("The full-screen break also shows TickTick habits that are still due today.")
            }

            Section {
                LabeledContent("Rests") {
                    Text("\(reminders.restsToday)").monospacedDigit()
                }
                LabeledContent("Active work") {
                    Text(reminders.workedTimeText).monospacedDigit()
                }
            } header: {
                Label("Today", systemImage: "chart.bar")
            } footer: {
                Text("Daily totals persist between launches and reset at local midnight.")
            }
        }
        .formStyle(.grouped)
    }

    private var tickTickSettings: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Label(
                        reminders.isTickTickConnected ? "Connected" : "Not connected",
                        systemImage: reminders.isTickTickConnected ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(reminders.isTickTickConnected ? .green : .secondary)
                }

                SecureField("TickTick API token", text: $tickTickToken)
                    .textContentType(.password)

                HStack {
                    Button(reminders.isTickTickConnected ? "Replace token" : "Connect and load habits") {
                        let token = tickTickToken
                        Task {
                            await reminders.connectTickTick(token: token)
                            if reminders.isTickTickConnected { tickTickToken = "" }
                        }
                    }
                    .disabled(tickTickToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reminders.isTickTickSyncing)

                    if reminders.isTickTickConnected {
                        Button("Sync now") {
                            Task { await reminders.syncTickTickHabits() }
                        }
                        .disabled(reminders.isTickTickSyncing)

                        Button("Disconnect", role: .destructive) {
                            reminders.disconnectTickTick()
                        }
                    }

                    if reminders.isTickTickSyncing {
                        ProgressView().controlSize(.small)
                    }
                }
            } header: {
                Label("Connection", systemImage: "link")
            } footer: {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Create a token in TickTick Web → Settings → Account → API Token. RestIt keeps it in macOS Keychain and sends it only to TickTick’s official MCP server.")
                    Link(
                        "TickTick’s API-token instructions",
                        destination: URL(string: "https://help.ticktick.com/articles/7438129581631995904")!
                    )
                }
            }

            Section {
                Picker("Water intake", selection: $reminders.selectedWaterHabitID) {
                    Text("Not linked").tag("")
                    ForEach(reminders.tickTickHabits) { habit in
                        Text(habit.name).tag(habit.id)
                    }
                }

                HStack {
                    Label("Eye drops", systemImage: "eyedropper.halffull")
                        .foregroundStyle(.purple)
                    Spacer()
                    Text(eyeDropsSelectionLabel)
                        .foregroundStyle(.secondary)
                }

                TextField("Search all habits", text: $habitSearch)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredHabits.isEmpty {
                            Text(reminders.tickTickHabits.isEmpty ? "No habits loaded" : "No matching habits")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(filteredHabits) { habit in
                                Button {
                                    reminders.toggleEyeDropsHabit(habit)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: reminders.isEyeDropsHabitSelected(habit)
                                            ? "checkmark.circle.fill"
                                            : "circle")
                                            .foregroundStyle(reminders.isEyeDropsHabitSelected(habit) ? .purple : .secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(habit.name)
                                                .foregroundStyle(.primary)
                                            Text(habit.progressText)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if !habit.isScheduledToday {
                                            Text("Not due today")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                }
                                .buttonStyle(.plain)

                                if habit.id != filteredHabits.last?.id {
                                    Divider().padding(.leading, 38)
                                }
                            }
                        }
                    }
                }
                .frame(height: 190)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                }
            } header: {
                Label("Habit Links", systemImage: "arrow.triangle.branch")
            } footer: {
                Text("Loaded \(reminders.tickTickHabits.count) habits. Water adds one configured habit step. Select any number of eye-drop habits; each gets its own Check button in the RestIt menu.")
            }
            .disabled(!reminders.isTickTickConnected || reminders.tickTickHabits.isEmpty)

            if reminders.isTickTickConnected {
                Section {
                    if reminders.incompleteTickTickHabits.isEmpty {
                        Label("All scheduled habits are complete", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        ForEach(reminders.incompleteTickTickHabits) { habit in
                            LabeledContent(habit.name) {
                                Text(habit.progressText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Still Due Today", systemImage: "checklist")
                }
            }

            if let status = reminders.tickTickStatusMessage {
                Section {
                    Label(
                        status,
                        systemImage: reminders.tickTickStatusIsError
                            ? "exclamationmark.triangle.fill"
                            : "checkmark.circle.fill"
                    )
                    .foregroundStyle(reminders.tickTickStatusIsError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var soundSettings: some View {
        Form {
            Section {
                Toggle("Audio cues", isOn: $reminders.audioCuesEnabled)

                HStack {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $reminders.audioCueVolume, in: 0.1...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                .disabled(!reminders.audioCuesEnabled)

                Button("Preview sound") {
                    reminders.previewAudioCue()
                }
                .disabled(!reminders.audioCuesEnabled)
            } header: {
                Label("Break Sounds", systemImage: "speaker.wave.2")
            } footer: {
                Text("RestIt plays a gentle cue when an eye break starts and ends. TickTick owns habit reminder sounds and schedules.")
            }
        }
        .formStyle(.grouped)
    }

    private var consistencySettings: some View {
        Form {
            Section {
                LabeledContent("Overall") {
                    Text(scoreText(reminders.habitConsistencySummary.overallScore))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }

                ForEach(reminders.habitConsistencySummary.categoryScores) { metric in
                    LabeledContent {
                        Text(scoreText(metric.score))
                            .monospacedDigit()
                            .foregroundStyle(metric.score == nil ? .secondary : .primary)
                    } label: {
                        Label(metric.category.name, systemImage: metric.category.icon)
                    }
                }
            } header: {
                Label("28-day scores", systemImage: "gauge.with.dots.needle.67percent")
            } footer: {
                Text("Each score averages daily progress for habits scheduled in that category. The overall score gives all configured categories equal weight.")
            }

            Section {
                TextField("Search habits", text: $consistencySearch)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if consistencyHabits.isEmpty {
                            Text(reminders.tickTickHabits.isEmpty ? "Connect TickTick to load habits" : "No matching habits")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        } else {
                            ForEach(consistencyHabits) { habit in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(habit.name)
                                            .lineLimit(1)
                                        Text(habit.progressText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Picker(
                                        "Category",
                                        selection: Binding<HabitConsistencyCategory?>(
                                            get: { reminders.category(for: habit) },
                                            set: { reminders.setCategory($0, for: habit) }
                                        )
                                    ) {
                                        Text("Not included").tag(nil as HabitConsistencyCategory?)
                                        ForEach(HabitConsistencyCategory.allCases) { category in
                                            Text(category.name).tag(category as HabitConsistencyCategory?)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(width: 145)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)

                                if habit.id != consistencyHabits.last?.id {
                                    Divider().padding(.leading, 10)
                                }
                            }
                        }
                    }
                }
                .frame(height: 260)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                }
            } header: {
                Label("Categorize habits", systemImage: "square.grid.2x2")
            } footer: {
                Text("Only categorized habits contribute. Partial numeric habits, such as water, receive proportional credit up to 100%.")
            }
            .disabled(!reminders.isTickTickConnected || reminders.tickTickHabits.isEmpty)
        }
        .formStyle(.grouped)
    }

    private var eyeDropsSelectionLabel: String {
        let count = reminders.selectedEyeDropsHabitIDs.count
        if count == 0 { return "Not linked" }
        return "\(count) selected"
    }

    private var filteredHabits: [TickTickHabit] {
        let query = habitSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let habits = query.isEmpty
            ? reminders.tickTickHabits
            : reminders.tickTickHabits.filter { $0.name.localizedCaseInsensitiveContains(query) }

        return habits.sorted { lhs, rhs in
            let lhsSelected = reminders.isEyeDropsHabitSelected(lhs)
            let rhsSelected = reminders.isEyeDropsHabitSelected(rhs)
            if lhsSelected != rhsSelected { return lhsSelected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var consistencyHabits: [TickTickHabit] {
        let query = consistencySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return reminders.tickTickHabits
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scoreText(_ score: Int?) -> String {
        score.map { "\($0)" } ?? "—"
    }
}
