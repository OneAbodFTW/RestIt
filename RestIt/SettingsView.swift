import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case reminders
    case habits
    case consistency
    case sound

    var id: Self { self }

    var title: String {
        switch self {
        case .reminders: "Reminders"
        case .habits: "TickTick Habits"
        case .consistency: "Consistency"
        case .sound: "Sound"
        }
    }

    var icon: String {
        switch self {
        case .reminders: "eye"
        case .habits: "checkmark.circle"
        case .consistency: "chart.line.uptrend.xyaxis"
        case .sound: "speaker.wave.2"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var reminders: ReminderManager
    @State private var selectedTab: SettingsTab = .reminders
    @State private var tickTickToken = ""
    @State private var habitSearch = ""
    @State private var consistencySearch = ""

    private let eyeIntervals = [20, 30, 45, 60]
    private let breakDurations = [20, 30, 60]

    var body: some View {
        VStack(spacing: 0) {
            settingsTabBar
            Divider()
            selectedSettings
            Divider()
            TickTickRefreshControls()
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .frame(width: 620, height: 560)
        .tint(Color.accentColor)
        .navigationTitle("RestIt Settings")
    }

    private var settingsTabBar: some View {
        HStack(spacing: 8) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(tab.title)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 28, height: 3)
                                .offset(y: 1)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.035))
    }

    @ViewBuilder
    private var selectedSettings: some View {
        switch selectedTab {
        case .reminders:
            reminderSettings
        case .habits:
            tickTickSettings
        case .consistency:
            consistencySettings
        case .sound:
            soundSettings
        }
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
                Text("The full-screen break keeps distractions to a minimum so you can close your eyes and rest.")
            }

            Section {
                LabeledContent("Completed rests") {
                    Text("\(reminders.restsToday)").monospacedDigit()
                }
            } header: {
                Label("Today", systemImage: "chart.bar")
            } footer: {
                Text("Only rests that finish count. The total persists between launches and resets at local midnight.")
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
                        .foregroundStyle(Color.accentColor)
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
                                            .foregroundStyle(reminders.isEyeDropsHabitSelected(habit) ? Color.accentColor : Color.secondary)

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
                Text("Loaded \(reminders.tickTickHabits.count) habits. Water and eye-drop logs each add one configured habit step. Select any number of eye-drop habits; each gets its own Log button in the RestIt menu.")
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
        let summary = reminders.habitConsistencySummary

        return Form {
            Section {
                HabitConsistencyScoreCalculation(summary: summary)
            } header: {
                Label("7-day scores", systemImage: "gauge.with.dots.needle.67percent")
            }

            Section {
                if !reminders.isTickTickConnected {
                    Text("Connect TickTick to see weekly consistency.")
                        .foregroundStyle(.secondary)
                } else if summary.habitImpacts.isEmpty {
                    Text("Categorize at least one habit to see its weekly consistency.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.prioritizedHabitImpacts) { impact in
                        HabitConsistencyImpactRow(impact: impact, dayStamps: summary.dayStamps)
                            .padding(.vertical, 6)
                    }
                }
            } header: {
                Label("Your habits this week", systemImage: "calendar")
            } footer: {
                Text("Each row shows the last 7 days, including today. A checkmark means the goal was met, a half-circle means partial progress, and a dash means no scheduled data. Partial progress earns partial credit; days off are ignored.")
            }

            Section {
                DisclosureGroup("How weekly consistency is calculated") {
                    HabitConsistencyFormulaExplanation()
                        .padding(.top, 6)
                }
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

}
