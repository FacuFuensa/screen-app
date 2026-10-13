import Foundation
import ScreenCore

struct OutboxItem: Codable, Equatable {
    let clientID: String
    let kind: String
    let groupID: UUID?
    let createdAt: Date
}

/// Extensions have no reliable network, so device events wait here until the
/// app uploads them. Client IDs are deterministic per kind, group and day, so a
/// re-fired threshold never shows up twice in the partner's feed.
struct Outbox {
    var store = SharedStore()

    func enqueue(kind: String, groupID: UUID?, now: Date = .now) {
        let id = "\(kind).\(groupID?.uuidString ?? "-").\(DayKey.string(for: now))"
        var items = all()
        guard !items.contains(where: { $0.clientID == id }) else { return }
        items.append(OutboxItem(clientID: id, kind: kind, groupID: groupID, createdAt: now))
        store.save(items, key: SharedKey.outbox)
    }

    func all() -> [OutboxItem] { store.load([OutboxItem].self, key: SharedKey.outbox) ?? [] }

    func remove(clientIDs: Set<String>) {
        store.save(all().filter { !clientIDs.contains($0.clientID) }, key: SharedKey.outbox)
    }
}
