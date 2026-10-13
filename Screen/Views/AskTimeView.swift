import ScreenCore
import SwiftUI

struct AskTimeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var groupID: UUID?
    @State private var minutes = 15
    @State private var message = ""
    @State private var sending = false
    @State private var error: String?
    @State private var hapticTrigger = 0

    init(preselected: UUID?) { _groupID = State(initialValue: preselected) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeroHeader(symbol: "hand.raised.fill", title: "¿Cuánto necesitás?",
                           subtitle: "Le avisamos a \(partnerName) al toque.")
                Text("Elegí el grupo").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.groups) { group in
                            Chip(title: group.name, isSelected: groupID == group.id) { groupID = group.id }
                        }
                    }
                    .padding(.vertical, 2)
                }
                Text("Minutos").font(.headline)
                HStack(spacing: 10) {
                    ForEach(UsageRules.extraTimeOptions, id: \.self) { option in
                        Chip(title: "\(option) min", isSelected: minutes == option) { minutes = option }
                            .frame(maxWidth: .infinity)
                    }
                }
                Card {
                    TextField("¿Para qué? (opcional)", text: $message, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .onChange(of: message) { _, value in if value.count > 140 { message = String(value.prefix(140)) } }
                }
                if let error { Text(error).foregroundStyle(.red) }
                Button("Pedirle a \(partnerName)") { Task { await send() } }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(groupID == nil || sending)
            }
            .padding(24)
        }
        .background(Theme.background)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        .onAppear { model.reload() }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }

    private func send() async {
        guard let groupID else { return }
        if Demo.isOn { hapticTrigger += 1; dismiss(); return }
        sending = true; defer { sending = false }
        do {
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = try await app.backend.requestExtra(groupID: groupID, minutes: minutes, message: text.isEmpty ? nil : text)
            await app.backend.notify(requestID: id)
            hapticTrigger += 1
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
