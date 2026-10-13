import SwiftUI

/// Shown in the partner tab until there is someone on the other side.
struct InviteView: View {
    @EnvironmentObject var app: AppState
    @State private var code: String?
    @State private var entered = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroHeader(symbol: "person.2.fill", title: "Invitá a tu dupla",
                           subtitle: "Cada uno pone sus límites y el otro aprueba los minutos extra.")
                inviteCards
                if let error { Text(error).foregroundStyle(.red) }
            }
            .padding(24)
        }
        .background(Theme.background)
        .task {
            // Notice when the other person uses the code, without any tapping.
            while !Task.isCancelled && !app.isPaired && !Demo.isOn {
                try? await Task.sleep(for: .seconds(4))
                await app.refresh()
            }
        }
    }

    var inviteCards: some View {
        VStack(spacing: 16) {
            Card {
                VStack(spacing: 16) {
                    if let rawCode = shownCode {
                        Text(format(rawCode))
                            .font(.system(size: 38, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .frame(maxWidth: .infinity)
                        ShareLink(item: "Sumate a mi dupla en Screen con el código \(format(rawCode))") {
                            Label("Compartir código", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Esperando que lo use…")
                        }
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                    } else {
                        Button(working ? "Creando…" : "Crear código") {
                            Task { await run { code = try await app.backend.createInvite() } }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(working)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("¿Te pasaron un código?").font(.title3.bold())
                    TextField("6 dígitos", text: $entered).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    Button(working ? "Uniéndote…" : "Unirme") {
                        Task {
                            guard !Demo.isOn else { return }
                            await run { try await app.backend.joinPair(code: joinCode); await app.refresh() }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(joinCode.count != 6 || working)
                }
            }
        }
    }

    private var shownCode: String? { Demo.isOn ? "482913" : (code ?? app.pair?.inviteCode) }
    private var joinCode: String { entered.filter(\.isNumber) }

    private func format(_ code: String) -> String {
        let digits = code.filter(\.isNumber)
        guard digits.count == 6 else { return code }
        return "\(digits.prefix(3)) \(digits.suffix(3))"
    }

    private func run(_ work: () async throws -> Void) async {
        guard !working else { return }
        working = true
        defer { working = false }
        do { try await work(); error = nil } catch { self.error = error.localizedDescription }
    }
}
