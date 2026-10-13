import ScreenCore
import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var editing: LimitGroup?
    @State private var creating = false

    var body: some View {
        List {
            Section("Mis límites") {
                if model.groups.isEmpty { Text("Todavía no tenés grupos.").foregroundStyle(.secondary) }
                ForEach(model.groups) { g in
                    Button { editing = g } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.name).font(.headline)
                            Text(summary(dailyMinutes: g.dailyMinutes, window: g.window, apps: g.appCount))
                                .font(.subheadline).foregroundStyle(.secondary)
                            if model.pendingGroupIDs.contains(g.id) {
                                Label("Cambio esperando aprobación", systemImage: "clock").font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                if model.groups.count < UsageRules.maxGroups {
                    Button { creating = true } label: { Label("Nuevo grupo", systemImage: "plus") }
                }
            }
            if let partner = app.partner {
                Section("Límites de \(partner.displayName)") {
                    if model.partnerGroups.isEmpty { Text("Sin grupos todavía.").foregroundStyle(.secondary) }
                    ForEach(model.partnerGroups) { g in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(g.name).font(.headline)
                            Text(summary(dailyMinutes: g.dailyMinutes, window: g.window, apps: g.appCount))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(item: $editing) { g in NavigationStack { GroupEditorView(group: g) } }
        .sheet(isPresented: $creating) { NavigationStack { GroupEditorView(group: nil) } }
        .refreshable { model.reload(); await model.loadRemote(partnerID: app.partner?.id) }
    }

    private func summary(dailyMinutes: Int?, window: BlockWindow?, apps: Int) -> String {
        var parts = ["\(apps) apps"]
        if let m = dailyMinutes { parts.append("\(Formatting.minutes(m)) por día") }
        if let w = window { parts.append("bloqueo \(Formatting.window(w))") }
        return parts.joined(separator: " · ")
    }
}
