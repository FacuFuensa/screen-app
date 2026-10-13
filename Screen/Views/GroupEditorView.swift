import FamilyControls
import ScreenCore
import SwiftUI

/// Creates or edits one of my limits. Before saving it says, in plain words, whether
/// the change applies now or goes to the partner, and it can only send once.
struct GroupEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @EnvironmentObject var model: GroupsModel
    @State private var draft: LimitGroup
    @State private var hasDaily: Bool
    @State private var hasWindow: Bool
    @State private var pickerShown = false
    @State private var saving = false
    @State private var cancelling = false
    @State private var confirmDelete = false
    @State private var notice: String?
    @State private var hapticTrigger = 0
    @FocusState private var nameFocused: Bool
    private let original: LimitGroup?
    private let quarterHours = Array(stride(from: 0, to: 1440, by: 15))

    init(group: LimitGroup?, startingDraft: LimitGroup? = nil) {
        original = group
        let initial = startingDraft ?? group
            ?? LimitGroup(id: UUID(), name: "", selection: FamilyActivitySelection(), dailyMinutes: 30, window: nil)
        _draft = State(initialValue: initial)
        _hasDaily = State(initialValue: initial.dailyMinutes != nil)
        _hasWindow = State(initialValue: initial.window != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let pending { pendingCard(pending) }
                VStack(alignment: .leading, spacing: 16) {
                    nameCard
                    appsCard
                    dailyCard
                    windowCard
                    if original != nil {
                        Button("Borrar límite", role: .destructive) { confirmDelete = true }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                }
                .disabled(pending != nil)
                .opacity(pending != nil ? 0.5 : 1)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) { if pending == nil { bottomBar } }
        .navigationTitle(original == nil ? "Nuevo límite" : (original?.name ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        .familyActivityPicker(isPresented: $pickerShown, selection: $draft.selection)
        .onChange(of: hasDaily) { _, on in draft.dailyMinutes = on ? (draft.dailyMinutes ?? 30) : nil }
        .onChange(of: hasWindow) { _, on in
            draft.window = on ? (draft.window ?? BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)) : nil
        }
        .confirmationDialog(deleteQuestion, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(app.isPaired ? "Pedirle a \(partnerLabel)" : "Borrar", role: .destructive) { Task { await remove() } }
        }
        .alert("Screen", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") {}
        } message: { Text(notice ?? "") }
        .sensoryFeedback(.success, trigger: hapticTrigger)
        .onChange(of: nameFocused) { _, focused in
            if !focused, !trimmedName.isEmpty { TourController.shared.complete(.name) }
        }
        .onChange(of: draft.appCount) { _, count in if count > 0 { TourController.shared.complete(.apps) } }
        .onChange(of: draft.dailyMinutes) { _, _ in TourController.shared.complete(.minutes) }
        .onChange(of: hasWindow) { _, _ in TourController.shared.complete(.minutes) }
        .tourHost()
    }

    // MARK: Derived state

    private var pending: PendingLoosen? { original.flatMap { model.pendingByGroup[$0.id] } }
    private var partnerName: String? { app.isPaired ? (app.partner?.displayName ?? "tu dupla") : nil }
    private var partnerLabel: String { partnerName ?? "tu dupla" }
    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespaces) }
    private var preview: ChangePreviewNote? {
        ChangePreview.note(old: original?.config, new: draft.config, partnerName: partnerName)
    }
    private var renamed: Bool { original.map { $0.name != trimmedName } ?? false }
    private var valid: Bool {
        !trimmedName.isEmpty
            && (draft.appCount > 0 || Demo.isOn)
            && (draft.dailyMinutes != nil || draft.window != nil)
            && (draft.window?.isValid ?? true)
            && !model.overlaps(draft)
    }
    private var canSave: Bool { valid && (preview != nil || renamed) && !saving }
    private var deleteQuestion: String {
        app.isPaired ? "Borrar un límite lo tiene que aprobar \(partnerLabel)." : "¿Borrar este límite?"
    }

    // MARK: Cards

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Nombre", systemImage: "textformat").font(.headline)
                TextField("Por ejemplo, Redes", text: $draft.name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { if !trimmedName.isEmpty { TourController.shared.complete(.name) } }
                Text("Un nombre corto que los dos reconozcan.").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
        .tourAnchor(.name)
    }

    private var appsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Button { pickerShown = true } label: {
                    HStack {
                        Label("Elegir apps", systemImage: "square.grid.2x2").font(.headline)
                        Spacer()
                        Text(draft.appCount == 0 ? "Ninguna" : (draft.appCount == 1 ? "1 app" : "\(draft.appCount) apps"))
                            .foregroundStyle(Theme.secondaryText)
                        Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                if model.overlaps(draft) {
                    Text("Alguna de estas apps ya está en otro límite.").font(.footnote).foregroundStyle(.red)
                } else {
                    Text("La lista de apps queda solo en este celular.").font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .tourAnchor(.apps)
    }

    private var dailyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasDaily) { Label("Minutos por día", systemImage: "hourglass").font(.headline) }
                if hasDaily {
                    Stepper(value: Binding(get: { draft.dailyMinutes ?? 30 }, set: { draft.dailyMinutes = $0 }),
                            in: 5...600, step: 5) {
                        Text(Formatting.minutes(draft.dailyMinutes ?? 30))
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(Theme.coral)
                    }
                }
                Text("Se reinicia todos los días a la medianoche.").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
        .tourAnchor(.minutes)
    }

    private var windowCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $hasWindow) { Label("Bloquear en un horario", systemImage: "moon.fill").font(.headline) }
                if hasWindow, let window = draft.window {
                    Picker("Desde", selection: Binding(get: { window.startMinute }, set: { draft.window?.startMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    Picker("Hasta", selection: Binding(get: { window.endMinute }, set: { draft.window?.endMinute = $0 })) {
                        ForEach(quarterHours, id: \.self) { Text(Formatting.clock($0)).tag($0) }
                    }
                    if !window.isValid {
                        Text("Cada parte del horario tiene que durar al menos 15 minutos; si cruza la medianoche, empezá 23:30 o antes.")
                            .font(.footnote).foregroundStyle(.red)
                    }
                }
                Text("En esa franja las apps quedan bloqueadas aunque te queden minutos.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func pendingCard(_ pending: PendingLoosen) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                StatusPill(text: "Esperando a \(partnerLabel)", color: Theme.amber, symbol: "clock.fill")
                if let original {
                    Text("Ya le pediste a \(partnerLabel): \(LimitText.change(from: original, to: pending.edit)).")
                        .font(.subheadline)
                    Text("Mientras tanto sigue \(Formatting.limitSummary(dailyMinutes: original.dailyMinutes, window: original.window)).")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Button(cancelling ? "Cancelando…" : "Cancelar pedido") { Task { await cancelPending() } }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(cancelling)
            }
        }
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.amber, lineWidth: 2) }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let preview {
                Label(preview.text, systemImage: preview.tone == .needsApproval ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(preview.tone == .needsApproval ? Color.orange : Color.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button { Task { await save() } } label: {
                if saving { ProgressView().tint(.white) } else { Text(ChangePreview.buttonTitle(for: preview, partnerName: partnerName)) }
            }
            .buttonStyle(PrimaryButtonStyle(color: preview?.tone == .needsApproval ? Theme.amber : Theme.coral))
            .disabled(!canSave)
            .tourAnchor(.save)
        }
        .padding(16)
        .background(.bar)
    }

    // MARK: Actions

    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        draft.name = trimmedName
        do {
            _ = try await model.save(draft, paired: app.isPaired)
            hapticTrigger += 1
            TourController.shared.complete(.save)
            dismiss()  // the card in "Yo" now shows the result, including "Esperando a …"
        } catch {
            notice = error.localizedDescription
        }
    }

    private func cancelPending() async {
        guard let original, !cancelling else { return }
        cancelling = true
        defer { cancelling = false }
        do { try await model.cancelPending(groupID: original.id) } catch { notice = error.localizedDescription }
    }

    private func remove() async {
        do {
            _ = try await model.delete(draft, paired: app.isPaired)
            dismiss()
        } catch {
            notice = error.localizedDescription
        }
    }
}
