import SwiftUI

struct AuthView: View {
    @EnvironmentObject var app: AppState
    @State private var creating = true
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HeroHeader(symbol: "hourglass", title: "Screen", subtitle: "Tu tiempo en pantalla, de a dos.")
                Text("Para hacerlo con un amigo, tu hermana, tu pareja o quien quieras.")
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                Picker("", selection: $creating) {
                    Text("Crear cuenta").tag(true)
                    Text("Entrar").tag(false)
                }
                .pickerStyle(.segmented)
                Card {
                    VStack(spacing: 14) {
                        if creating {
                            TextField("Tu nombre", text: $name).textContentType(.givenName)
                            Divider()
                        }
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Divider()
                        SecureField("Contraseña (mínimo 6)", text: $password)
                            .textContentType(creating ? .newPassword : .password)
                    }
                }
                if let error { Text(error).foregroundStyle(.red).multilineTextAlignment(.center) }
                Button(creating ? "Crear cuenta" : "Entrar") { Task { await submit() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy || email.isEmpty || password.count < 6 || (creating && name.trimmingCharacters(in: .whitespaces).isEmpty))
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
    }

    private func submit() async {
        guard !Demo.isOn else { return }
        busy = true; defer { busy = false }
        do {
            if creating {
                try await app.backend.signUp(email: email, password: password, name: name.trimmingCharacters(in: .whitespaces))
            } else {
                try await app.backend.signIn(email: email, password: password)
            }
            error = nil
            await app.refresh()
        } catch { self.error = error.localizedDescription }
    }
}
