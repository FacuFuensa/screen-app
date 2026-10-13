import Foundation
import ScreenCore

/// A loosening of one of my limits that is waiting for the partner.
struct PendingLoosen: Equatable {
    let requestID: UUID
    let edit: PendingEdit
}

@MainActor
final class GroupsModel: ObservableObject {
    enum Outcome { case applied, sentForApproval }

    @Published private(set) var groups: [LimitGroup] = []
    @Published private(set) var pendingByGroup: [UUID: PendingLoosen] = [:]
    var pendingGroupIDs: Set<UUID> { Set(pendingByGroup.keys) }
    @Published private(set) var partnerGroups: [GroupRow] = []

    let enforcer = Enforcer()
    let backend = Backend.shared

    func reload() {
        if Demo.isOn {
            groups = Demo.myGroups
            pendingByGroup = Demo.pendingLoosen
            return
        }
        groups = enforcer.groups
        var pending: [UUID: PendingLoosen] = [:]
        for (key, edit) in PendingEdits().all() {
            guard let requestID = UUID(uuidString: key) else { continue }
            pending[edit.group.id] = PendingLoosen(requestID: requestID, edit: edit)
        }
        pendingByGroup = pending
    }

    func loadRemote(partnerID: UUID?) async {
        if Demo.isOn {
            partnerGroups = Demo.partnerGroups
            return
        }
        guard let partnerID, let rows = try? await backend.remoteGroups() else { return }
        partnerGroups = rows.filter { $0.owner == partnerID }
    }

    func save(_ edited: LimitGroup, paired: Bool) async throws -> Outcome {
        if Demo.isOn {
            if let index = groups.firstIndex(where: { $0.id == edited.id }) { groups[index] = edited } else { groups.append(edited) }
            pendingByGroup[edited.id] = nil
            return .applied
        }
        let old = groups.first { $0.id == edited.id }
        let verdict = old.map { LimitChange.classify(from: $0.config, to: edited.config) } ?? .tightening
        let removesApps = old.map { LimitChange.removesApps(from: $0.config, to: edited.config) } ?? false

        if verdict == .loosening && paired {
            let id = try await backend.requestLoosen(groupID: edited.id, payload: LoosenPayload(edited), message: nil)
            PendingEdits().set(PendingEdit(group: edited, delete: false), requestID: id)
            await backend.notify(requestID: id)
            reload()
            return .sentForApproval
        }

        // Tightening never waits for the network.
        var next = groups
        if let i = next.firstIndex(where: { $0.id == edited.id }) { next[i] = edited } else { next.append(edited) }
        try enforcer.install(groups: next)
        reload()
        // The mirror catches up on the next sync if this fails.
        _ = try? await backend.saveGroup(edited, removesApps: removesApps)
        return .applied
    }

    func delete(_ group: LimitGroup, paired: Bool) async throws -> Outcome {
        if Demo.isOn {
            groups.removeAll { $0.id == group.id }
            pendingByGroup[group.id] = nil
            return .applied
        }
        if paired {
            let id = try await backend.requestLoosen(groupID: group.id, payload: LoosenPayload(group, delete: true), message: nil)
            PendingEdits().set(PendingEdit(group: group, delete: true), requestID: id)
            await backend.notify(requestID: id)
            reload()
            return .sentForApproval
        }
        try enforcer.install(groups: groups.filter { $0.id != group.id })
        reload()
        try? await backend.deleteGroup(group.id)
        return .applied
    }

    /// True when `draft` shares an app, category or website with another group.
    func overlaps(_ draft: LimitGroup) -> Bool {
        groups.contains { group in
            guard group.id != draft.id else { return false }
            return !group.selection.applicationTokens.isDisjoint(with: draft.selection.applicationTokens)
                || !group.selection.categoryTokens.isDisjoint(with: draft.selection.categoryTokens)
                || !group.selection.webDomainTokens.isDisjoint(with: draft.selection.webDomainTokens)
        }
    }

    /// Takes back a pending loosening; the limit simply stays as it is.
    func cancelPending(groupID: UUID) async throws {
        guard let pending = pendingByGroup[groupID] else { return }
        if !Demo.isOn { try await backend.cancelRequest(pending.requestID) }
        _ = PendingEdits().take(requestID: pending.requestID)
        if Demo.isOn { pendingByGroup[groupID] = nil } else { reload() }
    }
}
