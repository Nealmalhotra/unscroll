#if os(iOS)
import Foundation
import ManagedSettings
import os
import UnscrollKit

/// The logic behind the ShieldAction extension.
public struct ShieldActionHandler {
    let root: URL
    let log = Logger(subsystem: "org.unscroll", category: "shield-action")

    public init(root: URL = SharedContainer.directory()) { self.root = root }

    public func handle(_ action: ShieldAction, context: ShieldContext) -> ShieldActionResponse {
        guard action == .secondaryButtonPressed else { return .close }
        switch context {
        case let .session(session):
            guard !session.beastMode else { return .close }
            update { $0.breakingSession(session.id) }
            post(.sessionBrokenFromShield(sessionID: session.id))
            ShieldController.clearSession()
            return .defer
        case let .intentionOpens(intention, _):
            recordOpen(intention)
            return .defer
        case let .intentionTimeUp(intention):
            overrideForToday(intention)
            return .defer
        case .unknown:
            return .close
        }
    }

    func recordOpen(_ intention: Intention) {
        let now = Date()
        update { $0.recordingOpen(intention.id, until: now.addingTimeInterval(TimeInterval(intention.minutesPerOpen * 60))) }
        do {
            try ActivityScheduler.monitorRelock(intention, now: now)
        } catch {
            log.error("Failed to record open: \(error.localizedDescription, privacy: .public)")
        }
        post(.intentionOpened(intentionID: intention.id))
        ShieldController.unshield(intention.id)
    }

    /// Already counted as broken by the limit event; record the choice so later resyncs don't re-shield.
    func overrideForToday(_ intention: Intention) {
        update { $0.overriding(intention.id) }
        ShieldController.unshield(intention.id)
    }

    func update(_ transform: (OpensLedger) -> OpensLedger) {
        let ledger = transform(OpensLedger.load(today: DayKey(Date()), root: root))
        do {
            try OpensLedger.file(root: root).save(ledger)
        } catch {
            log.error("Failed to save shield ledger: \(error.localizedDescription, privacy: .public)")
        }
    }

    func post(_ kind: ExtensionEvent.Kind) {
        do {
            try EventInbox(root: root).post(ExtensionEvent(kind: kind))
        } catch {
            log.error("Failed to post event: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
