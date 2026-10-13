import Foundation
import ManagedSettings
import ManagedSettingsUI
import ScreenCore
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(groupID: application.token.flatMap { Enforcer().groupID(containing: $0) })
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let e = Enforcer()
        let byApp = application.token.flatMap { e.groupID(containing: $0) }
        return make(groupID: byApp ?? category.token.flatMap { e.groupID(containing: $0) })
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(groupID: webDomain.token.flatMap { Enforcer().groupID(containing: $0) })
    }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        let e = Enforcer()
        let byDomain = webDomain.token.flatMap { e.groupID(containing: $0) }
        return make(groupID: byDomain ?? category.token.flatMap { e.groupID(containing: $0) })
    }

    private func make(groupID: UUID?) -> ShieldConfiguration {
        let e = Enforcer()
        let ledger = e.ledger(now: .now)
        let group = groupID.flatMap(e.group)
        let runtime = group.map { ledger.runtime[$0.id.uuidString] ?? GroupRuntime() }
        let reason: String
        switch (group, runtime) {
        case let (g?, rt?) where rt.limitReached: reason = "Se terminó tu tiempo de hoy en \(g.name)."
        case let (g?, _): reason = "\(g.name) está en horario de bloqueo."
        default: reason = "Esta app está bloqueada."
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1),
            icon: UIImage(systemName: "hourglass"),
            title: .init(text: "Screen", color: .white),
            subtitle: .init(text: reason, color: UIColor(white: 0.85, alpha: 1)),
            primaryButtonLabel: .init(text: "Pedir tiempo", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: group != nil && ledger.canUseWildcard
                ? .init(text: "Usar comodín (\(UsageRules.wildcardMinutes) min)", color: .white)
                : nil)
    }
}
