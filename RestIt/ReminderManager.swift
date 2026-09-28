import Combine
import Foundation

@MainActor
final class ReminderManager: ObservableObject {
    private enum DefaultsKey {
        static let eyeRemindersEnabled = "eyeRemindersEnabled"
        static let eyeIntervalMinutes = "eyeIntervalMinutes"
        static let eyeBreakSeconds = "eyeBreakSeconds"
        static let audioCuesEnabled = "audioCuesEnabled"
        static let audioCueVolume = "audioCueVolume"
        static let trackingDayStart = "trackingDayStart"
        static let restsToday = "restsToday"
        static let selectedWaterHabitID = "selectedWaterHabitID"
        static let selectedEyeDropsHabitIDs = "selectedEyeDropsHabitIDs"
        static let selectedEyeDropsHabitID = "selectedEyeDropsHabitID"
        static let habitCategoryAssignments = "habitCategoryAssignments"
    }

    @Published var eyeRemindersEnabled: Bool {
        didSet {
            defaults.set(eyeRemindersEnabled, forKey: DefaultsKey.eyeRemindersEnabled)
            if hasStarted { resetEyeSchedule() }
        }
    }

    @Published var eyeIntervalMinutes: Int {
        didSet {
            defaults.set(eyeIntervalMinutes, forKey: DefaultsKey.eyeIntervalMinutes)
            if hasStarted { resetEyeSchedule() }
        }
    }

    @Published var eyeBreakSeconds: Int {
        didSet { defaults.set(eyeBreakSeconds, forKey: DefaultsKey.eyeBreakSeconds) }
    }

    @Published var audioCuesEnabled: Bool {
        didSet { defaults.set(audioCuesEnabled, forKey: DefaultsKey.audioCuesEnabled) }
    }

    @Published var audioCueVolume: Double {
        didSet { defaults.set(audioCueVolume, forKey: DefaultsKey.audioCueVolume) }
    }

    @Published var selectedWaterHabitID: String {
        didSet { defaults.set(selectedWaterHabitID, forKey: DefaultsKey.selectedWaterHabitID) }
    }

    @Published private(set) var selectedEyeDropsHabitIDs: Set<String> {
        didSet {
            defaults.set(selectedEyeDropsHabitIDs.sorted(), forKey: DefaultsKey.selectedEyeDropsHabitIDs)
        }
    }

    @Published private(set) var habitCategoryAssignments: [String: HabitConsistencyCategory] {
        didSet {
            defaults.set(
                habitCategoryAssignments.mapValues(\.rawValue),
                forKey: DefaultsKey.habitCategoryAssignments
            )
        }
    }

    @Published private(set) var now = Date()
    @Published private(set) var nextEyeBreak = Date()
    @Published private(set) var isEyeBreakActive = false
    @Published private(set) var restsToday = 0
    @Published private(set) var tickTickHabits: [TickTickHabit] = []
    @Published private(set) var isTickTickConnected = false
    @Published private(set) var isTickTickSyncing = false
    @Published private(set) var checkingHabitIDs: Set<String> = []
    @Published private(set) var tickTickStatusMessage: String?
    @Published private(set) var tickTickStatusIsError = false

    private let defaults: UserDefaults
    private let tickTickTokenLoader: () throws -> String?
    private let overlayController: BreakOverlayController
    private let audioCuePlayer = AudioCuePlayer()
    private var timer: Timer?
    private var hasStarted = false
    private var trackingDayStart = Calendar.current.startOfDay(for: Date())
    private var lastTickTickSyncDate = Date.distantPast

