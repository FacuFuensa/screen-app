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

    init(preselected: UUID?) { _groupID = State(initialValue: preselected) }

    var body: some View {
        Form {
            Picker("Grupo", selection: $groupID) {
                Text("Elegí uno").tag(UUID?.none)
                ForEach(model.groups) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker("Minutos", selection: $minutes) {
                ForEach(UsageRules.extraTimeOptions, id: \.self) { Text("\($0) min").tag($0) }
            }
            .pickerStyle(.segmented)
            TextField("Mensaje (opcional)", text: $message, axis: .vertical)
                .onChange(of: message) { _, v in if v.count > 140 { message = String(v.prefix(140)) } }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Pedir tiempo")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Pedir") { Task { await send() } }.disabled(groupID == nil || sending)
            }
        }
        .onAppear { model.reload() }
    }

    private func send() async {
        guard let groupID else { return }
        sending = true; defer { sending = false }
        do {
            let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = try await app.backend.requestExtra(groupID: groupID, minutes: minutes, message: text.isEmpty ? nil : text)
            await app.backend.notify(requestID: id)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
