import XCTest
@testable import ScreenCore

final class DayRulesTests: XCTestCase {
    func testWarnThresholdIsEightyPercent() {
        XCTAssertEqual(UsageRules.warnThreshold(daily: 60), 48)
        XCTAssertEqual(UsageRules.warnThreshold(daily: 5), 4)
        XCTAssertNil(UsageRules.warnThreshold(daily: 1))
    }

    func testExtraIntervalRunsUntilEndOfDay() {
        XCTAssertEqual(UsageRules.extraTimeInterval(nowMinute: 600),
                       DaySegment(startMinute: 600, endMinute: 1439, continuesNextDay: false))
    }

    func testExtraIntervalNearMidnightStillLasts15Minutes() {
        let seg = UsageRules.extraTimeInterval(nowMinute: 1430)
        XCTAssertEqual(seg, DaySegment(startMinute: 1424, endMinute: 1439, continuesNextDay: false))
        XCTAssertGreaterThanOrEqual(seg.length, BlockWindow.minimumSegment)
    }

    func testShieldPolicy() {
        XCTAssertFalse(GroupRuntime().shouldShield)
        XCTAssertTrue(GroupRuntime(limitReached: true).shouldShield)
        XCTAssertTrue(GroupRuntime(inWindow: true).shouldShield)
        XCTAssertFalse(GroupRuntime(limitReached: true, inWindow: true, creditActive: true).shouldShield)
    }

    func testRollResetsDailyStateButKeepsWindow() {
        var l = DayLedger(day: "2026-10-12")
        l.runtime["g"] = GroupRuntime(limitReached: true, inWindow: true, creditActive: true)
        XCTAssertTrue(l.consumeWildcard())
        l.roll(to: "2026-10-13")
        XCTAssertEqual(l.day, "2026-10-13")
        XCTAssertEqual(l.runtime["g"], GroupRuntime(limitReached: false, inWindow: true, creditActive: false))
        XCTAssertTrue(l.canUseWildcard)
    }

    func testRollOnSameDayIsNoOp() {
        var l = DayLedger(day: "2026-10-12")
        l.runtime["g"] = GroupRuntime(limitReached: true)
        l.roll(to: "2026-10-12")
        XCTAssertEqual(l.runtime["g"]?.limitReached, true)
    }

    func testWildcardOncePerDay() {
        var l = DayLedger(day: "2026-10-12")
        XCTAssertTrue(l.consumeWildcard())
        XCTAssertFalse(l.consumeWildcard())
        XCTAssertFalse(l.canUseWildcard)
    }

    func testMarkAppliedIsIdempotent() {
        var l = DayLedger(day: "2026-10-12")
        l.markApplied("r1")
        l.markApplied("r1")
        XCTAssertTrue(l.hasApplied("r1"))
        XCTAssertEqual(l.appliedRequestIDs, ["r1"])
    }

    func testAppliedListIsCapped() {
        var l = DayLedger(day: "2026-10-12")
        for i in 0..<205 { l.markApplied("r\(i)") }
        XCTAssertEqual(l.appliedRequestIDs.count, DayLedger.appliedCap)
        XCTAssertFalse(l.hasApplied("r0"))
        XCTAssertTrue(l.hasApplied("r204"))
    }

    func testDayKeyUsesTheGivenCalendar() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let d = ISO8601DateFormatter().date(from: "2026-10-12T02:30:00Z")!  // 23:30 on the 11th in BA
        XCTAssertEqual(DayKey.string(for: d, calendar: cal), "2026-10-11")
        XCTAssertEqual(DayKey.minuteOfDay(d, calendar: cal), 1410)
    }

    func testPendingRequestExpires() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(RequestRules.effectiveStatus(.pending, expiresAt: now.addingTimeInterval(60), now: now), .pending)
        XCTAssertEqual(RequestRules.effectiveStatus(.pending, expiresAt: now, now: now), .expired)
        XCTAssertEqual(RequestRules.effectiveStatus(.granted, expiresAt: now.addingTimeInterval(-60), now: now), .granted)
    }
}
