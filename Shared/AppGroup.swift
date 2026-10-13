import Foundation

enum AppGroup {
    static let id = "group.com.facufuensa.screen"
    static var defaults: UserDefaults { UserDefaults(suiteName: id)! }
}

enum SharedKey {
    static let groups = "groups"
    static let ledger = "ledger"
    static let outbox = "outbox"
    static let pendingAsk = "pendingAsk"
    static let pendingEdits = "pendingEdits"
}
