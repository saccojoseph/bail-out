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

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if notification?.subscriptionID == "vote-changes" {
            // A vote was cast or changed — refresh events
            do {
                try await CloudKitService.shared.fetchEvents()
                return .newData
            } catch {
                return .failed
            }
        }

        return .noData
    }
}
#endif
