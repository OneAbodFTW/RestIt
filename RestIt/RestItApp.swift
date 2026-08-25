import SwiftUI

@main
struct RestItApp: App {
    @StateObject private var reminders: ReminderManager

    init() {
        let overlay = BreakOverlayController()

        _reminders = StateObject(
            wrappedValue: ReminderManager(
                overlayController: overlay
            )
        )
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
}
