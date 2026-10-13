import Foundation
import ScreenCore

@MainActor
final class GroupsModel: ObservableObject {
    enum Outcome { case applied, sentForApproval }

    @Published private(set) var groups: [LimitGroup] = []
    @Published private(set) var pendingGroupIDs: Set<UUID> = []
    @Published private(set) var partnerGroups: [GroupRow] = []

    let enforcer = Enforcer()
    let backend = Backend.shared

    func reload() {
        groups = enforcer.groups
        pendingGroupIDs = Set(PendingEdits().all().values.map(\.group.id))
    }

    func loadRemote(partnerID: UUID?) async {
        guard let partnerID, let rows = try? await backend.remoteGroups() else { return }
        partnerGroups = rows.filter { $0.owner == partnerID }
    }

    func save(_ edited: LimitGroup, paired: Bool) async throws -> Outcome {
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
}
