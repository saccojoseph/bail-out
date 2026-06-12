import SwiftUI
import CloudKit

@main
struct BailApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
/// Handles CloudKit silent push notifications for real-time vote updates.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        // Build the dictionary CKNotification expects
        var converted: [String: NSObject] = [:]
        for (key, value) in userInfo {
            if let stringKey = key as? String, let objValue = value as? NSObject {
                converted[stringKey] = objValue
            }
        }
        let notification = CKNotification(fromRemoteNotificationDictionary: converted)

        let subID = notification?.subscriptionID ?? ""
        if subID.hasPrefix("vote-") || subID.hasPrefix("event-") {
            do {
                // Refresh and detect plans that just cancelled (auto via bail
                // threshold OR manual cancel) and location votes that just
                // resolved, so every guest gets the right local notification.
                let changes = try await CloudKitService.shared.fetchEventsDetectingChanges()
                for event in changes.newlyCancelled {
                    NotificationService.shared.cancelPending(for: event.id)
                    NotificationService.shared.scheduleCancellation(for: event)
                }
                for event in changes.newlyResolvedLocation {
                    NotificationService.shared.scheduleLocationResolved(for: event)
                }
                return .newData
            } catch {
                return .failed
            }
        }

        return .noData
    }
}
#endif
