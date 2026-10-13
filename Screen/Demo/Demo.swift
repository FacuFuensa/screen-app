import FamilyControls
import Foundation
import ScreenCore

/// Launch arguments `-ScreenDemo -ScreenShot <name>` render a screen with sample
/// data and no backend, so CI can screenshot the UI in the simulator.
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-ScreenDemo") }
    static var shot: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-ScreenShot"), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    static let meID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let partnerID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    static let pairID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    static let redesID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
    static let juegosID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
    static let anaRedesID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
    static let seriesID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!

    static let me = ProfileRow(id: meID, displayName: "Facu", lastSeenAt: .now, authStatus: "approved")
    static let partner = ProfileRow(id: partnerID, displayName: "Ana", lastSeenAt: .now, authStatus: "approved")
    static let pair = PairRow(id: pairID, userA: meID, userB: partnerID, inviteCode: "482913")

    static var phase: AppState.Phase {
        switch shot {
        case "auth": return .signedOut
        case "gate": return .needsScreenTime
        case "pairing": return .unpaired
        default: return .ready
        }
    }

    static let myGroups = [
        LimitGroup(id: redesID, name: "Redes", selection: FamilyActivitySelection(), dailyMinutes: 45, window: nil),
        LimitGroup(id: juegosID, name: "Juegos", selection: FamilyActivitySelection(), dailyMinutes: nil,
                   window: BlockWindow(startMinute: 23 * 60, endMinute: 7 * 60)),
    ]

    static let partnerGroups = [
        GroupRow(id: anaRedesID, owner: partnerID, name: "Redes", appCount: 3, dailyMinutes: 30, windowStart: nil, windowEnd: nil),
        GroupRow(id: seriesID, owner: partnerID, name: "Series", appCount: 2, dailyMinutes: 60, windowStart: nil, windowEnd: nil),
    ]

    static var requests: [RequestRow] {
        let now = Date.now
        return [
            RequestRow(id: UUID(uuidString: "88888888-8888-4888-8888-888888888881")!, fromUser: partnerID,
                       kind: .extraTime, groupID: anaRedesID, minutes: 15, payload: nil,
                       message: "es para un video del laburo", status: .pending, grantedMinutes: nil,
                       appliedAt: nil, createdAt: now.addingTimeInterval(-8 * 60),
                       expiresAt: now.addingTimeInterval(22 * 60), answeredAt: nil),
            RequestRow(id: UUID(uuidString: "88888888-8888-4888-8888-888888888882")!, fromUser: partnerID,
                       kind: .loosenLimit, groupID: anaRedesID, minutes: nil,
                       payload: PayloadRow(name: "Redes", appCount: 3, dailyMinutes: 60, windowStart: nil, windowEnd: nil, delete: false),
                       message: nil, status: .pending, grantedMinutes: nil, appliedAt: nil,
                       createdAt: now.addingTimeInterval(-14 * 60), expiresAt: now.addingTimeInterval(16 * 60), answeredAt: nil),
            RequestRow(id: UUID(uuidString: "88888888-8888-4888-8888-888888888883")!, fromUser: meID,
                       kind: .extraTime, groupID: redesID, minutes: 30, payload: nil, message: "termino de hablar con un amigo",
                       status: .granted, grantedMinutes: 30, appliedAt: now.addingTimeInterval(-2 * 3600),
                       createdAt: now.addingTimeInterval(-3 * 3600), expiresAt: now.addingTimeInterval(-2.5 * 3600),
                       answeredAt: now.addingTimeInterval(-2.8 * 3600)),
            RequestRow(id: UUID(uuidString: "88888888-8888-4888-8888-888888888884")!, fromUser: partnerID,
                       kind: .extraTime, groupID: seriesID, minutes: 15, payload: nil, message: nil,
                       status: .denied, grantedMinutes: nil, appliedAt: nil,
                       createdAt: now.addingTimeInterval(-7 * 3600), expiresAt: now.addingTimeInterval(-6.5 * 3600),
                       answeredAt: now.addingTimeInterval(-6.8 * 3600)),
        ]
    }

    static var events: [EventRow] {
        let now = Date.now
        let values: [(String, UUID, UUID?, Int?, TimeInterval)] = [
            ("limit_reached", partnerID, anaRedesID, nil, -20 * 60),
            ("request_granted", meID, redesID, 30, -2 * 3600),
            ("wildcard_used", partnerID, seriesID, nil, -4 * 3600),
            ("threshold_80", meID, redesID, nil, -7 * 3600),
            ("limit_tightened", partnerID, anaRedesID, nil, -11 * 3600),
            ("group_created", meID, juegosID, nil, -20 * 3600),
        ]
        return values.enumerated().map { index, value in
            EventRow(id: UUID(uuidString: String(format: "99999999-9999-4999-8999-%012d", index + 1))!,
                     actor: value.1, kind: value.0, groupID: value.2,
                     data: EventRow.Details(minutes: value.3), createdAt: now.addingTimeInterval(value.4))
        }
    }
}
