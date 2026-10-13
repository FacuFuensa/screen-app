import ScreenCore
import SwiftUI

/// Everything about the other person: what they are asking me, their limits, and
/// what happened lately. Before pairing, the invitation.
struct PartnerView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @EnvironmentObject var activity: ActivityModel
    @State private var hapticTrigger = 0

    var body: some View {
        if app.isPaired { content } else { InviteView() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let incoming = activity.incoming(from: app.partner?.id)
                if !incoming.isEmpty {
                    Text("\(name) te pide").font(.title2.bold())
                    ForEach(incoming) { request in
                        IncomingRequestCard(
                            request: request,
                            partnerName: name,
                            groupName: groupName(request.groupID),
                            change: request.kind == .loosenLimit ? request.payload.map { diff(request, $0) } : nil,
                            busy: activity.busy.contains(request.id),
                            onGrant: { Task { if await activity.answer(request.id, grant: true) { hapticTrigger += 1 } } },
                            onOther: { router.sheet = .answer(request.id) },
                            onDeny: { Task { if await activity.answer(request.id, grant: false) { hapticTrigger += 1 } } })
                    }
                }

                Text("Límites de \(name)").font(.title2.bold()).padding(.top, incoming.isEmpty ? 0 : 8)
                if model.partnerGroups.isEmpty {
                    EmptyState(symbol: "person.crop.circle.badge.questionmark", title: "Sin límites todavía",
                               message: "Cuando \(name) cree uno, aparece acá.")
                }
                ForEach(model.partnerGroups) { group in
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.name).font(.headline)
                            Text(LimitText.summary(group)).font(.subheadline).foregroundStyle(Theme.secondaryText)
                            if reachedToday(group.id) {
                                StatusPill(text: "Llegó al límite hoy", color: Theme.coral, symbol: "hourglass.bottomhalf.filled")
                            }
                        }
                    }
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.amber).frame(width: 5).padding(.vertical, 16)
                    }
                }

                Text("Lo último").font(.title2.bold()).padding(.top, 8)
                if activity.events.isEmpty {
                    EmptyState(symbol: "sparkles", title: "Todavía no pasó nada",
                               message: "Acá vas a ver lo que pasa entre vos y \(name).")
                } else {
                    Card {
                        VStack(spacing: 0) {
                            let recent = Array(activity.events.prefix(10))
                            ForEach(recent) { event in
                                EventRowView(event: event,
                                             text: FeedWording.describe(kind: event.kind, actor: actorName(event.actor),
                                                                        group: groupName(event.groupID), minutes: event.data.minutes,
                                                                        isMe: event.actor == app.me?.id))
                                if event.id != recent.last?.id { Divider().padding(.leading, 51) }
                            }
                        }
                    }
                }
                if let error = activity.error { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            .padding(16)
        }
        .background(Theme.background)
        .refreshable { await activity.load(); await model.loadRemote(partnerID: app.partner?.id) }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private var name: String { app.partner?.displayName ?? "tu dupla" }

    private func actorName(_ id: UUID) -> String { id == app.me?.id ? "Vos" : name }

    private func groupName(_ id: UUID?) -> String {
        guard let id else { return "un límite borrado" }
        return model.partnerGroups.first { $0.id == id }?.name ?? model.groups.first { $0.id == id }?.name ?? "un límite"
    }

    private func reachedToday(_ groupID: UUID) -> Bool {
        activity.events.contains {
            $0.kind == "limit_reached" && $0.actor == app.partner?.id && $0.groupID == groupID
                && Calendar.current.isDateInToday($0.createdAt)
        }
    }

    private func diff(_ request: RequestRow, _ payload: PayloadRow) -> String {
        if payload.delete == true { return "Borrar el límite" }
        guard let current = model.partnerGroups.first(where: { $0.id == request.groupID }) else { return "" }
        let before = Formatting.limitSummary(dailyMinutes: current.dailyMinutes, window: current.window)
        let newWindow = payload.windowStart.flatMap { start in payload.windowEnd.map { BlockWindow(startMinute: start, endMinute: $0) } }
        let after = Formatting.limitSummary(dailyMinutes: payload.dailyMinutes, window: newWindow)
        if before != after { return "\(before) → \(after)" }
        if let count = payload.appCount, count != current.appCount { return "\(current.appCount) → \(count) apps" }
        return "Cambia qué apps entran"
    }
}

/// A request waiting for my answer; every button locks while the answer is in flight.
struct IncomingRequestCard: View {
    let request: RequestRow
    let partnerName: String
    let groupName: String
    let change: String?
    let busy: Bool
    let onGrant: () -> Void
    let onOther: () -> Void
    let onDeny: () -> Void

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Avatar(name: partnerName, size: 42)
                    Text(FeedWording.requestTitle(extraMinutes: request.kind == .extraTime ? (request.minutes ?? 0) : nil,
                                                  group: groupName, actor: partnerName, isMe: false))
                        .font(.headline)
                }
                if let change { Text(change).font(.subheadline).foregroundStyle(Theme.secondaryText) }
                if let message = request.message {
                    Text("“\(message)”")
                        .font(.subheadline)
                        .padding(11)
                        .background(Theme.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: 8) {
                    Button(action: onGrant) {
                        if busy { ProgressView().tint(.white) } else {
                            Text(request.kind == .extraTime ? "Dar \(request.minutes ?? 0) min" : "Aprobar")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if request.kind == .extraTime {
                        Button("Otra", action: onOther).buttonStyle(SecondaryButtonStyle())
                    }
                    Button("No", role: .destructive, action: onDeny)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(minWidth: 50, minHeight: 52)
                        .background(Color.red.opacity(0.11), in: Capsule())
                }
                .disabled(busy)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.amber, lineWidth: 2)
        }
    }
}

/// One line of "Lo último".
struct EventRowView: View {
    let event: EventRow
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            let look = appearance(event.kind)
            Image(systemName: look.symbol)
                .font(.body.bold()).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(look.color, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(text).font(.subheadline.weight(.medium))
                // "hace 20 minutos", in Spanish whatever the device language is.
                Text(event.createdAt.formatted(.relative(presentation: .named).locale(Locale(identifier: "es_AR"))))
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
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
}
