import Foundation
import UserNotifications

enum NotificationCategories {
    static func register() {
        let deny = UNNotificationAction(identifier: "DENY", title: "No", options: [.destructive, .authenticationRequired])
        let other = UNNotificationAction(identifier: "GRANT_OTHER", title: "Otra cantidad", options: [.foreground])
        var categories: Set<UNNotificationCategory> = []
        for m in [5, 15, 30] {
            let grant = UNNotificationAction(identifier: "GRANT", title: "Dar \(m) min", options: [.authenticationRequired])
            categories.insert(UNNotificationCategory(identifier: "EXTRA_TIME_REQUEST_\(m)", actions: [grant, other, deny], intentIdentifiers: []))
        }
        let approve = UNNotificationAction(identifier: "APPROVE", title: "Aprobar", options: [.authenticationRequired])
        categories.insert(UNNotificationCategory(identifier: "LOOSEN_REQUEST", actions: [approve, deny], intentIdentifiers: []))
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

@MainActor
enum NotificationRouter {
    static func handle(_ response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let type = info["type"] as? String

        if type == "ask" {
            Router.shared.sheet = .ask((info["group_id"] as? String).flatMap(UUID.init))
            return
        }
        guard let rid = (info["request_id"] as? String).flatMap(UUID.init) else {
            await SyncService.shared.run()
            return
        }
        switch response.actionIdentifier {
        case "GRANT", "APPROVE": await answer(rid, grant: true)
        case "DENY": await answer(rid, grant: false)
        case "GRANT_OTHER": Router.shared.sheet = .answer(rid)
        default:
            if type == "request" { Router.shared.tab = .partner } else { await SyncService.shared.run() }
        }
    }

    private static func answer(_ rid: UUID, grant: Bool) async {
        do {
            try await Backend.shared.answer(requestID: rid, grant: grant, minutes: nil)
            await Backend.shared.notify(requestID: rid)
        } catch {
            // Answered from the lock screen, so say why it did nothing.
            let c = UNMutableNotificationContent()
            c.title = "No se pudo responder"
            c.body = error.localizedDescription
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
        }
        NotificationCenter.default.post(name: .screenDataChanged, object: nil)
    }
}
