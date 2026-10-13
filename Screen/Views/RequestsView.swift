import ScreenCore
import SwiftUI

struct RequestsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var rows: [RequestRow] = []
    @State private var error: String?
    @State private var hapticTrigger = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text("Para responder").font(.title2.bold())
                if incoming.isEmpty {
                    EmptyState(symbol: "hand.thumbsup", title: "Nada para responder",
                               message: "Cuando \(partnerName) te pida tiempo, aparece acá.")
                } else {
                    ForEach(incoming) { request in incomingCard(request) }
                }

                Text("Historial").font(.title2.bold()).padding(.top, 10)
                if history.isEmpty {
                    Text("Todavía no hay pedidos anteriores.").foregroundStyle(Theme.secondaryText)
                } else {
                    Card {
                        VStack(spacing: 0) {
                            ForEach(history.indices, id: \.self) { index in
                                let request = history[index]
                                historyRow(request)
                                if index < history.count - 1 { Divider().padding(.vertical, 10) }
                            }
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .padding(16)
        }
        .background(Theme.background)
        .task { await load() }
        .refreshable { await load() }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }
    private var incoming: [RequestRow] {
        rows.filter { $0.fromUser == app.partner?.id && $0.effectiveStatus() == .pending }
    }
    private var history: [RequestRow] {
        let ids = Set(incoming.map(\.id))
        return rows.filter { !ids.contains($0.id) }
    }

    private func incomingCard(_ request: RequestRow) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Avatar(name: partnerName, size: 42)
                    Text(title(request)).font(.headline)
                }
                if request.kind == .loosenLimit, let payload = request.payload {
                    Text(diff(request, payload)).font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                if let message = request.message {
                    Text("“\(message)”")
                        .font(.subheadline)
                        .padding(11)
                        .background(Theme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                HStack(spacing: 8) {
                    Button(request.kind == .extraTime ? "Dar \(request.minutes ?? 0) min" : "Aprobar") {
                        Task { await answer(request, true) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    if request.kind == .extraTime {
                        Button("Otra") { router.sheet = .answer(request.id) }.buttonStyle(SecondaryButtonStyle())
                    }
                    Button("No", role: .destructive) { Task { await answer(request, false) } }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(minWidth: 50, minHeight: 52)
                        .background(Color.red.opacity(0.11), in: Capsule())
                }
            }
        }
    }

    private func historyRow(_ request: RequestRow) -> some View {
        HStack(spacing: 11) {
            Image(systemName: statusAppearance(request).symbol)
                .foregroundStyle(statusAppearance(request).color)
                .frame(width: 30, height: 30)
                .background(statusAppearance(request).color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title(request)).font(.subheadline.weight(.medium))
                Text(statusText(request)).font(.caption).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func groupName(_ id: UUID?) -> String {
        guard let id else { return "un grupo borrado" }
        return model.partnerGroups.first { $0.id == id }?.name ?? model.groups.first { $0.id == id }?.name ?? "un grupo"
    }

    private func who(_ request: RequestRow) -> String {
        request.fromUser == app.me?.id ? "Vos" : (app.partner?.displayName ?? "Tu dupla")
    }

    private func title(_ request: RequestRow) -> String {
        FeedWording.requestTitle(extraMinutes: request.kind == .extraTime ? (request.minutes ?? 0) : nil,
                                 group: groupName(request.groupID), actor: who(request),
                                 isMe: request.fromUser == app.me?.id)
    }

    private func diff(_ request: RequestRow, _ payload: PayloadRow) -> String {
        if payload.delete == true { return "Borrar el grupo" }
        guard let current = model.partnerGroups.first(where: { $0.id == request.groupID }) else { return "" }
        var parts: [String] = []
        if current.dailyMinutes != payload.dailyMinutes {
            parts.append("\(current.dailyMinutes.map(Formatting.minutes) ?? "sin límite") → \(payload.dailyMinutes.map(Formatting.minutes) ?? "sin límite")")
        }
        let newWindow = payload.windowStart.flatMap { start in payload.windowEnd.map { BlockWindow(startMinute: start, endMinute: $0) } }
        if current.window != newWindow {
            parts.append("bloqueo \(current.window.map(Formatting.window) ?? "sin horario") → \(newWindow.map(Formatting.window) ?? "sin horario")")
        }
        if let count = payload.appCount, count != current.appCount { parts.append("\(current.appCount) → \(count) apps") }
        return parts.isEmpty ? "Cambia qué apps entran" : parts.joined(separator: " · ")
    }

    private func statusText(_ request: RequestRow) -> String {
        switch request.effectiveStatus() {
        case .pending: return "Esperando respuesta"
        case .granted: return request.grantedMinutes.map { "Aprobado: \($0) min" } ?? "Aprobado"
        case .denied: return "Rechazado"
        case .superseded: return "Reemplazado por otro pedido"
        case .expired: return "Venció sin respuesta"
        }
    }

    private func statusAppearance(_ request: RequestRow) -> (symbol: String, color: Color) {
        switch request.effectiveStatus() {
        case .granted: return ("checkmark.circle.fill", .green)
        case .denied, .superseded, .expired: return ("xmark.circle.fill", .gray)
        case .pending: return ("clock.fill", Theme.amber)
        }
    }

    private func load() async {
        if Demo.isOn {
            rows = Demo.requests
            error = nil
        } else {
            do { rows = try await app.backend.requests(); error = nil } catch { self.error = error.localizedDescription }
        }
        router.incomingCount = incoming.count
        await model.loadRemote(partnerID: app.partner?.id)
    }

    private func answer(_ request: RequestRow, _ grant: Bool) async {
        do {
            if !Demo.isOn {
                try await app.backend.answer(requestID: request.id, grant: grant, minutes: nil)
                await app.backend.notify(requestID: request.id)
                await load()
            }
            hapticTrigger += 1
        } catch { self.error = error.localizedDescription }
    }
}
