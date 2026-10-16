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
            done(.close)
        case .secondaryButtonPressed:
            // Shield extensions can neither open the app nor reach the network: leave the
            // request for the app and post a notification that opens straight into it.
            SharedStore().save(PendingAsk(groupID: groupID, createdAt: .now), key: SharedKey.pendingAsk)
            let partner = AppGroup.defaults.string(forKey: SharedKey.partnerName)
            let content = UNMutableNotificationContent()
            content.title = partner.map { "Pedile permiso a \($0)" } ?? "Pedir permiso"
            content.body = "Tocá acá para elegir cuántos minutos necesitás."
            content.sound = .default
            content.userInfo = ["type": "ask", "group_id": groupID.uuidString]
            let request = UNNotificationRequest(identifier: "ask", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { _ in done(.close) }
        @unknown default:
            done(.close)
        }
    }
}
