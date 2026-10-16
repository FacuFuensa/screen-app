/// Text for the screen iOS shows over a blocked app.
public struct ShieldText: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var askLabel: String
}

public enum ShieldWording {
    /// `appName` is what iOS calls the app ("Instagram"); nil for categories or unknown apps.
    /// `windowEnd` is the minute of the day the block window ends, when that is why it is blocked.
    public static func make(appName: String?, groupName: String?, limitReached: Bool,
                            dailyMinutes: Int?, windowEnd: Int?, partner: String?,
                            canUseWildcard: Bool) -> ShieldText {
        let app = appName.flatMap { $0.isEmpty ? nil : $0 }
        let who = partner.flatMap { $0.isEmpty ? nil : $0 }
        let askLabel = who.map { "Pedirle permiso a \($0)" } ?? "Pedir permiso"

        guard let groupName else {
            return ShieldText(title: "\(app ?? "Esta app") está bloqueada", subtitle: "Screen la tiene en pausa.",
                              askLabel: askLabel)
        }

        let title: String
        var lines: [String] = []
        if limitReached {
            title = app.map { "Se terminó \($0) por hoy" } ?? "Se terminó tu tiempo por hoy"
            if let dailyMinutes {
                lines.append("Ya usaste tus \(Formatting.minutes(dailyMinutes)) de \(groupName).")
            } else {
                lines.append("Ya usaste tu tiempo de \(groupName).")
            }
            lines.append("Mañana arranca de cero.")
        } else {
            title = "\(app ?? groupName) está en pausa"
            if let windowEnd {
                lines.append("\(groupName) está bloqueado hasta las \(Formatting.clock(windowEnd)).")
            } else {
                lines.append("\(groupName) está en horario de bloqueo.")
            }
        }
        lines.append(who.map { "Si de verdad lo necesitás, pedile minutos a \($0)." }
            ?? "Si de verdad lo necesitás, pedí minutos.")
        if canUseWildcard {
            lines.append("Te queda el comodín de \(UsageRules.wildcardMinutes) min: lo usás desde la app.")
        }
        return ShieldText(title: title, subtitle: lines.joined(separator: "\n"), askLabel: askLabel)
    }
}