    init(
        defaults: UserDefaults = .standard,
        overlayController: BreakOverlayController,
        tickTickTokenLoader: @escaping () throws -> String? = TickTickTokenStore.load
    ) {
        self.defaults = defaults
        self.tickTickTokenLoader = tickTickTokenLoader
        self.overlayController = overlayController

        defaults.register(defaults: [
            DefaultsKey.eyeRemindersEnabled: true,
            DefaultsKey.eyeIntervalMinutes: 20,
            DefaultsKey.eyeBreakSeconds: 20,
            DefaultsKey.audioCuesEnabled: true,
            DefaultsKey.audioCueVolume: 0.55,
            DefaultsKey.trackingDayStart: 0.0,
            DefaultsKey.restsToday: 0,
            DefaultsKey.selectedWaterHabitID: "",
            DefaultsKey.selectedEyeDropsHabitIDs: [String](),
            DefaultsKey.selectedEyeDropsHabitID: "",
            DefaultsKey.habitCategoryAssignments: [String: String]()
        ])

        eyeRemindersEnabled = defaults.bool(forKey: DefaultsKey.eyeRemindersEnabled)
        eyeIntervalMinutes = defaults.integer(forKey: DefaultsKey.eyeIntervalMinutes)
        eyeBreakSeconds = defaults.integer(forKey: DefaultsKey.eyeBreakSeconds)
        audioCuesEnabled = defaults.bool(forKey: DefaultsKey.audioCuesEnabled)
        audioCueVolume = defaults.double(forKey: DefaultsKey.audioCueVolume)
        selectedWaterHabitID = defaults.string(forKey: DefaultsKey.selectedWaterHabitID) ?? ""
        let savedEyeDropIDs = defaults.stringArray(forKey: DefaultsKey.selectedEyeDropsHabitIDs) ?? []
        let legacyEyeDropID = defaults.string(forKey: DefaultsKey.selectedEyeDropsHabitID) ?? ""
        selectedEyeDropsHabitIDs = Set(
            savedEyeDropIDs.isEmpty && !legacyEyeDropID.isEmpty ? [legacyEyeDropID] : savedEyeDropIDs
        )
        let savedAssignments = defaults.dictionary(forKey: DefaultsKey.habitCategoryAssignments) as? [String: String] ?? [:]
        habitCategoryAssignments = savedAssignments.compactMapValues(HabitConsistencyCategory.init(rawValue:))
        defaults.set(
            habitCategoryAssignments.mapValues(\.rawValue),
            forKey: DefaultsKey.habitCategoryAssignments
        )
        defaults.set(selectedEyeDropsHabitIDs.sorted(), forKey: DefaultsKey.selectedEyeDropsHabitIDs)
        defaults.removeObject(forKey: DefaultsKey.selectedEyeDropsHabitID)
        isTickTickConnected = ((try? tickTickTokenLoader()) ?? nil) != nil

        let start = Date()
        nextEyeBreak = start.addingTimeInterval(TimeInterval(eyeIntervalMinutes * 60))
        restoreDailyStats(at: start)
        startTimers()

        if isTickTickConnected {
            Task { await syncTickTickHabits(showSuccess: false) }
        }
    }

    deinit { timer?.invalidate() }

    var nextEyeBreakText: String {
        guard eyeRemindersEnabled else { return "Off" }
        if isEyeBreakActive { return "Resting now" }
        return Self.durationText(from: now, to: nextEyeBreak)
    }

    var menuBarTitle: String {
        let consistency = habitConsistencySummary.overallScore.map(String.init) ?? "—"
        if isEyeBreakActive { return "C\(consistency) · Rest" }
        guard eyeRemindersEnabled else { return "C\(consistency)" }

        let seconds = max(0, Int(nextEyeBreak.timeIntervalSince(now)))
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        return "C\(consistency) · \(minutes)m"
    }

    var menuBarIcon: String {
        if isEyeBreakActive { return "eye.slash.fill" }
        return "eye.fill"
    }

    var incompleteTickTickHabits: [TickTickHabit] {
        tickTickHabits.filter { $0.isScheduledToday && !$0.isCompletedToday }
    }

    var selectedWaterHabit: TickTickHabit? {
        tickTickHabits.first { $0.id == selectedWaterHabitID }
    }

    var selectedEyeDropsHabits: [TickTickHabit] {
        tickTickHabits.filter { selectedEyeDropsHabitIDs.contains($0.id) }
    }

    var habitConsistencySummary: HabitConsistencySummary {
        HabitConsistencySummary.calculate(
            habits: tickTickHabits,
            assignments: habitCategoryAssignments
        )
    }

    func skipNextEyeBreak() {
        guard !isEyeBreakActive else { return }
        nextEyeBreak = Date().addingTimeInterval(eyeInterval)
    }

