import Foundation

public enum RequestStatus: String, Codable, Sendable {
    case pending, granted, denied, superseded, expired
}

public enum RequestRules {
    public static let ttl: TimeInterval = 30 * 60

    /// The server stores `pending` forever; expiry is derived from `expiresAt`.
    public static func effectiveStatus(_ raw: RequestStatus, expiresAt: Date, now: Date) -> RequestStatus {
        raw == .pending && now >= expiresAt ? .expired : raw
    }
}
