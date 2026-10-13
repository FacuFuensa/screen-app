import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if Demo.isOn { return true }
        NotificationCategories.register()
        BackgroundRefresh.register()
        BackgroundRefresh.schedule()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard !Demo.isOn else { return }
        PushToken.current = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { await SyncService.shared.run() }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard !Demo.isOn else { return .noData }
        await SyncService.shared.run()
        await MainActor.run { NotificationCenter.default.post(name: .screenDataChanged, object: nil) }
        return .newData
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // The app is open: refresh what is on screen, not just show a banner.
        await MainActor.run { NotificationCenter.default.post(name: .screenDataChanged, object: nil) }
        return [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await NotificationRouter.handle(response)
    }
}
