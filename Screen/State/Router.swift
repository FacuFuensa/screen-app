import Foundation

/// Opens the editor with a prepared draft; only used by demo screenshots.
struct DemoEditorRequest: Identifiable {
    let original: LimitGroup?
    let draft: LimitGroup
    var id: UUID { draft.id }
}

@MainActor
final class Router: ObservableObject {
    static let shared = Router()

    enum Tab: Hashable { case me, partner }
    enum Sheet: Identifiable {
        case ask(UUID?)
        case answer(UUID)
        var id: String {
            switch self {
            case .ask(let g): return "ask-\(g?.uuidString ?? "")"
            case .answer(let r): return "answer-\(r.uuidString)"
            }
        }
    }

    @Published var tab: Tab = .me
    @Published var sheet: Sheet?
    @Published var demoEditor: DemoEditorRequest?
}
