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
    /// `isMe` switches to second person for the viewer's own events ("Pediste", not "Vos pidió").
    public static func describe(kind: String, actor: String, group: String?, minutes: Int?, isMe: Bool = false) -> String {
        let inGroup = group.map { " en \($0)" } ?? ""
        if isMe { return describeOwn(kind: kind, inGroup: inGroup, group: group, minutes: minutes) }
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

    /// Title of a request row; `extraMinutes` nil means a request to loosen a limit.
    public static func requestTitle(extraMinutes: Int?, group: String, actor: String, isMe: Bool) -> String {
        switch (extraMinutes, isMe) {
        case let (m?, true): return "Pediste \(m) min en \(group)"
        case let (m?, false): return "\(actor) pidió \(m) min en \(group)"
        case (nil, true): return "Pediste aflojar \(group)"
        case (nil, false): return "\(actor) quiere aflojar \(group)"
        }
    }

    private static func describeOwn(kind: String, inGroup: String, group: String?, minutes: Int?) -> String {
        switch kind {
        case "threshold_80": return "Usaste el 80 % de tu tiempo\(inGroup)"
        case "limit_reached": return "Llegaste al límite\(inGroup)"
        case "wildcard_used": return "Usaste tu comodín\(inGroup)"
        case "auth_revoked": return "Desactivaste los permisos de Screen"
        case "silent_24h": return "Tu celular no reporta hace un día"
        case "limit_tightened": return "Endureciste un límite\(inGroup)"
        case "group_created": return "Creaste un grupo nuevo\(group.map { ": \($0)" } ?? "")"
        case "request_granted":
            return minutes.map { "Diste \($0) min\(inGroup)" } ?? "Aprobaste un cambio\(inGroup)"
        case "request_denied": return "Rechazaste un pedido\(inGroup)"
        default: return kind
        }
    }
}
