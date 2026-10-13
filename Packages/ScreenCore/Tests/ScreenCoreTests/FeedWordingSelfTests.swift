import XCTest
@testable import ScreenCore

/// Events the viewer caused read in second person ("Pediste"), not "Vos pidió".
final class FeedWordingSelfTests: XCTestCase {
    private func me(_ kind: String, group: String? = "Redes", minutes: Int? = nil) -> String {
        FeedWording.describe(kind: kind, actor: "Vos", group: group, minutes: minutes, isMe: true)
    }

    func testOwnEventsUseVoseo() {
        XCTAssertEqual(me("limit_reached"), "Llegaste al límite en Redes")
        XCTAssertEqual(me("threshold_80"), "Usaste el 80 % de tu tiempo en Redes")
        XCTAssertEqual(me("wildcard_used"), "Usaste tu comodín en Redes")
        XCTAssertEqual(me("auth_revoked", group: nil), "Desactivaste los permisos de Screen")
        XCTAssertEqual(me("silent_24h", group: nil), "Tu celular no reporta hace un día")
        XCTAssertEqual(me("limit_tightened"), "Endureciste un límite en Redes")
        XCTAssertEqual(me("group_created", group: "Juegos"), "Creaste un grupo nuevo: Juegos")
        XCTAssertEqual(me("request_granted", minutes: 30), "Diste 30 min en Redes")
        XCTAssertEqual(me("request_granted"), "Aprobaste un cambio en Redes")
        XCTAssertEqual(me("request_denied"), "Rechazaste un pedido en Redes")
    }

    func testOtherPeopleKeepThirdPerson() {
        XCTAssertEqual(FeedWording.describe(kind: "request_granted", actor: "Ana", group: "Redes", minutes: 15, isMe: false),
                       "Ana dio 15 min en Redes")
    }

    func testExtraTimeRequestTitle() {
        XCTAssertEqual(FeedWording.requestTitle(extraMinutes: 30, group: "Redes", actor: "Vos", isMe: true),
                       "Pediste 30 min en Redes")
        XCTAssertEqual(FeedWording.requestTitle(extraMinutes: 15, group: "Redes", actor: "Ana", isMe: false),
                       "Ana pidió 15 min en Redes")
        XCTAssertEqual(FeedWording.requestTitle(extraMinutes: nil, group: "Redes", actor: "Vos", isMe: true),
                       "Pediste aflojar Redes")
        XCTAssertEqual(FeedWording.requestTitle(extraMinutes: nil, group: "Redes", actor: "Ana", isMe: false),
                       "Ana quiere aflojar Redes")
    }
}
