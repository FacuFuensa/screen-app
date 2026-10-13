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
        await dropAnsweredEdits()
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
            do {
                switch r.kind {
                case .extraTime:
                    // Yesterday's minutes are gone; just acknowledge them.
                    if let answered = r.answeredAt, DayKey.string(for: answered) == today,
                       let gid = r.groupID, let minutes = r.grantedMinutes {
                        _ = try enforcer.grantCredit(groupID: gid, minutes: minutes, requestID: r.id.uuidString)
                    }
                case .loosenLimit:
                    try applyApprovedEdit(request: r)
                }
            } catch {
                continue  // Keep it unapplied so the next sync retries.
            }
            try? await backend.markApplied(r.id)
        }
    }

    private func dropAnsweredEdits() async {
        guard let me = await backend.currentUserID(), let requests = try? await backend.requests() else { return }
        for r in requests where r.fromUser == me {
            guard case .loosenLimit = r.kind else { continue }
            switch r.effectiveStatus() {
            case .denied, .superseded, .expired, .cancelled:
                _ = PendingEdits().take(requestID: r.id)
            case .pending, .granted:
                break
            }
        }
    }

    private func applyApprovedEdit(request r: RequestRow) throws {
        var groups = enforcer.groups
        let pending = PendingEdits()
        if let edit = pending.take(requestID: r.id) {
            if edit.delete {
                groups.removeAll { $0.id == edit.group.id }
            } else if let i = groups.firstIndex(where: { $0.id == edit.group.id }) {
                groups[i] = edit.group
            }
            do {
                try enforcer.install(groups: groups)
            } catch {
                pending.set(edit, requestID: r.id)
                throw error
            }
            return
        }

        guard let groupID = r.groupID, let p = r.payload,
              let i = groups.firstIndex(where: { $0.id == groupID }) else { return }
        // App reinstalled: no local edit, so apply the numbers and keep the apps.
        if p.delete == true {
            groups.remove(at: i)
        } else {
            groups[i].dailyMinutes = p.dailyMinutes
            groups[i].window = p.windowStart.flatMap { s in p.windowEnd.map { BlockWindow(startMinute: s, endMinute: $0) } }
        }
        try enforcer.install(groups: groups)
    }
}
