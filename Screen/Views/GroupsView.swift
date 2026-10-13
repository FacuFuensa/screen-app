import ScreenCore
import SwiftUI

struct GroupsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var editing: LimitGroup?
    @State private var creating = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Button("Pedirle tiempo a \(partnerName)") { router.sheet = .ask(nil) }
                    .buttonStyle(PrimaryButtonStyle())

                Text("Tus límites").font(.title2.bold()).padding(.top, 8)
                if model.groups.isEmpty {
                    EmptyState(symbol: "hourglass", title: "Todavía no tenés límites",
                               message: "Creá un grupo de apps para empezar.")
                } else {
                    ForEach(model.groups.indices, id: \.self) { index in
                        let group = model.groups[index]
                        Button { editing = group } label: { ownGroupCard(group, index: index) }
                            .buttonStyle(.plain)
                    }
                }
                if model.groups.count < UsageRules.maxGroups {
                    Button { creating = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").font(.title2)
                            Text("Nuevo grupo").font(.headline)
                        }
                        .foregroundStyle(Theme.coral)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Theme.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Theme.coral.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                        }
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Avatar(name: partnerName, size: 38)
                    Text("Límites de \(partnerName)").font(.title2.bold())
                }
                .padding(.top, 14)
                if model.partnerGroups.isEmpty {
                    EmptyState(symbol: "person.crop.circle.badge.questionmark", title: "Sin límites todavía",
                               message: "Cuando \(partnerName) cree uno, aparece acá.")
                } else {
                    ForEach(model.partnerGroups) { group in
                        Card {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(group.name).font(.headline)
                                Text(summary(dailyMinutes: group.dailyMinutes, window: group.window, apps: group.appCount))
                                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .sheet(item: $editing) { group in NavigationStack { GroupEditorView(group: group) } }
        .sheet(isPresented: $creating) { NavigationStack { GroupEditorView(group: nil) } }
        .refreshable { model.reload(); await model.loadRemote(partnerID: app.partner?.id) }
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }

    private func ownGroupCard(_ group: LimitGroup, index: Int) -> some View {
        let pending = model.pendingGroupIDs.contains(group.id)
        let blocked = model.enforcer.ledger(now: .now).runtime[group.id.uuidString]?.shouldShield == true
        return Card {
            HStack(spacing: 14) {
                Image(systemName: group.dailyMinutes == nil && group.window != nil ? "moon.fill" : "hourglass")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(index.isMultiple(of: 2) ? Theme.coral : Theme.amber,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(group.name).font(.headline)
                    Text(summary(dailyMinutes: group.dailyMinutes, window: group.window, apps: group.appCount))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    if pending {
                        StatusPill(text: "Esperando a \(partnerName)", color: Theme.amber, symbol: "clock.fill")
                    } else if blocked {
                        StatusPill(text: "Bloqueado ahora", color: Theme.coral, symbol: "lock.fill")
                    } else {
                        StatusPill(text: "Activo", color: .green, symbol: "checkmark")
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func summary(dailyMinutes: Int?, window: BlockWindow?, apps: Int) -> String {
        var parts: [String] = []
        if apps > 0 { parts.append("\(apps) apps") }
        if let minutes = dailyMinutes { parts.append("\(Formatting.minutes(minutes)) por día") }
        if let window { parts.append("bloqueo \(Formatting.window(window))") }
        return parts.joined(separator: " · ")
    }
}
