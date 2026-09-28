import SwiftUI
import Combine
import Darwin

@main
struct RestItApp: App {
    @StateObject private var reminders: ReminderManager

    init() {
        let overlay = BreakOverlayController()

        let manager = ReminderManager(overlayController: overlay)
        _reminders = StateObject(wrappedValue: manager)

        if ProcessInfo.processInfo.arguments.contains("--verify-ticktick-refresh") {
            Task { await Self.verifyTickTickRefresh(manager) }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(reminders)
        } label: {
            Label(reminders.menuBarTitle, systemImage: reminders.menuBarIcon)
                .onAppear {
                    guard ProcessInfo.processInfo.arguments.contains("--settings") else { return }
                    DispatchQueue.main.async {
                        SettingsWindowController.shared.show(reminders: reminders)
                    }
                }
        }
        .menuBarExtraStyle(.window)

    }

    /// Opt-in, read-only verification runs under the app's own Keychain identity.
    /// Reports only counts and state transitions, never tokens or habit contents.
    @MainActor private static func verifyTickTickRefresh(_ manager: ReminderManager) async {
        await Task.yield()
        let deadline = Date().addingTimeInterval(90)
        while manager.isTickTickSyncing, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }

        var loadingStates: [Bool] = []
        var dataUpdates = 0
        let loadingSubscription = manager.$isTickTickSyncing.dropFirst().sink { loadingStates.append($0) }
        let dataSubscription = manager.$tickTickHabits.dropFirst().sink { _ in dataUpdates += 1 }
        await manager.syncTickTickHabits()
        loadingSubscription.cancel()
        dataSubscription.cancel()

        let expectedStamps = manager.habitConsistencySummary.dayStamps
        let validWindow = manager.tickTickHabits.allSatisfy { $0.recentDays.map(\.stamp) == expectedStamps }
        let passed = !manager.tickTickStatusIsError && dataUpdates == 1
            && loadingStates == [true, false] && validWindow
        let report: [String: Any] = [
            "passed": passed,
            "connected": manager.isTickTickConnected,
            "habitCount": manager.tickTickHabits.count,
            "historyDays": HabitConsistencySummary.defaultDays,
            "allRecordWindowsValid": validWindow,
            "dataUpdates": dataUpdates,
            "loadingStates": loadingStates,
            "status": manager.tickTickStatusMessage ?? "No refresh status"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
            fflush(stdout)
        }
        exit(passed ? 0 : 1)
    }
}
