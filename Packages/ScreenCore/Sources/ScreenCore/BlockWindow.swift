/// A daily time range during which a group is blocked, in minutes of the day.
/// `endMinute` is exclusive; when it is lower than `startMinute` the window
/// wraps past midnight (23:00 → 07:00).
public struct BlockWindow: Codable, Equatable, Hashable, Sendable {
    public static let minutesPerDay = 1440
    /// DeviceActivitySchedule rejects intervals shorter than this.
    public static let minimumSegment = 15

    public var startMinute: Int
    public var endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    public var length: Int {
        startMinute < endMinute ? endMinute - startMinute : Self.minutesPerDay - startMinute + endMinute
    }

    public var isValid: Bool {
        let range = 0..<Self.minutesPerDay
        guard range.contains(startMinute), range.contains(endMinute), startMinute != endMinute else { return false }
        return segments().allSatisfy { $0.length >= Self.minimumSegment }
    }

    public func contains(minute m: Int) -> Bool {
        startMinute < endMinute ? (m >= startMinute && m < endMinute) : (m >= startMinute || m < endMinute)
    }

    /// True when every minute blocked by `other` is also blocked by `self`.
    public func covers(_ other: BlockWindow) -> Bool {
        (0..<Self.minutesPerDay).allSatisfy { !other.contains(minute: $0) || contains(minute: $0) }
    }

    /// Same-day pieces for DeviceActivitySchedule, which cannot cross midnight.
    /// The evening piece of a wrapping window ends at 23:59 and is flagged so the
    /// monitor keeps the shield up until the morning piece starts at 00:00.
    public func segments() -> [DaySegment] {
        if startMinute < endMinute {
            return [DaySegment(startMinute: startMinute, endMinute: endMinute, continuesNextDay: false)]
        }
        if endMinute == 0 {
            return [DaySegment(startMinute: startMinute, endMinute: 1439, continuesNextDay: false)]
        }
        return [
            DaySegment(startMinute: startMinute, endMinute: 1439, continuesNextDay: true),
            DaySegment(startMinute: 0, endMinute: endMinute, continuesNextDay: false),
        ]
    }
}

public struct DaySegment: Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int
    public let continuesNextDay: Bool

    public init(startMinute: Int, endMinute: Int, continuesNextDay: Bool) {
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.continuesNextDay = continuesNextDay
    }

    public var length: Int { endMinute - startMinute }
}
