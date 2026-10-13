import XCTest
@testable import ScreenCore

final class ChangePreviewTests: XCTestCase {
    private let night = BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)
    private func cfg(_ m: Int?, _ w: BlockWindow? = nil, _ apps: Set<String> = ["a:1", "a:2"]) -> LimitConfig {
        LimitConfig(dailyMinutes: m, window: w, appKeys: apps)
    }

    func testNewLimitAppliesNow() {
        XCTAssertEqual(ChangePreview.note(old: nil, new: cfg(30), partnerName: "Ana"),
                       ChangePreviewNote(tone: .appliesNow, text: "Se aplica al instante."))
    }

    func testUnchangedHasNoNote() {
        XCTAssertNil(ChangePreview.note(old: cfg(30), new: cfg(30), partnerName: "Ana"))
    }

    func testTighteningAppliesNow() {
        XCTAssertEqual(ChangePreview.note(old: cfg(45), new: cfg(30), partnerName: "Ana"),
                       ChangePreviewNote(tone: .appliesNow, text: "Menos tiempo: se aplica al instante."))
    }

    func testMoreTimeNeedsApprovalAndNamesCurrentLimit() {
        XCTAssertEqual(ChangePreview.note(old: cfg(45), new: cfg(75), partnerName: "Ana"),
                       ChangePreviewNote(tone: .needsApproval,
                                         text: "Más tiempo: Ana tiene que aprobarlo. Hasta entonces seguís con 45 min por día."))
    }

    func testRemovingAppsSaysSo() {
        XCTAssertEqual(ChangePreview.note(old: cfg(45), new: cfg(45, nil, ["a:1"]), partnerName: "Ana"),
                       ChangePreviewNote(tone: .needsApproval,
                                         text: "Sacar apps: Ana tiene que aprobarlo. Hasta entonces seguís con 45 min por día."))
    }

    func testLooseningWithoutPartnerAppliesNow() {
        XCTAssertEqual(ChangePreview.note(old: cfg(45), new: cfg(75), partnerName: nil),
                       ChangePreviewNote(tone: .appliesNow, text: "Se aplica al instante."))
    }

    func testButtonTitles() {
        let ask = ChangePreviewNote(tone: .needsApproval, text: "")
        XCTAssertEqual(ChangePreview.buttonTitle(for: ask, partnerName: "Ana"), "Pedirle a Ana")
        XCTAssertEqual(ChangePreview.buttonTitle(for: ask, partnerName: nil), "Pedirle a tu dupla")
        XCTAssertEqual(ChangePreview.buttonTitle(for: nil, partnerName: "Ana"), "Guardar")
    }

    func testLimitSummary() {
        XCTAssertEqual(Formatting.limitSummary(dailyMinutes: 45, window: nil), "45 min por día")
        XCTAssertEqual(Formatting.limitSummary(dailyMinutes: nil, window: night), "bloqueo 23:00–07:00")
        XCTAssertEqual(Formatting.limitSummary(dailyMinutes: 90, window: night), "1 h 30 min por día y bloqueo 23:00–07:00")
        XCTAssertEqual(Formatting.limitSummary(dailyMinutes: nil, window: nil), "sin límite")
    }

    func testCancelledIsNotExpired() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(RequestRules.effectiveStatus(.cancelled, expiresAt: now.addingTimeInterval(-60), now: now), .cancelled)
    }
}
