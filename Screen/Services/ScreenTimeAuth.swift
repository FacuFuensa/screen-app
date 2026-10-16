import FamilyControls
import Foundation
import UIKit

/// AuthorizationCenter loads its status asynchronously: right after a cold launch
/// or a background wake it can read `.notDetermined` for an app that is approved.
/// Reading it too early showed the permissions screen on every launch and told
/// the partner "desactivó los permisos" out of nowhere.
@MainActor
enum ScreenTimeAuth {
    private static let approvedKey = "screenTimeApprovedOnce"
    private static let suspectKey = "screenTimeNotApprovedSince"
    /// A real revocation sticks; a launch glitch is gone by the next wake.
    private static let confirmAfter: TimeInterval = 30 * 60

    private static var defaults: UserDefaults { AppGroup.defaults }

    /// Waits for the status to load. Apps that were approved before get a longer wait.
    static func settledStatus() async -> AuthorizationStatus {
        let center = AuthorizationCenter.shared
        let timeout: TimeInterval = defaults.bool(forKey: approvedKey) ? 3 : 0.6
        let deadline = Date().addingTimeInterval(timeout)
        while center.authorizationStatus != .approved, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        let status = center.authorizationStatus
        if status == .approved {
            defaults.set(true, forKey: approvedKey)
            defaults.removeObject(forKey: suspectKey)
        }
        return status
    }

    /// What the heartbeat tells the server. In the foreground the settled value is
    /// trusted; in the background a loss only counts once it is still there 30 min later.
    static func reportedStatus() async -> String {
        let status = await settledStatus()
        guard status != .approved, defaults.bool(forKey: approvedKey) else { return status.wireValue }
        if UIApplication.shared.applicationState == .active { return status.wireValue }
        let now = Date()
        guard let since = defaults.object(forKey: suspectKey) as? Date else {
            defaults.set(now, forKey: suspectKey)
            return AuthorizationStatus.approved.wireValue
        }
        return now.timeIntervalSince(since) >= confirmAfter ? status.wireValue : AuthorizationStatus.approved.wireValue
    }
}
