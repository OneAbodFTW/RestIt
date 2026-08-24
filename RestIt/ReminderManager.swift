import Foundation

@MainActor
final class ReminderManager: ObservableObject {
    private enum DefaultsKey {
        static let eyeRemindersEnabled = "eyeRemindersEnabled"
        static let eyeIntervalMinutes = "eyeIntervalMinutes"
        static let eyeBreakSeconds = "eyeBreakSeconds"
        static let waterRemindersEnabled = "waterRemindersEnabled"
        static let waterIntervalMinutes = "waterIntervalMinutes"
        static let audioCuesEnabled = "audioCuesEnabled"
        static let audioCueVolume = "audioCueVolume"
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
        didSet {
            defaults.set(eyeBreakSeconds, forKey: DefaultsKey.eyeBreakSeconds)
        }
    }

    @Published var waterRemindersEnabled: Bool {
        didSet {
            defaults.set(waterRemindersEnabled, forKey: DefaultsKey.waterRemindersEnabled)
            if hasStarted { resetWaterSchedule() }
        }
    }

    @Published var waterIntervalMinutes: Int {
        didSet {
            defaults.set(waterIntervalMinutes, forKey: DefaultsKey.waterIntervalMinutes)
            if hasStarted { resetWaterSchedule() }
        }
    }

    @Published var audioCuesEnabled: Bool {
        didSet {
            defaults.set(audioCuesEnabled, forKey: DefaultsKey.audioCuesEnabled)
        }
    }

    @Published var audioCueVolume: Double {
        didSet {
            defaults.set(audioCueVolume, forKey: DefaultsKey.audioCueVolume)
        }
    }

    @Published private(set) var now = Date()
    @Published private(set) var nextEyeBreak = Date()
    @Published private(set) var nextWaterReminder = Date()
    @Published private(set) var pausedUntil: Date?
    @Published private(set) var isEyeBreakActive = false
    @Published private(set) var lastWaterReminder: Date?

    private let defaults: UserDefaults
    private let notificationService: NotificationService
    private let overlayController: BreakOverlayController
    private let audioCuePlayer = AudioCuePlayer()
    private var timer: Timer?
    private var hasStarted = false

    init(
        defaults: UserDefaults = .standard,
        notificationService: NotificationService,
        overlayController: BreakOverlayController
    ) {
        self.defaults = defaults
        self.notificationService = notificationService
        self.overlayController = overlayController

        defaults.register(defaults: [
            DefaultsKey.eyeRemindersEnabled: true,
            DefaultsKey.eyeIntervalMinutes: 20,
            DefaultsKey.eyeBreakSeconds: 20,
            DefaultsKey.waterRemindersEnabled: true,
            DefaultsKey.waterIntervalMinutes: 60,
            DefaultsKey.audioCuesEnabled: true,
            DefaultsKey.audioCueVolume: 0.55
        ])

        eyeRemindersEnabled = defaults.bool(forKey: DefaultsKey.eyeRemindersEnabled)
        eyeIntervalMinutes = defaults.integer(forKey: DefaultsKey.eyeIntervalMinutes)
        eyeBreakSeconds = defaults.integer(forKey: DefaultsKey.eyeBreakSeconds)
        waterRemindersEnabled = defaults.bool(forKey: DefaultsKey.waterRemindersEnabled)
        waterIntervalMinutes = defaults.integer(forKey: DefaultsKey.waterIntervalMinutes)
        audioCuesEnabled = defaults.bool(forKey: DefaultsKey.audioCuesEnabled)
        audioCueVolume = defaults.double(forKey: DefaultsKey.audioCueVolume)

        let start = Date()
        nextEyeBreak = start.addingTimeInterval(TimeInterval(eyeIntervalMinutes * 60))
        nextWaterReminder = start.addingTimeInterval(TimeInterval(waterIntervalMinutes * 60))

        startTimers()
    }

