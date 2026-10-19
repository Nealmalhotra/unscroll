import ManagedSettings
import UnscrollKit
import UnscrollScreenTime

/// Handles taps on the shield buttons.
final class ShieldActionExtension: ShieldActionDelegate {
    private let resolver = ShieldResolver()
    private let handler = ShieldActionHandler()

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handler.handle(action, context: resolver.context(application: application, category: nil)))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handler.handle(action, context: resolver.context(application: nil, category: nil, webDomain: webDomain)))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(handler.handle(action, context: resolver.context(application: nil, category: category)))
    }
}
