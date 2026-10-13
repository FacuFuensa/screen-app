import Foundation

/// Left by the shield's "Pedir tiempo" button for the app to pick up.
struct PendingAsk: Codable {
    var groupID: UUID
    var createdAt: Date
}
