import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // 1-hour reminder before the event
    func scheduleReminder(for event: Event) {
        let trigger = event.scheduledAt.addingTimeInterval(-3600)
        guard trigger > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "Happening in 1 hour. Still on? Check the bail-o-meter."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: trigger
        )
        let request = UNNotificationRequest(
            identifier: "reminder-\(event.id)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Fires immediately when plan is cancelled
    func scheduleCancellation(for event: Event) {
        let content = UNMutableNotificationContent()
        content.title = "\(event.title) is cancelled"
        content.body = "Plans fell through. No names. No blame. No drama."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "cancelled-\(event.id)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelPending(for eventId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["reminder-\(eventId)", "cancelled-\(eventId)"]
        )
    }
}
