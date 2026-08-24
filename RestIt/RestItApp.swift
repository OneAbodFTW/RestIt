import SwiftUI

@main
struct RestItApp: App {
    @StateObject private var reminders: ReminderManager
    private let notificationService: NotificationService

    init() {
        let notifications = NotificationService()
        let overlay = BreakOverlayController()

        notificationService = notifications
        _reminders = StateObject(
            wrappedValue: ReminderManager(
                notificationService: notifications,
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
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(reminders)
        }
    }
}

