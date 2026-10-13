import ScreenCore
import SwiftUI

struct FeedView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var rows: [EventRow] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if rows.isEmpty {
                    EmptyState(symbol: "sparkles", title: "Todavía no pasó nada",
                               message: "Acá vas a ver lo que pasa entre vos y \(partnerName).")
                } else {
                    ForEach(rows) { event in
                        HStack(alignment: .top, spacing: 13) {
                            let appearance = appearance(event.kind)
                            Image(systemName: appearance.symbol)
                                .font(.body.bold())
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(appearance.color, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text(FeedWording.describe(kind: event.kind, actor: name(event.actor),
                                                         group: groupName(event.groupID), minutes: event.data.minutes))
                                    .font(.subheadline.weight(.medium))
                                Text(event.createdAt, style: .relative).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                        if event.id != rows.last?.id { Divider().padding(.leading, 51) }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .task { await load() }
        .refreshable { await load() }
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }

    private func name(_ id: UUID) -> String {
        id == app.me?.id ? "Vos" : (app.partner?.displayName ?? "Tu dupla")
    }

    private func groupName(_ id: UUID?) -> String? {
        guard let id else { return nil }
        return model.groups.first { $0.id == id }?.name ?? model.partnerGroups.first { $0.id == id }?.name
    }

    private func appearance(_ kind: String) -> (symbol: String, color: Color) {
        switch kind {
        case "limit_reached": return ("hourglass.bottomhalf.filled", Theme.coral)
        case "threshold_80": return ("gauge.with.dots.needle.67percent", Theme.amber)
        case "wildcard_used": return ("sparkles", Theme.amber)
        case "auth_revoked": return ("exclamationmark.shield.fill", .red)
        case "silent_24h": return ("moon.zzz.fill", .gray)
        case "request_granted": return ("checkmark.circle.fill", .green)
        case "request_denied": return ("xmark.circle.fill", .gray)
        case "limit_tightened": return ("arrow.down.circle.fill", Theme.ink)
        case "group_created": return ("plus.circle.fill", Theme.coral)
        default: return ("circle.fill", Theme.ink)
        }
    }

    private func load() async {
        if Demo.isOn { rows = Demo.events; return }
        rows = (try? await app.backend.events()) ?? rows
    }
}
