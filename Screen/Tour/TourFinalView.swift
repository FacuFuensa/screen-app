import SwiftUI

/// Shown once when the tour ends: what happens from now on.
struct TourFinalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HeroHeader(symbol: "checkmark.seal.fill", title: "¡Listo!", subtitle: "Así funciona de ahora en más:")
            row("lock.fill", "Cuando se te acaba el tiempo, la app se bloquea.")
            row("hand.raised.fill", "Desde ahí mismo le pedís minutos a tu dupla, y te los da desde su celular.")
            row("arrow.up.arrow.down", "Bajar tus límites es libre. Subirlos lo aprueba el otro.")
            Spacer()
            Button("Entendido") { dismiss() }.buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .background(Theme.background)
        .presentationDetents([.medium, .large])
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Theme.coral, in: Circle())
            Text(text).font(.body)
        }
    }
}
