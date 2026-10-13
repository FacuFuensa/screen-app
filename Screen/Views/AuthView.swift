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
        Form {
            Section {
                Picker("", selection: $creating) {
                    Text("Crear cuenta").tag(true)
                    Text("Entrar").tag(false)
                }
                .pickerStyle(.segmented)
            }
            Section {
                if creating { TextField("Tu nombre", text: $name).textContentType(.givenName) }
                TextField("Email", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Contraseña (mínimo 6)", text: $password)
                    .textContentType(creating ? .newPassword : .password)
            }
            if let error { Text(error).foregroundStyle(.red) }
            Button(creating ? "Crear cuenta" : "Entrar") { Task { await submit() } }
                .disabled(busy || email.isEmpty || password.count < 6 || (creating && name.trimmingCharacters(in: .whitespaces).isEmpty))
        }
        .navigationTitle("Screen")
    }

    private func submit() async {
        busy = true; defer { busy = false }
        do {
            if creating {
                try await app.backend.signUp(email: email, password: password, name: name.trimmingCharacters(in: .whitespaces))
            } else {
                try await app.backend.signIn(email: email, password: password)
            }
            error = nil
            await app.refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
