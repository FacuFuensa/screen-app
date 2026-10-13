import Foundation

@MainActor
final class Router: ObservableObject {
    static let shared = Router()

    enum Tab: Hashable { case groups, requests, feed }
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

    @Published var tab: Tab = .groups
    @Published var sheet: Sheet?
}
