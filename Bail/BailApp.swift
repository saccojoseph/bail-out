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

        if notification?.subscriptionID == "vote-changes" {
            do {
                // Refresh and detect any plan that just auto-cancelled, so the
                // organizer and other guests get a local cancellation alert too.
                let newlyCancelled = try await CloudKitService.shared.fetchEventsDetectingCancellations()
                for event in newlyCancelled {
                    NotificationService.shared.cancelPending(for: event.id)
                    NotificationService.shared.scheduleCancellation(for: event)
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
