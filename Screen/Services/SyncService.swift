import FamilyControls
import Foundation
import ScreenCore

extension AuthorizationStatus {
    var wireValue: String {
        switch self {
        case .approved: return "approved"
        case .denied: return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }
}

/// Everything that needs the network and might have been missed: runs on every
/// foreground, background refresh and push. Each step is safe to repeat.
@MainActor
final class SyncService {
    static let shared = SyncService()
    private let backend = Backend.shared
    private let enforcer = Enforcer()
    private var running = false

    func run() async {
        guard !running, await backend.currentUserID() != nil else { return }
        running = true; defer { running = false }

        let status = AuthorizationCenter.shared.authorizationStatus.wireValue
        if let eid = try? await backend.heartbeat(authStatus: status, apnsToken: PushToken.current) {
            await backend.notify(eventID: eid)
        }
        await flushOutbox()
        await applyGrants()
        // Re-mirror local groups; the server rejects anything looser, which is fine.
        for g in enforcer.groups { _ = try? await backend.saveGroup(g, removesApps: false) }
    }

    private func flushOutbox() async {
        let outbox = Outbox()
        var sent = Set<String>()
        for item in outbox.all() {
            do {
                if let id = try await backend.logEvent(item) { await backend.notify(eventID: id) }
                sent.insert(item.clientID)
            } catch {
                break  // offline: try again next time
            }
        }
        outbox.remove(clientIDs: sent)
    }

    private func applyGrants() async {
        guard let grants = try? await backend.myUnappliedGrants() else { return }
        let today = DayKey.string(for: .now)
        for r in grants {
            switch r.kind {
            case .extraTime:
                // Yesterday's minutes are gone; just acknowledge them.
                if let answered = r.answeredAt, DayKey.string(for: answered) == today,
                   let gid = r.groupID, let minutes = r.grantedMinutes {
                    _ = try? enforcer.grantCredit(groupID: gid, minutes: minutes, requestID: r.id.uuidString)
                }
            case .loosenLimit:
                if let gid = r.groupID ?? pendingGroupID(for: r) { applyApprovedEdit(groupID: gid, request: r) }
            }
            try? await backend.markApplied(r.id)
        }
    }

    /// A deleted group comes back with group_id null; find it among the pending edits.
    private func pendingGroupID(for r: RequestRow) -> UUID? {
        guard r.payload?.delete == true else { return nil }
        return PendingEdits().all().values.first(where: { $0.delete })?.group.id
    }

    private func applyApprovedEdit(groupID: UUID, request r: RequestRow) {
        var groups = enforcer.groups
        if let edit = PendingEdits().take(groupID: groupID) {
            if edit.delete {
                groups.removeAll { $0.id == groupID }
            } else if let i = groups.firstIndex(where: { $0.id == groupID }) {
                groups[i] = edit.group
            }
        } else if let p = r.payload, let i = groups.firstIndex(where: { $0.id == groupID }) {
            // App reinstalled: no local edit, so apply the numbers and keep the apps.
            if p.delete == true {
                groups.remove(at: i)
            } else {
                groups[i].dailyMinutes = p.dailyMinutes
                groups[i].window = p.windowStart.flatMap { s in p.windowEnd.map { BlockWindow(startMinute: s, endMinute: $0) } }
            }
        }
        try? enforcer.install(groups: groups)
    }
}
