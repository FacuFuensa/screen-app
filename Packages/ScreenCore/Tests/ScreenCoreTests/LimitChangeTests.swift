import XCTest
@testable import ScreenCore

final class LimitChangeTests: XCTestCase {
    private let night = BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)
    private func cfg(_ m: Int?, _ w: BlockWindow? = nil, _ apps: Set<String> = ["a:tiktok", "a:ig"]) -> LimitConfig {
        LimitConfig(dailyMinutes: m, window: w, appKeys: apps)
    }

    func testIdenticalIsUnchanged() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30, night), to: cfg(30, night)), .unchanged)
    }
    func testFewerMinutesIsTightening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(20)), .tightening)
    }
    func testMoreMinutesIsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(45)), .loosening)
    }
    func testRemovingDailyLimitIsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(nil, night)), .loosening)
    }
    func testAddingDailyLimitIsTightening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(nil, night), to: cfg(30, night)), .tightening)
    }
    func testAddingAnAppIsTightening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(30, nil, ["a:tiktok", "a:ig", "a:x"])), .tightening)
    }
    func testSwappingAnAppIsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(30, nil, ["a:tiktok", "a:notes"])), .loosening)
        XCTAssertTrue(LimitChange.removesApps(from: cfg(30), to: cfg(30, nil, ["a:tiktok", "a:notes"])))
    }
    func testWideningWindowIsTightening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(nil, night), to: cfg(nil, BlockWindow(startMinute: 22 * 60, endMinute: 8 * 60))), .tightening)
    }
    func testShrinkingWindowIsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(nil, night), to: cfg(nil, BlockWindow(startMinute: 23 * 60, endMinute: 6 * 60))), .loosening)
    }
    func testRemovingWindowIsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30, night), to: cfg(30)), .loosening)
    }
    func testAddingWindowIsTightening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(30, night)), .tightening)
    }
    func testMixedChangeCountsAsLoosening() {
        XCTAssertEqual(LimitChange.classify(from: cfg(30), to: cfg(10, nil, ["a:tiktok"])), .loosening)
    }
}