    func previewAudioCue() {
        guard audioCuesEnabled else { return }
        audioCuePlayer.play(.eyeBreakStarted, volume: audioCueVolume)
    }

    func connectTickTick(token: String) async {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            setTickTickStatus("Paste an API token first.", isError: true)
            return
        }

        isTickTickSyncing = true
        defer { isTickTickSyncing = false }
        do {
            let habits = try await TickTickHabitService(token: cleanToken).fetchHabits()
            try TickTickTokenStore.save(cleanToken)
            isTickTickConnected = true
            applyTickTickHabits(habits)
            lastTickTickSyncDate = Date()
            setTickTickStatus("Connected. Loaded \(habits.count) habit\(habits.count == 1 ? "" : "s").", isError: false)
        } catch {
            setTickTickStatus(error.localizedDescription, isError: true)
        }
    }

    func disconnectTickTick() {
        do {
            try TickTickTokenStore.delete()
            isTickTickConnected = false
            tickTickHabits = []
            checkingHabitIDs = []
            setTickTickStatus("Disconnected from TickTick.", isError: false)
        } catch {
            setTickTickStatus(error.localizedDescription, isError: true)
        }
    }

    func syncTickTickHabits(showSuccess: Bool = true) async {
        guard !isTickTickSyncing, checkingHabitIDs.isEmpty else { return }
        guard let token = try? tickTickTokenLoader() else {
            isTickTickConnected = false
            if showSuccess { setTickTickStatus("Connect TickTick first.", isError: true) }
            return
        }

        isTickTickSyncing = true
        lastTickTickSyncDate = Date()
        defer { isTickTickSyncing = false }
        do {
            let habits = try await TickTickHabitService(token: token).fetchHabits()
            isTickTickConnected = true
            applyTickTickHabits(habits)
            if showSuccess {
                setTickTickStatus("Refreshed \(habits.count) habit\(habits.count == 1 ? "" : "s") and the last \(HabitConsistencySummary.defaultDays) days of check-ins.", isError: false)
            }
        } catch {
            setTickTickStatus(error.localizedDescription, isError: true)
        }
    }

    func logWaterHabit() {
        guard let habit = selectedWaterHabit else {
            setTickTickStatus("Choose a water habit in Settings first.", isError: true)
            return
        }
        checkIn(habit, complete: false)
    }

    func toggleEyeDropsHabit(_ habit: TickTickHabit) {
        if selectedEyeDropsHabitIDs.contains(habit.id) {
            selectedEyeDropsHabitIDs.remove(habit.id)
        } else {
            selectedEyeDropsHabitIDs.insert(habit.id)
        }
    }

    func isEyeDropsHabitSelected(_ habit: TickTickHabit) -> Bool {
        selectedEyeDropsHabitIDs.contains(habit.id)
    }

    func category(for habit: TickTickHabit) -> HabitConsistencyCategory? {
        habitCategoryAssignments[habit.id]
    }

    func setCategory(_ category: HabitConsistencyCategory?, for habit: TickTickHabit) {
        if let category {
            habitCategoryAssignments[habit.id] = category
        } else {
            habitCategoryAssignments.removeValue(forKey: habit.id)
        }
    }

    func checkEyeDropsHabit(_ habit: TickTickHabit) {
        guard selectedEyeDropsHabitIDs.contains(habit.id) else {
            setTickTickStatus("Link that eye-drop habit in Settings first.", isError: true)
            return
        }
        checkIn(habit, complete: false)
    }

    func isCheckingHabit(_ habit: TickTickHabit) -> Bool {
        checkingHabitIDs.contains(habit.id)
    }

    private var eyeInterval: TimeInterval {
        TimeInterval(eyeIntervalMinutes * 60)
    }

    private func startTimers() {
        hasStarted = true
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        let currentDate = Date()
        now = currentDate
        rollDailyStatsIfNeeded(at: currentDate)

        if isTickTickConnected,
           !isTickTickSyncing,
           checkingHabitIDs.isEmpty,
           currentDate.timeIntervalSince(lastTickTickSyncDate) >= 300 {
            lastTickTickSyncDate = currentDate
            Task { await syncTickTickHabits(showSuccess: false) }
        }

        if eyeRemindersEnabled, !isEyeBreakActive, currentDate >= nextEyeBreak {
            beginEyeBreak()
        }
    }

    private func beginEyeBreak() {
        isEyeBreakActive = true
        playAudioCue(.eyeBreakStarted)

        if isTickTickConnected {
            Task { await syncTickTickHabits(showSuccess: false) }
        }

        overlayController.show(
            duration: eyeBreakSeconds,
            onFinished: { [weak self] completed in
                guard let self else { return }
                self.isEyeBreakActive = false
                self.nextEyeBreak = Date().addingTimeInterval(self.eyeInterval)
                if completed {
                    self.rollDailyStatsIfNeeded(at: Date())
                    self.restsToday += 1
                    self.persistDailyStats()
                }
                self.playAudioCue(.eyeBreakFinished)
            }
        )
    }

    private func checkIn(_ habit: TickTickHabit, complete: Bool) {
        // Serialize check-ins and refreshes so an older fetch cannot replace a
        // just-saved value, including automatic refreshes started by the timer.
        guard !isTickTickSyncing, checkingHabitIDs.isEmpty else { return }
        guard let token = try? tickTickTokenLoader() else {
            setTickTickStatus("Connect TickTick first.", isError: true)
            return
        }

        checkingHabitIDs.insert(habit.id)
        Task {
            do {
                let value = try await TickTickHabitService(token: token).checkIn(habit, complete: complete)
                if let index = tickTickHabits.firstIndex(where: { $0.id == habit.id }) {
                    tickTickHabits[index].applyCurrentValue(value)
                }
                setTickTickStatus("Logged \(habit.name) in TickTick.", isError: false)
            } catch {
                checkingHabitIDs.remove(habit.id)
                setTickTickStatus(error.localizedDescription, isError: true)
                return
            }
            checkingHabitIDs.remove(habit.id)
            // Reload canonical records, including history edited on other devices.
            await syncTickTickHabits(showSuccess: false)
            if tickTickStatusIsError {
                setTickTickStatus("Logged \(habit.name) in TickTick, but could not refresh: \(tickTickStatusMessage ?? "Unknown error")", isError: true)
            }
        }
    }

    private func applyTickTickHabits(_ habits: [TickTickHabit]) {
        tickTickHabits = habits
    }

    private func setTickTickStatus(_ message: String, isError: Bool) {
        tickTickStatusMessage = message
        tickTickStatusIsError = isError
    }

    private func playAudioCue(_ cue: AudioCuePlayer.Cue) {
        guard audioCuesEnabled else { return }
        audioCuePlayer.play(cue, volume: audioCueVolume)
    }

    private func resetEyeSchedule(from date: Date = Date()) {
        nextEyeBreak = date.addingTimeInterval(eyeInterval)
        if !eyeRemindersEnabled, isEyeBreakActive {
            overlayController.dismiss()
            isEyeBreakActive = false
        }
    }

    private func restoreDailyStats(at date: Date) {
        let savedTimestamp = defaults.double(forKey: DefaultsKey.trackingDayStart)
        let savedDate = Date(timeIntervalSince1970: savedTimestamp)

        guard savedTimestamp > 0, Calendar.current.isDate(savedDate, inSameDayAs: date) else {
            trackingDayStart = Calendar.current.startOfDay(for: date)
            persistDailyStats()
            return
        }

        trackingDayStart = Calendar.current.startOfDay(for: savedDate)
        restsToday = defaults.integer(forKey: DefaultsKey.restsToday)
    }

    private func rollDailyStatsIfNeeded(at date: Date) {
        guard !Calendar.current.isDate(trackingDayStart, inSameDayAs: date) else { return }

        trackingDayStart = Calendar.current.startOfDay(for: date)
        restsToday = 0
        lastTickTickSyncDate = .distantPast
        persistDailyStats()
    }

    private func persistDailyStats() {
        defaults.set(trackingDayStart.timeIntervalSince1970, forKey: DefaultsKey.trackingDayStart)
        defaults.set(restsToday, forKey: DefaultsKey.restsToday)
    }

    private static func durationText(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        if seconds < 60 { return "\(seconds)s" }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
        }
        return remainingSeconds == 0 ? "\(minutes)m" : "\(minutes)m \(remainingSeconds)s"
    }
}
