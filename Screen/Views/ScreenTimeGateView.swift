import FamilyControls
import SwiftUI
import UIKit
import UserNotifications

struct ScreenTimeGateView: View {
    @EnvironmentObject var app: AppState
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hourglass").font(.system(size: 56))
            Text("Screen necesita dos permisos").font(.title2.bold())
            Text("Tiempo en pantalla, para poder bloquear tus apps, y notificaciones, para que te lleguen los pedidos de tu pareja.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            if let error { Text(error).foregroundStyle(.red).multilineTextAlignment(.center) }
            Button("Dar permisos") { Task { await request() } }.buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private func request() async {
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
