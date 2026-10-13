import Foundation

extension Notification.Name {
    /// Posted when a push arrives or a request changes, so the visible tabs reload.
    static let screenDataChanged = Notification.Name("screenDataChanged")
}
