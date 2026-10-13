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
    private let isNew: Bool
    private let quarterHours = Array(stride(from: 0, to: 1440, by: 15))

    init(group: LimitGroup?) {
        let g = group ?? LimitGroup(id: UUID(), name: "", selection: FamilyActivitySelection(), dailyMinutes: 30, window: nil)
        _draft = State(initialValue: g)
        _hasDaily = State(initialValue: g.dailyMinutes != nil)
        _hasWindow = State(initialValue: g.window != nil)
        isNew = group == nil
    }

    var body: some View {
        Form {
            Section("Nombre") { TextField("Redes", text: $draft.name) }
            Section("Apps") {
                Button { pickerShown = true } label: { LabeledContent("Elegir apps", value: "\(draft.appCount)") }
                if model.overlaps(draft) {
                    Text("Alguna de estas apps ya está en otro grupo.").font(.footnote).foregroundStyle(.red)
                }
            }
            Section("Minutos por día") {
                Toggle("Límite diario", isOn: $hasDaily)
                if hasDaily {
                    Stepper(Formatting.minutes(draft.dailyMinutes ?? 30),
                            value: Binding(get: { draft.dailyMinutes ?? 30 }, set: { draft.dailyMinutes = $0 }),
                            in: 5...600, step: 5)
                }
            }
            Section("Horario de bloqueo") {
                Toggle("Bloquear en un horario", isOn: $hasWindow)
                if hasWindow, let w = draft.window {
                    Picker("Desde", selection: Binding(get: { w.startMinute }, set: { draft.window?.startMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    Picker("Hasta", selection: Binding(get: { w.endMinute }, set: { draft.window?.endMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    if !w.isValid {
                        Text("Cada parte del horario tiene que durar al menos 15 minutos; si cruza la medianoche, empezá 23:30 o antes.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }
            }
            if app.isPaired && !isNew {
                Section {
                    Text("Endurecer se aplica al instante. Aflojar (más minutos, menos apps, menos horario) se lo pedimos a \(app.partner?.displayName ?? "tu pareja").")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if !isNew {
                Section { Button("Borrar grupo", role: .destructive) { Task { await remove() } } }
            }
        }
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
    }

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
            case .applied: dismiss()
            case .sentForApproval:
                notice = "Le mandamos el cambio a \(app.partner?.displayName ?? "tu pareja"). Mientras tanto sigue el límite anterior."
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    private func remove() async {
        do {
            switch try await model.delete(draft, paired: app.isPaired) {
            case .applied: dismiss()
            case .sentForApproval: notice = "Borrar el grupo necesita la aprobación de \(app.partner?.displayName ?? "tu pareja")."
            }
        } catch {
            notice = error.localizedDescription
        }
    }
}
