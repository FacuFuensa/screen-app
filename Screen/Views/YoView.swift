import ScreenCore
import SwiftUI

/// The "Yo" tab: only my own limits, in my color, plus what I am waiting for.
struct YoView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @EnvironmentObject var activity: ActivityModel
    @State private var editing: LimitGroup?
    @State private var creating = false
    @State private var cancellingGroup: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                askSection
                Text("Tus límites").font(.title2.bold()).padding(.top, 6)
                if model.groups.isEmpty {
                    EmptyState(symbol: "hourglass", title: "Todavía no tenés límites",
                               message: "Creá uno para elegir qué apps controlar y cuánto tiempo por día.")
                }
                ForEach(model.groups) { group in
                    MyLimitCard(group: group,
                                pending: model.pendingByGroup[group.id],
                                blocked: model.enforcer.ledger(now: .now).runtime[group.id.uuidString]?.shouldShield == true,
                                partnerName: partnerName,
                                cancelling: cancellingGroup == group.id,
                                onOpen: { editing = group },
                                onCancel: { Task { await cancelPending(group.id) } })
                }
                if model.groups.count < UsageRules.maxGroups {
                    Button { creating = true; TourController.shared.complete(.newLimit) } label: { newLimitTile }.buttonStyle(.plain).tourAnchor(.newLimit)
                }
                if !app.isPaired {
                    Button { router.tab = .partner; TourController.shared.complete(.invite) } label: { inviteTile }.buttonStyle(.plain).tourAnchor(.invite)
                }
                if let error = activity.error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(16)
        }
        .background(Theme.background)
        .tourHost()
        .sheet(item: $editing) { group in NavigationStack { GroupEditorView(group: group) } }
        .sheet(isPresented: $creating) { NavigationStack { GroupEditorView(group: nil) } }
        .refreshable { model.reload(); await activity.load() }
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }

    @ViewBuilder private var askSection: some View {
        if let own = activity.ownPendingExtra(me: app.me?.id) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    StatusPill(text: "Le pediste \(own.minutes ?? 0) min a \(partnerName)", color: Theme.amber, symbol: "clock.fill")
                    Text("Esperando que responda. Te avisamos con una notificación.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    Button(activity.busy.contains(own.id) ? "Cancelando…" : "Cancelar pedido") {
                        Task { await activity.cancel(own.id) }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(activity.busy.contains(own.id))
                }
            }
        } else {
            Button("Pedirle tiempo a \(partnerName)") { router.sheet = .ask(nil) }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!app.isPaired || model.groups.isEmpty)
            if !app.isPaired {
                Text("Primero invitá a tu dupla.").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var newLimitTile: some View {
        HStack {
            Image(systemName: "plus.circle.fill").font(.title2)
            Text("Nuevo límite").font(.headline)
        }
        .foregroundStyle(Theme.coral)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Theme.card.opacity(0.65), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.coral.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [7]))
        }
    }

    private var inviteTile: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "person.badge.plus")
                    .font(.title2.bold()).foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Theme.amber, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invitá a tu dupla").font(.headline)
                    Text("Screen funciona de a dos: la otra persona aprueba tus minutos extra.")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func cancelPending(_ groupID: UUID) async {
        guard cancellingGroup == nil else { return }
        cancellingGroup = groupID
        defer { cancellingGroup = nil }
        do { try await model.cancelPending(groupID: groupID) } catch { activity.error = error.localizedDescription }
        await activity.load()
    }
}

/// One of my limits: coral strip, status, and the pending request with a way back.
struct MyLimitCard: View {
    let group: LimitGroup
    let pending: PendingLoosen?
    let blocked: Bool
    let partnerName: String
    let cancelling: Bool
    let onOpen: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: group.dailyMinutes == nil && group.window != nil ? "moon.fill" : "hourglass")
                        .font(.title2.bold()).foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name).font(.headline)
                        Text(LimitText.summary(group)).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onOpen)
                if let pending {
                    StatusPill(text: "Esperando a \(partnerName)", color: Theme.amber, symbol: "clock.fill")
                    Text(LimitText.change(from: group, to: pending.edit))
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    Button(cancelling ? "Cancelando…" : "Cancelar pedido", action: onCancel)
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(cancelling)
                } else if blocked {
                    StatusPill(text: "Bloqueado ahora", color: Theme.coral, symbol: "lock.fill")
                } else {
                    StatusPill(text: "Activo", color: .green, symbol: "checkmark")
                }
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(Theme.coral).frame(width: 5).padding(.vertical, 16)
        }
    }
}