    deinit {
        timer?.invalidate()
    }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }

    var nextEyeBreakText: String {
        guard eyeRemindersEnabled else { return "Off" }
        if let pausedUntil, pausedUntil > now {
            return "Paused for \(Self.durationText(from: now, to: pausedUntil))"
        }
        if isEyeBreakActive { return "Resting now" }
        return Self.durationText(from: now, to: nextEyeBreak)
    }

    var nextWaterReminderText: String {
        guard waterRemindersEnabled else { return "Off" }
        if let pausedUntil, pausedUntil > now {
            return "Paused"
        }
        return Self.durationText(from: now, to: nextWaterReminder)
    }

    var menuBarTitle: String {
        if isEyeBreakActive { return "Rest" }
        if isPaused { return "Paused" }
        guard eyeRemindersEnabled else { return "RestIt" }

        let seconds = max(0, Int(nextEyeBreak.timeIntervalSince(now)))
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        return "\(minutes)m"
    }

    var menuBarIcon: String {
        if isPaused { return "pause.circle.fill" }
        if isEyeBreakActive { return "eye.slash.fill" }
        return "eye.fill"
    }

    func startEyeBreakNow() {
        guard !isEyeBreakActive else { return }
        beginEyeBreak()
    }

    func skipNextEyeBreak() {
        guard !isEyeBreakActive else { return }
        nextEyeBreak = Date().addingTimeInterval(eyeInterval)
    }

    func recordWater() {
        lastWaterReminder = nil
        nextWaterReminder = Date().addingTimeInterval(waterInterval)
    }

    func snoozeWater(minutes: Int = 10) {
        lastWaterReminder = nil
        nextWaterReminder = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func pause(for minutes: Int) {
        let resumeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        pausedUntil = resumeDate
        nextEyeBreak = resumeDate.addingTimeInterval(eyeInterval)
        nextWaterReminder = resumeDate.addingTimeInterval(waterInterval)

        if isEyeBreakActive {
            overlayController.dismiss()
            isEyeBreakActive = false
        }
    }

    func resume() {
        pausedUntil = nil
        resetSchedules()
    }

    func requestNotificationPermission() {
        notificationService.requestAuthorization()
    }

    func previewAudioCue() {
        guard audioCuesEnabled else { return }
        audioCuePlayer.play(.eyeBreakStarted, volume: audioCueVolume)
    }

    private var eyeInterval: TimeInterval {
        TimeInterval(eyeIntervalMinutes * 60)
    }

    private var waterInterval: TimeInterval {
        TimeInterval(waterIntervalMinutes * 60)
    }

    private func startTimers() {
        hasStarted = true
        notificationService.requestAuthorization()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        let currentDate = Date()
        now = currentDate

        if let pausedUntil {
            if pausedUntil > currentDate { return }
            self.pausedUntil = nil
            resetSchedules(from: currentDate)
            return
        }

        if eyeRemindersEnabled, !isEyeBreakActive, currentDate >= nextEyeBreak {
            beginEyeBreak()
        }

        if waterRemindersEnabled, currentDate >= nextWaterReminder {
            triggerWaterReminder(at: currentDate)
        }
    }

    private func beginEyeBreak() {
        isEyeBreakActive = true
        playAudioCue(.eyeBreakStarted)
        overlayController.show(duration: eyeBreakSeconds) { [weak self] in
            guard let self else { return }
            self.isEyeBreakActive = false
            self.nextEyeBreak = Date().addingTimeInterval(self.eyeInterval)
            self.playAudioCue(.eyeBreakFinished)
        }
    }

    private func triggerWaterReminder(at date: Date) {
        lastWaterReminder = date
        nextWaterReminder = date.addingTimeInterval(waterInterval)
        playAudioCue(.waterReminder)
        notificationService.sendWaterReminder()
    }

    private func playAudioCue(_ cue: AudioCuePlayer.Cue) {
        guard audioCuesEnabled else { return }
        audioCuePlayer.play(cue, volume: audioCueVolume)
    }

    private func resetEyeSchedule() {
        nextEyeBreak = Date().addingTimeInterval(eyeInterval)
        if !eyeRemindersEnabled, isEyeBreakActive {
            overlayController.dismiss()
            isEyeBreakActive = false
        }
    }

    private func resetWaterSchedule() {
        lastWaterReminder = nil
        nextWaterReminder = Date().addingTimeInterval(waterInterval)
    }

    private func resetSchedules(from date: Date = Date()) {
        nextEyeBreak = date.addingTimeInterval(eyeInterval)
        nextWaterReminder = date.addingTimeInterval(waterInterval)
        lastWaterReminder = nil
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
