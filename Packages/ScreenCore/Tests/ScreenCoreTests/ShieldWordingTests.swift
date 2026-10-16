import ScreenCore
import XCTest

final class ShieldWordingTests: XCTestCase {
    func testLimitReachedNamesAppGroupAndPartner() {
        let t = ShieldWording.make(appName: "Instagram", groupName: "Redes", limitReached: true, dailyMinutes: 45,
                                   windowEnd: nil, partner: "Miri", canUseWildcard: false)
        XCTAssertEqual(t.title, "Se terminó Instagram por hoy")
        XCTAssertEqual(t.subtitle, "Ya usaste tus 45 min de Redes.\nMañana arranca de cero.\nSi de verdad lo necesitás, pedile minutos a Miri.")
        XCTAssertEqual(t.askLabel, "Pedirle permiso a Miri")
    }

    func testWindowSaysUntilWhen() {
        let t = ShieldWording.make(appName: "Instagram", groupName: "Redes", limitReached: false, dailyMinutes: nil,
                                   windowEnd: 7 * 60, partner: nil, canUseWildcard: true)
        XCTAssertEqual(t.title, "Instagram está en pausa")
        XCTAssertTrue(t.subtitle.hasPrefix("Redes está bloqueado hasta las 07:00."))
        XCTAssertTrue(t.subtitle.contains("comodín de 5 min"))
        XCTAssertEqual(t.askLabel, "Pedir permiso")
    }

    func testUnknownGroupFallsBack() {
        let t = ShieldWording.make(appName: nil, groupName: nil, limitReached: false, dailyMinutes: nil,
                                   windowEnd: nil, partner: "", canUseWildcard: false)
        XCTAssertEqual(t.title, "Esta app está bloqueada")
        XCTAssertEqual(t.askLabel, "Pedir permiso")
    }
}
