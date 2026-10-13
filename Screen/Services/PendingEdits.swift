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

    func set(_ edit: PendingEdit) {
        var map = all()
        map[edit.group.id.uuidString] = edit
        store.save(map, key: SharedKey.pendingEdits)
    }

    func take(groupID: UUID) -> PendingEdit? {
        var map = all()
        let edit = map.removeValue(forKey: groupID.uuidString)
        store.save(map, key: SharedKey.pendingEdits)
        return edit
    }
}
