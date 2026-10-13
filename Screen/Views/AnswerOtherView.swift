import SwiftUI

struct AnswerOtherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @EnvironmentObject var activity: ActivityModel
    let requestID: UUID
    @State private var minutes = 10
    @State private var error: String?
    @State private var hapticTrigger = 0

    var body: some View {
        VStack(spacing: 26) {
            Text("¿Cuánto le das?").font(.system(.largeTitle, design: .rounded).bold())
            Text("\(minutes)")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.coral)
            Text("minutos").font(.headline).foregroundStyle(Theme.secondaryText)
            Stepper("Elegir minutos", value: $minutes, in: 1...120).labelsHidden().controlSize(.large)
            if let error { Text(error).foregroundStyle(.red) }
            Button("Dar \(minutes) min") { Task { await give() } }.buttonStyle(PrimaryButtonStyle())
                .disabled(activity.busy.contains(requestID))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private func give() async {
        if await activity.answer(requestID, grant: true, minutes: minutes) {
            hapticTrigger += 1
            dismiss()
        } else {
            error = activity.error
        }
    }
}
