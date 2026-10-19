#if os(iOS)
import Foundation
import ManagedSettings
import UnscrollKit

/// Works out why an app is shielded, so the shield screen and its buttons can respond correctly.
public struct ShieldResolver {
    let root: URL

    public init(root: URL = SharedContainer.directory()) { self.root = root }

    public func context(application: ApplicationToken?, category: ActivityCategoryToken?, webDomain: WebDomainToken? = nil) -> ShieldContext {
        let now = Date()
        let today = DayKey(now)
        let config = SharedConfig.load(root: root)
        let ledger = OpensLedger.load(today: today, root: root)
        // A scheduled session may not have reached the app yet; check the monitor's record too.
        let candidates = [config.activeSession, ScheduledSessionFile.load(root: root)].compactMap { $0 }
        if let session = candidates.first(where: { !$0.isFinished(at: now) && !ledger.brokenSessions.contains($0.id) }) {
            return .session(session)
        }
        let matches = config.intentions.first {
            SelectionCodec.contains($0.selectionData, application: application, category: category)
                || SelectionCodec.contains($0.selectionData, webDomain: webDomain)
        }
        guard let intention = matches else { return .unknown }
        if LimitLedger.load(today: today, root: root).reached.contains(intention.id) {
            return .intentionTimeUp(intention)
        }
        return .intentionOpens(intention, remaining: ledger.remaining(for: intention) ?? 0)
    }
}
#endif
