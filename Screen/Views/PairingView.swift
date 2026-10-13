import SwiftUI

struct PairingView: View {
    @EnvironmentObject var app: AppState
    @State private var code: String?
    @State private var entered = ""
    @State private var error: String?

    var body: some View {
        Form {
            Section("Invitar a tu pareja") {
                if let code = code ?? app.pair?.inviteCode {
                    Text(code).font(.system(size: 40, weight: .bold, design: .monospaced)).frame(maxWidth: .infinity)
                    Text("Pasale este código. Esta pantalla avanza sola cuando lo use.").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Button("Crear código") { Task { await run { code = try await app.backend.createInvite() } } }
                }
            }
            Section("Tengo un código") {
                TextField("6 dígitos", text: $entered).keyboardType(.numberPad)
                Button("Unirme") { Task { await run { try await app.backend.joinPair(code: entered); await app.refresh() } } }
                    .disabled(entered.count != 6)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Emparejar")
        .task {
            while !Task.isCancelled && app.phase == .unpaired {
                try? await Task.sleep(for: .seconds(4))
                await app.refresh()
            }
        }
    }

    private func run(_ work: () async throws -> Void) async {
        do { try await work(); error = nil } catch { self.error = error.localizedDescription }
    }
}
