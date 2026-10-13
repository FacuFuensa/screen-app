import FamilyControls
import ScreenCore
import SwiftUI

struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var draft: LimitGroup
    @State private var hasDaily: Bool
    @State private var hasWindow: Bool
    @State private var pickerShown = false
    @State private var saving = false
    @State private var notice: String?
    @State private var hapticTrigger = 0
    private let isNew: Bool
    private let quarterHours = Array(stride(from: 0, to: 1440, by: 15))

    init(group: LimitGroup?) {
        isNew = group == nil
        let initial = group ?? LimitGroup(id: UUID(), name: "", selection: FamilyActivitySelection(), dailyMinutes: 30, window: nil)
        _draft = State(initialValue: initial)
        _hasDaily = State(initialValue: initial.dailyMinutes != nil)
        _hasWindow = State(initialValue: initial.window != nil)
    }

    var body: some View {
        Form {
            Section {
                TextField("Redes", text: $draft.name)
            } header: { Label("Nombre", systemImage: "textformat") }
              footer: { Text("Poné un nombre corto que los dos reconozcan.") }

            Section {
                Button { pickerShown = true } label: {
                    Label { LabeledContent("Elegir apps", value: "\(draft.appCount)") } icon: { Image(systemName: "square.grid.2x2") }
                }
                if model.overlaps(draft) {
                    Text("Alguna de estas apps ya está en otro grupo.").foregroundStyle(.red)
                }
            } header: { Label("Apps", systemImage: "apps.iphone") }
              footer: { Text("La selección queda guardada solo en este celular.") }

            Section {
                Toggle(isOn: $hasDaily) { Label("Límite diario", systemImage: "hourglass") }
                if hasDaily {
                    Stepper(Formatting.minutes(draft.dailyMinutes ?? 30),
                            value: Binding(get: { draft.dailyMinutes ?? 30 }, set: { draft.dailyMinutes = $0 }),
                            in: 5...600, step: 5)
                }
            } footer: { Text("Se reinicia cada día a la medianoche.") }

            Section {
                Toggle(isOn: $hasWindow) { Label("Bloquear en un horario", systemImage: "moon.fill") }
                if hasWindow, let window = draft.window {
                    Picker("Desde", selection: Binding(get: { window.startMinute }, set: { draft.window?.startMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    Picker("Hasta", selection: Binding(get: { window.endMinute }, set: { draft.window?.endMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    if !window.isValid {
                        Text("Cada parte del horario tiene que durar al menos 15 minutos; si cruza la medianoche, empezá 23:30 o antes.")
                            .foregroundStyle(.red)
                    }
                }
            } footer: { Text("Durante esa franja, las apps quedan bloqueadas aunque queden minutos.") }

            if app.isPaired && !isNew {
                Section {
                    Label("Endurecer se aplica al instante. Si aflojás el límite, se lo pedimos a \(partnerName).",
                          systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(Theme.amber)
                } footer: { Text("Más minutos, menos apps o menos horario necesitan su aprobación.") }
            }
            if !isNew {
                Section { Button("Borrar grupo", role: .destructive) { Task { await remove() } } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .tint(Theme.coral)
        .navigationTitle(isNew ? "Nuevo grupo" : draft.name)
        .familyActivityPicker(isPresented: $pickerShown, selection: $draft.selection)
        .onChange(of: hasDaily) { _, on in draft.dailyMinutes = on ? (draft.dailyMinutes ?? 30) : nil }
        .onChange(of: hasWindow) { _, on in
            draft.window = on ? (draft.window ?? BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)) : nil
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { Task { await save() } }.disabled(!canSave || saving)
            }
        }
        .alert("Screen", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil; dismiss() } })) {
            Button("OK") {}
        } message: { Text(notice ?? "") }
        .sensoryFeedback(.success, trigger: hapticTrigger)
    }

    private var partnerName: String { app.partner?.displayName ?? "tu dupla" }
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.appCount > 0
            && (draft.dailyMinutes != nil || draft.window != nil)
            && (draft.window?.isValid ?? true)
            && !model.overlaps(draft)
    }

    private func save() async {
        saving = true; defer { saving = false }
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        do {
            switch try await model.save(draft, paired: app.isPaired) {
            case .applied: hapticTrigger += 1; dismiss()
            case .sentForApproval:
                hapticTrigger += 1
                notice = "Le mandamos el cambio a \(partnerName). Mientras tanto sigue el límite anterior."
            }
        } catch { notice = error.localizedDescription }
    }

    private func remove() async {
        do {
            switch try await model.delete(draft, paired: app.isPaired) {
            case .applied: dismiss()
            case .sentForApproval: notice = "Borrar el grupo necesita la aprobación de \(partnerName)."
            }
        } catch { notice = error.localizedDescription }
    }
}
