import SwiftUI

struct PairingView: View {
    @EnvironmentObject var app: AppState
    @State private var code: String?
    @State private var entered = ""
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroHeader(symbol: "person.2.fill", title: "Invitá a tu dupla",
                           subtitle: "Screen funciona de a dos: cada uno pone sus límites y el otro aprueba los minutos extra.")
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
                            Button("Crear código") { Task { await run { code = try await app.backend.createInvite() } } }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("¿Te pasaron un código?").font(.title3.bold())
                        TextField("6 dígitos", text: $entered).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        Button("Unirme") {
                            Task {
                                guard !Demo.isOn else { return }
                                await run { try await app.backend.joinPair(code: joinCode); await app.refresh() }
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(joinCode.count != 6)
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .padding(24)
        }
        .background(Theme.background)
        .task {
            while !Task.isCancelled && app.phase == .unpaired {
                try? await Task.sleep(for: .seconds(4))
                await app.refresh()
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
        do { try await work(); error = nil } catch { self.error = error.localizedDescription }
    }
}
