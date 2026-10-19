import ManagedSettings
import ManagedSettingsUI
import UIKit
import UnscrollKit
import UnscrollScreenTime

/// Customizes the screen shown over a blocked app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    private let resolver = ShieldResolver()
    private let accent = UIColor(red: 0.16, green: 0.55, blue: 0.43, alpha: 1)
    private let beast = UIColor(red: 0.93, green: 0.36, blue: 0.18, alpha: 1)

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(resolver.context(application: application.token, category: nil))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(resolver.context(application: application.token, category: category.token))
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(resolver.context(application: nil, category: nil, webDomain: webDomain.token))
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(resolver.context(application: nil, category: category.token, webDomain: webDomain.token))
    }

    private func make(_ context: ShieldContext) -> ShieldConfiguration {
        let copy = context.copy
        let isBeast: Bool = if case let .session(session) = context { session.beastMode } else { false }
        let tint = isBeast ? beast : accent
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterial,
            backgroundColor: tint.withAlphaComponent(0.12),
            icon: UIImage(systemName: isBeast ? "flame.fill" : "leaf.fill")?.withTintColor(tint, renderingMode: .alwaysOriginal),
            title: .init(text: copy.title, color: .label),
            subtitle: .init(text: copy.subtitle, color: .secondaryLabel),
            primaryButtonLabel: .init(text: copy.primaryButton, color: .white),
            primaryButtonBackgroundColor: tint,
            secondaryButtonLabel: copy.secondaryButton.map { .init(text: $0, color: tint) }
        )
    }
}
