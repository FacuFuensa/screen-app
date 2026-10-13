import SwiftUI

struct AnswerOtherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    let requestID: UUID
    @State private var minutes = 10
    @State private var error: String?

    var body: some View {
        Form {
            Stepper("\(minutes) min", value: $minutes, in: 1...120)
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("¿Cuánto le das?")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Dar") {
                    Task {
                        do {
                            try await app.backend.answer(requestID: requestID, grant: true, minutes: minutes)
                            await app.backend.notify(requestID: requestID)
                            dismiss()
                        } catch { self.error = error.localizedDescription }
                    }
                }
            }
        }
    }
}
