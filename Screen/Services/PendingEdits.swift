import Foundation

/// A loosening waiting for the partner. Kept on device because only this phone
/// can hold the app tokens the server never sees.
struct PendingEdit: Codable, Equatable {
    var group: LimitGroup
    var delete: Bool
}

struct PendingEdits {
    var store = SharedStore()

    func all() -> [String: PendingEdit] { store.load([String: PendingEdit].self, key: SharedKey.pendingEdits) ?? [:] }

    func set(_ edit: PendingEdit, requestID: UUID) {
        var map = all()
        map = map.filter { $0.value.group.id != edit.group.id }
        map[requestID.uuidString] = edit
        store.save(map, key: SharedKey.pendingEdits)
    }

    func take(requestID: UUID) -> PendingEdit? {
        var map = all()
        let edit = map.removeValue(forKey: requestID.uuidString)
        store.save(map, key: SharedKey.pendingEdits)
        return edit
    }

    func hasPending(groupID: UUID) -> Bool {
        all().values.contains { $0.group.id == groupID }
    }
}
