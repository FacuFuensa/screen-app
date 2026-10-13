import XCTest
@testable import ScreenCore

final class BlockWindowTests: XCTestCase {
    func testSameDayWindowContainsItsMinutes() {
        let w = BlockWindow(startMinute: 9 * 60, endMinute: 18 * 60)
        XCTAssertTrue(w.contains(minute: 9 * 60))
        XCTAssertTrue(w.contains(minute: 18 * 60 - 1))
        XCTAssertFalse(w.contains(minute: 18 * 60))
        XCTAssertFalse(w.contains(minute: 9 * 60 - 1))
    }

    func testOvernightWindowWrapsMidnight() {
        let w = BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)
        XCTAssertTrue(w.contains(minute: 23 * 60))
        XCTAssertTrue(w.contains(minute: 1439))
        XCTAssertTrue(w.contains(minute: 0))
        XCTAssertTrue(w.contains(minute: 7 * 60 - 1))
        XCTAssertFalse(w.contains(minute: 7 * 60))
        XCTAssertFalse(w.contains(minute: 23 * 60 - 1))
    }

    func testCoversRequiresEveryOldMinute() {
        let night = BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)
        XCTAssertTrue(BlockWindow(startMinute: 22 * 60, endMinute: 8 * 60).covers(night))
        XCTAssertFalse(night.covers(BlockWindow(startMinute: 22 * 60, endMinute: 8 * 60)))
        // Same length, shifted: frees 23:00–01:00, so it does not cover.
        XCTAssertFalse(BlockWindow(startMinute: 60, endMinute: 9 * 60).covers(night))
    }

    func testValidity() {
        XCTAssertTrue(BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60).isValid)
        XCTAssertTrue(BlockWindow(startMinute: 1410, endMinute: 420).isValid)
        XCTAssertFalse(BlockWindow(startMinute: 1430, endMinute: 420).isValid, "evening part is 9 min")
        XCTAssertFalse(BlockWindow(startMinute: 1380, endMinute: 10).isValid, "morning part is 10 min")
        XCTAssertFalse(BlockWindow(startMinute: 60, endMinute: 70).isValid)
        XCTAssertFalse(BlockWindow(startMinute: 60, endMinute: 60).isValid)
        XCTAssertFalse(BlockWindow(startMinute: -1, endMinute: 60).isValid)
        XCTAssertFalse(BlockWindow(startMinute: 60, endMinute: 1440).isValid)
    }

    func testSegmentsForSameDayWindow() {
        XCTAssertEqual(BlockWindow(startMinute: 540, endMinute: 1080).segments(),
                       [DaySegment(startMinute: 540, endMinute: 1080, continuesNextDay: false)])
    }

    func testOvernightSegmentsHaveNoMidnightGap() {
        XCTAssertEqual(BlockWindow(startMinute: 1380, endMinute: 420).segments(), [
            DaySegment(startMinute: 1380, endMinute: 1439, continuesNextDay: true),
            DaySegment(startMinute: 0, endMinute: 420, continuesNextDay: false),
        ])
    }

    func testWindowEndingAtMidnightIsOneSegment() {
        XCTAssertEqual(BlockWindow(startMinute: 1320, endMinute: 0).segments(),
                       [DaySegment(startMinute: 1320, endMinute: 1439, continuesNextDay: false)])
    }
}
