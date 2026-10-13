public enum PreviewTone: Equatable, Sendable {
    case appliesNow, needsApproval
}

public struct ChangePreviewNote: Equatable, Sendable {
    public let tone: PreviewTone
    public let text: String

    public init(tone: PreviewTone, text: String) {
        self.tone = tone
        self.text = text
    }
}

/// What saving an edited limit will do, shown live under the editor so nobody
/// taps "Guardar" without knowing it sends a request.
public enum ChangePreview {
    /// `old` is nil for a new limit; `partnerName` is nil when there is nobody to
    /// approve, in which case every change applies at once.
    public static func note(old: LimitConfig?, new: LimitConfig, partnerName: String?) -> ChangePreviewNote? {
        guard let old else { return ChangePreviewNote(tone: .appliesNow, text: "Se aplica al instante.") }
        switch LimitChange.classify(from: old, to: new) {
        case .unchanged:
            return nil
        case .tightening:
            return ChangePreviewNote(tone: .appliesNow, text: "Menos tiempo: se aplica al instante.")
        case .loosening:
            guard let partnerName else { return ChangePreviewNote(tone: .appliesNow, text: "Se aplica al instante.") }
            let what = LimitChange.removesApps(from: old, to: new) ? "Sacar apps" : "Más tiempo"
            let current = Formatting.limitSummary(dailyMinutes: old.dailyMinutes, window: old.window)
            return ChangePreviewNote(tone: .needsApproval,
                                     text: "\(what): \(partnerName) tiene que aprobarlo. Hasta entonces seguís con \(current).")
        }
    }

    public static func buttonTitle(for note: ChangePreviewNote?, partnerName: String?) -> String {
        note?.tone == .needsApproval ? "Pedirle a \(partnerName ?? "tu dupla")" : "Guardar"
    }
}
