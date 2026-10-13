import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

struct ScreenTimeGateView: View {
    @EnvironmentObject var app: AppState
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroHeader(symbol: "checkmark.shield", title: "Dos permisos y listo", subtitle: nil)
                permissionRow(symbol: "hourglass", color: Theme.coral, title: "Tiempo en pantalla",
                              message: "Para bloquear las apps que elijas, solo en este celular.")
                permissionRow(symbol: "bell.badge.fill", color: Theme.amber, title: "Notificaciones",
                              message: "Para enterarte cuando tu dupla te pida minutos o te los dé.")
                if let error { Text(error).foregroundStyle(.red).multilineTextAlignment(.center) }
                Button("Dar permisos") { Task { await request() } }.buttonStyle(PrimaryButtonStyle())
                Text("Screen nunca ve qué hacés en tus apps.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    private func permissionRow(symbol: String, color: Color, title: String, message: String) -> some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2.bold())
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private func request() async {
        guard !Demo.isOn else { return }
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            if try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
                UIApplication.shared.registerForRemoteNotifications()
            }
            await app.refresh()
        } catch {
            self.error = "No se pudo activar Tiempo en pantalla. Revisá que no tengas restricciones en Ajustes."
        }
    }
}
