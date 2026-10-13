import FamilyControls
import Foundation
import ScreenCore

struct LimitGroup: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var dailyMinutes: Int?
    var window: BlockWindow?

    var appCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var config: LimitConfig {
        LimitConfig(dailyMinutes: dailyMinutes, window: window, appKeys: selection.appKeys)
    }
}

extension FamilyActivitySelection {
    /// Stable string identities for the opaque tokens, so ScreenCore can tell
    /// "added an app" from "swapped one app for another".
    var appKeys: Set<String> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        func key<T: Encodable>(_ prefix: String, _ token: T) -> String? {
            (try? encoder.encode(token)).map { prefix + $0.base64EncodedString() }
        }
        return Set(applicationTokens.compactMap { key("a:", $0) }
            + categoryTokens.compactMap { key("c:", $0) }
            + webDomainTokens.compactMap { key("w:", $0) })
    }
}
