import ScreenCore
import SwiftUI

struct RequestsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var router: Router
    @EnvironmentObject var model: GroupsModel
    @State private var rows: [RequestRow] = []
    @State private var error: String?

    var body: some View {
        List {
            let incoming = rows.filter { $0.fromUser == app.partner?.id && $0.effectiveStatus() == .pending }
            Section("Para responder") {
                if incoming.isEmpty { Text("Nada pendiente.").foregroundStyle(.secondary) }
                ForEach(incoming) { r in incomingRow(r) }
            }
            Section("Historial") {
                ForEach(rows.filter { !incoming.map(\.id).contains($0.id) }) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(r)).font(.subheadline)
                        Text(statusText(r)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder private func incomingRow(_ r: RequestRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title(r)).font(.headline)
            if r.kind == .loosenLimit, let p = r.payload { Text(diff(r, p)).font(.subheadline) }
            if let m = r.message { Text("“\(m)”").font(.subheadline).italic() }
            HStack {
                Button(r.kind == .extraTime ? "Dar \(r.minutes ?? 0) min" : "Aprobar") { Task { await answer(r, true) } }
                    .buttonStyle(.borderedProminent)
                if r.kind == .extraTime { Button("Otra") { router.sheet = .answer(r.id) }.buttonStyle(.bordered) }
                Button("No", role: .destructive) { Task { await answer(r, false) } }.buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }

    private func groupName(_ id: UUID?) -> String {
        guard let id else { return "un grupo borrado" }
        return model.partnerGroups.first { $0.id == id }?.name ?? model.groups.first { $0.id == id }?.name ?? "un grupo"
    }

    private func who(_ r: RequestRow) -> String {
        r.fromUser == app.me?.id ? "Vos" : (app.partner?.displayName ?? "Tu pareja")
    }

    private func title(_ r: RequestRow) -> String {
        switch r.kind {
        case .extraTime: return "\(who(r)) pidió \(r.minutes ?? 0) min en \(groupName(r.groupID))"
        case .loosenLimit: return "\(who(r)) quiere aflojar \(groupName(r.groupID))"
        }
    }

    private func diff(_ r: RequestRow, _ p: PayloadRow) -> String {
        if p.delete == true { return "Borrar el grupo" }
        guard let current = model.partnerGroups.first(where: { $0.id == r.groupID }) else { return "" }
        var parts: [String] = []
        if current.dailyMinutes != p.dailyMinutes {
            parts.append("\(current.dailyMinutes.map(Formatting.minutes) ?? "sin límite") → \(p.dailyMinutes.map(Formatting.minutes) ?? "sin límite")")
        }
        let newWindow = p.windowStart.flatMap { s in p.windowEnd.map { BlockWindow(startMinute: s, endMinute: $0) } }
        if current.window != newWindow {
            parts.append("bloqueo \(current.window.map(Formatting.window) ?? "sin horario") → \(newWindow.map(Formatting.window) ?? "sin horario")")
        }
        if let n = p.appCount, n != current.appCount { parts.append("\(current.appCount) → \(n) apps") }
        return parts.isEmpty ? "Cambia qué apps entran" : parts.joined(separator: " · ")
    }

    private func statusText(_ r: RequestRow) -> String {
        switch r.effectiveStatus() {
        case .pending: return "Esperando respuesta"
        case .granted: return r.grantedMinutes.map { "Aprobado: \($0) min" } ?? "Aprobado"
        case .denied: return "Rechazado"
        case .superseded: return "Reemplazado por otro pedido"
        case .expired: return "Venció sin respuesta"
        }
    }

    private func load() async {
        do { rows = try await app.backend.requests(); error = nil } catch { self.error = error.localizedDescription }
        await model.loadRemote(partnerID: app.partner?.id)
    }

    private func answer(_ r: RequestRow, _ grant: Bool) async {
        do {
            try await app.backend.answer(requestID: r.id, grant: grant, minutes: nil)
            await app.backend.notify(requestID: r.id)
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
