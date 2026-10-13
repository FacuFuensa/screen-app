import Foundation
import ManagedSettings
import UserNotifications

final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, groupID: Enforcer().groupID(containing: application), completionHandler)
    }
    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, groupID: Enforcer().groupID(containing: webDomain), completionHandler)
    }
    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, groupID: Enforcer().groupID(containing: category), completionHandler)
    }

    private func handle(_ action: ShieldAction, groupID: UUID?, _ done: @escaping (ShieldActionResponse) -> Void) {
        guard let groupID else { done(.close); return }
        switch action {
        case .primaryButtonPressed:
            // Shield extensions have no network: hand the request to the app.
            SharedStore().save(PendingAsk(groupID: groupID, createdAt: .now), key: SharedKey.pendingAsk)
            let content = UNMutableNotificationContent()
            content.title = "Pedir tiempo"
            content.body = "Tocá acá para elegir cuántos minutos pedir."
            content.userInfo = ["type": "ask", "group_id": groupID.uuidString]
            let request = UNNotificationRequest(identifier: "ask", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in done(.close) }
        case .secondaryButtonPressed:
            let ok = (try? Enforcer().useWildcard(groupID: groupID)) ?? false
            done(ok ? .defer : .close)
        @unknown default:
            done(.close)
        }
    }
}
