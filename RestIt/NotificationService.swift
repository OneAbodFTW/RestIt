import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendWaterReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time for some water"
        content.body = "Take a short pause and drink a glass of water."
        // RestIt plays its own gentle cue so the notification must stay silent
        // to avoid two overlapping sounds.
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "water-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }
}
