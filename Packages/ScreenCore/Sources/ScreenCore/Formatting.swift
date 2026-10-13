import Foundation

public enum Formatting {
    public static func minutes(_ m: Int) -> String {
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r) min" }
        return r == 0 ? "\(h) h" : "\(h) h \(r) min"
    }

    public static func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    public static func window(_ w: BlockWindow) -> String {
        "\(clock(w.startMinute))–\(clock(w.endMinute))"
    }
}

public enum FeedWording {
    public static func describe(kind: String, actor: String, group: String?, minutes: Int?) -> String {
        let inGroup = group.map { " en \($0)" } ?? ""
        switch kind {
        case "threshold_80": return "\(actor) usó el 80 % de su tiempo\(inGroup)"
        case "limit_reached": return "\(actor) llegó al límite\(inGroup)"
        case "wildcard_used": return "\(actor) usó su comodín\(inGroup)"
        case "auth_revoked": return "\(actor) desactivó los permisos de Screen"
        case "silent_24h": return "\(actor) no reporta hace un día"
        case "limit_tightened": return "\(actor) endureció un límite\(inGroup)"
        case "group_created": return "\(actor) creó un grupo nuevo\(group.map { ": \($0)" } ?? "")"
        case "request_granted":
            return minutes.map { "\(actor) dio \($0) min\(inGroup)" } ?? "\(actor) aprobó un cambio\(inGroup)"
        case "request_denied": return "\(actor) rechazó un pedido\(inGroup)"
        default: return "\(actor): \(kind)"
        }
    }
}
