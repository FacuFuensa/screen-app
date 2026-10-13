import XCTest
@testable import ScreenCore

final class WordingTests: XCTestCase {
    func testMinutes() {
        XCTAssertEqual(Formatting.minutes(45), "45 min")
        XCTAssertEqual(Formatting.minutes(60), "1 h")
        XCTAssertEqual(Formatting.minutes(90), "1 h 30 min")
    }
    func testClockAndWindow() {
        XCTAssertEqual(Formatting.clock(7 * 60 + 5), "07:05")
        XCTAssertEqual(Formatting.window(BlockWindow(startMinute: 1380, endMinute: 420)), "23:00–07:00")
    }
    func testFeedWording() {
        XCTAssertEqual(FeedWording.describe(kind: "limit_reached", actor: "Beto", group: "Redes", minutes: nil),
                       "Beto llegó al límite en Redes")
        XCTAssertEqual(FeedWording.describe(kind: "request_granted", actor: "Ana", group: "Redes", minutes: 15),
                       "Ana dio 15 min en Redes")
        XCTAssertEqual(FeedWording.describe(kind: "auth_revoked", actor: "Beto", group: nil, minutes: nil),
                       "Beto desactivó los permisos de Screen")
        XCTAssertEqual(FeedWording.describe(kind: "wildcard_used", actor: "Beto", group: nil, minutes: nil),
                       "Beto usó su comodín")
    }
}
