/// Per-device state for the current day, shared by the app and its extensions.
public struct DayLedger: Codable, Equatable, Sendable {
    public static let appliedCap = 200

    public private(set) var day: String
    public private(set) var wildcardUsed: Bool
    /// Granted request IDs already turned into credit; survives day changes so a
    /// late sync never applies the same grant twice.
    public private(set) var appliedRequestIDs: [String]
    public var runtime: [String: GroupRuntime]

    public init(day: String) {
        self.day = day
        self.wildcardUsed = false
        self.appliedRequestIDs = []
        self.runtime = [:]
    }

    /// Midnight: daily limits and credits reset; schedule state is left to the
    /// window activities, which know whether a window spans midnight.
    public mutating func roll(to newDay: String) {
        guard newDay != day else { return }
        day = newDay
        wildcardUsed = false
        for key in runtime.keys {
            runtime[key]?.limitReached = false
            runtime[key]?.creditActive = false
        }
    }

    public var canUseWildcard: Bool { !wildcardUsed }

    @discardableResult
    public mutating func consumeWildcard() -> Bool {
        guard !wildcardUsed else { return false }
        wildcardUsed = true
        return true
    }

    public func hasApplied(_ id: String) -> Bool { appliedRequestIDs.contains(id) }

    public mutating func markApplied(_ id: String) {
        guard !hasApplied(id) else { return }
        appliedRequestIDs.append(id)
        if appliedRequestIDs.count > Self.appliedCap {
            appliedRequestIDs.removeFirst(appliedRequestIDs.count - Self.appliedCap)
        }
    }
}
