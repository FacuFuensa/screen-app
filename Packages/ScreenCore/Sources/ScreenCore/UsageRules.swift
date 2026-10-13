public enum UsageRules {
    public static let wildcardMinutes = 5
    public static let maxGroups = 5
    public static let extraTimeOptions = [5, 15, 30]

    /// Minute count for the "80 %" heads-up event, or nil when it would
    /// coincide with the limit itself.
    public static func warnThreshold(daily: Int) -> Int? {
        let w = daily * 8 / 10
        return (w >= 1 && w < daily) ? w : nil
    }

    /// The monitoring interval for granted extra time: from now to 23:59,
    /// pulled back so it never drops below DeviceActivity's 15-minute minimum.
    /// Usage only counts after monitoring starts, so starting a bit earlier is harmless.
    public static func extraTimeInterval(nowMinute: Int) -> DaySegment {
        DaySegment(startMinute: min(nowMinute, 1439 - BlockWindow.minimumSegment), endMinute: 1439, continuesNextDay: false)
    }
}

public struct GroupRuntime: Codable, Equatable, Sendable {
    public var limitReached: Bool
    public var inWindow: Bool
    public var creditActive: Bool

    public init(limitReached: Bool = false, inWindow: Bool = false, creditActive: Bool = false) {
        self.limitReached = limitReached
        self.inWindow = inWindow
        self.creditActive = creditActive
    }

    /// Granted time unlocks the group whatever the reason it was blocked.
    public var shouldShield: Bool { (limitReached || inWindow) && !creditActive }
}
