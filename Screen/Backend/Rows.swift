import Foundation
import ScreenCore

struct ProfileRow: Decodable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let lastSeenAt: Date?
    let authStatus: String
    enum CodingKeys: String, CodingKey {
        case id, displayName = "display_name", lastSeenAt = "last_seen_at", authStatus = "auth_status"
    }
}

struct PairRow: Decodable {
    let id: UUID
    let userA: UUID
    let userB: UUID?
    let inviteCode: String
    enum CodingKeys: String, CodingKey { case id, userA = "user_a", userB = "user_b", inviteCode = "invite_code" }
}

struct GroupRow: Decodable, Identifiable {
    let id: UUID
    let owner: UUID
    let name: String
    let appCount: Int
    let dailyMinutes: Int?
    let windowStart: Int?
    let windowEnd: Int?
    enum CodingKeys: String, CodingKey {
        case id, owner, name, appCount = "app_count", dailyMinutes = "daily_minutes",
             windowStart = "window_start", windowEnd = "window_end"
    }
    var window: BlockWindow? {
        guard let s = windowStart, let e = windowEnd else { return nil }
        return BlockWindow(startMinute: s, endMinute: e)
    }
}

struct PayloadRow: Decodable {
    let name: String?
    let appCount: Int?
    let dailyMinutes: Int?
    let windowStart: Int?
    let windowEnd: Int?
    let delete: Bool?
    enum CodingKeys: String, CodingKey {
        case name, appCount = "app_count", dailyMinutes = "daily_minutes",
             windowStart = "window_start", windowEnd = "window_end", delete
    }
}

struct RequestRow: Decodable, Identifiable {
    enum Kind: String, Decodable { case extraTime = "extra_time", loosenLimit = "loosen_limit" }
    let id: UUID
    let fromUser: UUID
    let kind: Kind
    let groupID: UUID?
    let minutes: Int?
    let payload: PayloadRow?
    let message: String?
    let status: RequestStatus
    let grantedMinutes: Int?
    let appliedAt: Date?
    let createdAt: Date
    let expiresAt: Date
    let answeredAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, fromUser = "from_user", kind, groupID = "group_id", minutes, payload, message, status,
             grantedMinutes = "granted_minutes", appliedAt = "applied_at", createdAt = "created_at",
             expiresAt = "expires_at", answeredAt = "answered_at"
    }
    func effectiveStatus(now: Date = .now) -> RequestStatus {
        RequestRules.effectiveStatus(status, expiresAt: expiresAt, now: now)
    }
}

struct EventRow: Decodable, Identifiable {
    struct Details: Decodable { let minutes: Int? }
    let id: UUID
    let actor: UUID
    let kind: String
    let groupID: UUID?
    let data: Details
    let createdAt: Date
    enum CodingKeys: String, CodingKey { case id, actor, kind, groupID = "group_id", data, createdAt = "created_at" }
}

/// Full proposed state for a loosen request; nil values are sent as JSON null on purpose.
struct LoosenPayload: Encodable {
    let name: String
    let appCount: Int
    let dailyMinutes: Int?
    let windowStart: Int?
    let windowEnd: Int?
    let delete: Bool

    init(_ g: LimitGroup, delete: Bool = false) {
        name = g.name
        appCount = g.appCount
        dailyMinutes = g.dailyMinutes
        windowStart = g.window?.startMinute
        windowEnd = g.window?.endMinute
        self.delete = delete
    }

    enum CodingKeys: String, CodingKey {
        case name, appCount = "app_count", dailyMinutes = "daily_minutes",
             windowStart = "window_start", windowEnd = "window_end", delete
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if delete { try c.encode(true, forKey: .delete); return }
        try c.encode(name, forKey: .name)
        try c.encode(appCount, forKey: .appCount)
        try c.encode(dailyMinutes, forKey: .dailyMinutes)
        try c.encode(windowStart, forKey: .windowStart)
        try c.encode(windowEnd, forKey: .windowEnd)
    }
}
