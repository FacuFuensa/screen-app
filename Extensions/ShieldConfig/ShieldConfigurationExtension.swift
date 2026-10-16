import Foundation
import ManagedSettings
import ManagedSettingsUI
import ScreenCore
import UIKit

final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(groupID: application.token.flatMap { Enforcer().groupID(containing: $0) },
             appName: application.localizedDisplayName)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        let e = Enforcer()
        let byApp = application.token.flatMap { e.groupID(containing: $0) }
        return make(groupID: byApp ?? category.token.flatMap { e.groupID(containing: $0) },
                    appName: application.localizedDisplayName)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(groupID: webDomain.token.flatMap { Enforcer().groupID(containing: $0) }, appName: webDomain.domain)
    }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        let e = Enforcer()
        let byDomain = webDomain.token.flatMap { e.groupID(containing: $0) }
        return make(groupID: byDomain ?? category.token.flatMap { e.groupID(containing: $0) }, appName: webDomain.domain)
    }

    private func make(groupID: UUID?, appName: String?) -> ShieldConfiguration {
        let e = Enforcer()
        let ledger = e.ledger(now: .now)
        let group = groupID.flatMap(e.group)
        let runtime = group.map { ledger.runtime[$0.id.uuidString] ?? GroupRuntime() }
        let limitReached = runtime?.limitReached == true && runtime?.inWindow != true
        let text = ShieldWording.make(
            appName: appName, groupName: group?.name, limitReached: limitReached,
            dailyMinutes: group?.dailyMinutes, windowEnd: limitReached ? nil : group?.window?.endMinute,
            partner: AppGroup.defaults.string(forKey: SharedKey.partnerName),
            canUseWildcard: group != nil && ledger.canUseWildcard)
        let coral = UIColor(red: 1.0, green: 0.54, blue: 0.49, alpha: 1)  // Theme.coral, dark
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1),
            icon: UIImage(systemName: limitReached ? "hourglass.bottomhalf.filled" : "moon.zzz.fill")?
                .withTintColor(coral, renderingMode: .alwaysOriginal),
            title: .init(text: text.title, color: .white),
            subtitle: .init(text: text.subtitle, color: UIColor(white: 0.85, alpha: 1)),
            primaryButtonLabel: .init(text: "Cerrar", color: .black),
            primaryButtonBackgroundColor: .white,
            // Without a group there is nothing to ask for.
            secondaryButtonLabel: group != nil ? .init(text: text.askLabel, color: coral) : nil)
    }
}
