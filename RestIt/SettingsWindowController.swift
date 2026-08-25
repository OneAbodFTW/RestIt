import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(reminders: ReminderManager) {
        let settingsView = SettingsView()
            .environmentObject(reminders)
        let hostingController = NSHostingController(rootView: settingsView)

        let settingsWindow: NSWindow
        if let window {
            window.contentViewController = hostingController
            settingsWindow = window
        } else {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow.title = "RestIt Settings"
            settingsWindow.contentViewController = hostingController
            settingsWindow.isReleasedWhenClosed = false
            settingsWindow.collectionBehavior = [.moveToActiveSpace]
            settingsWindow.delegate = self
            settingsWindow.center()
            window = settingsWindow
        }

        if settingsWindow.isMiniaturized {
            settingsWindow.deminiaturize(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
        settingsWindow.orderFrontRegardless()
    }
}
