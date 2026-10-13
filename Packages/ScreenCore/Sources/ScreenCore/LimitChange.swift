/// The part of a group that decides how strict it is. `appKeys` are stable
/// string forms of the opaque Screen Time tokens (see `FamilyActivitySelection.appKeys`).
public struct LimitConfig: Codable, Equatable, Sendable {
    public var dailyMinutes: Int?
    public var window: BlockWindow?
    public var appKeys: Set<String>

    public init(dailyMinutes: Int?, window: BlockWindow?, appKeys: Set<String>) {
        self.dailyMinutes = dailyMinutes
        self.window = window
        self.appKeys = appKeys
    }
}

public enum ChangeVerdict: Equatable, Sendable {
    case unchanged, tightening, loosening
}

/// Tightening applies at once; anything that frees time in any way needs the
/// partner's approval. A change that tightens one thing and loosens another
/// is a loosening.
public enum LimitChange {
    public static func classify(from old: LimitConfig, to new: LimitConfig) -> ChangeVerdict {
        if old == new { return .unchanged }
        return isLoosening(from: old, to: new) ? .loosening : .tightening
    }

    public static func removesApps(from old: LimitConfig, to new: LimitConfig) -> Bool {
        !old.appKeys.isSubset(of: new.appKeys)
    }

    static func isLoosening(from old: LimitConfig, to new: LimitConfig) -> Bool {
        if removesApps(from: old, to: new) { return true }
        if let o = old.dailyMinutes {
            guard let n = new.dailyMinutes, n <= o else { return true }
        }
        if let o = old.window {
            guard let n = new.window, n.covers(o) else { return true }
        }
        return false
    }
}
