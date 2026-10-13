import ScreenCore
import SwiftUI

struct FeedView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var rows: [EventRow] = []

    var body: some View {
        List(rows) { e in
            VStack(alignment: .leading, spacing: 2) {
                Text(FeedWording.describe(kind: e.kind, actor: name(e.actor), group: groupName(e.groupID), minutes: e.data.minutes))
                Text(e.createdAt, style: .relative).font(.caption).foregroundStyle(.secondary)
            }
        }
        .overlay { if rows.isEmpty { Text("Todavía no pasó nada.").foregroundStyle(.secondary) } }
        .task { await load() }
        .refreshable { await load() }
    }

    private func name(_ id: UUID) -> String {
        id == app.me?.id ? "Vos" : (app.partner?.displayName ?? "Tu pareja")
    }

    private func groupName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return model.groups.first { $0.id == id }?.name ?? model.partnerGroups.first { $0.id == id }?.name
    }

    private func load() async { rows = (try? await app.backend.events()) ?? rows }
}
