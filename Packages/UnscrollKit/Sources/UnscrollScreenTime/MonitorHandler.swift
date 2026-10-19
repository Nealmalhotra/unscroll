#if os(iOS)
import DeviceActivity
import Foundation
import os
import UnscrollKit

/// The logic behind the DeviceActivityMonitor extension. Lives here so the extension target is a thin shim.
public struct MonitorHandler {
    let root: URL
    let inbox: EventInbox
    let log = Logger(subsystem: "org.unscroll", category: "monitor")

    public init(root: URL = SharedContainer.directory()) {
        self.root = root
        inbox = EventInbox(root: root)
    }

    var config: SharedConfig { SharedConfig.load(root: root) }

    func post(_ kind: ExtensionEvent.Kind) {
        do {
            try inbox.post(ExtensionEvent(kind: kind))
        } catch {
            log.error("Failed to post event: \(error.localizedDescription, privacy: .public)")
        }
    }

    func save<T: Codable & Sendable>(_ value: T, to file: JSONFile<T>) {
        do {
            try file.save(value)
        } catch {
            log.error("Failed to save \(file.url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    public func intervalDidStart(for activity: DeviceActivityName) {
        switch ActivityNames.parse(activity) {
        case .daily:
            startDay()
        case let .plan(planID):
            startPlan(planID)
        case .session, .relock, .unknown:
            break
        }
    }

    /// New day: opens-limited apps go back behind the "is this intentional?" shield.
    /// Skipped when the daily schedule is merely re-registered mid-day.
    func startDay() {
        let today = DayKey(Date())
        guard !LimitLedger.hasStarted(today, root: root) else { return }
        save(LimitLedger(day: today), to: LimitLedger.file(root: root))
        ShieldController.resetIntentions(config.intentions)
    }

    func startPlan(_ planID: UUID) {
        let now = Date()
        let config = config
        guard let plan = config.plans.first(where: { $0.id == planID }), plan.enabled,
              plan.weekdays.contains(Calendar.current.component(.weekday, from: now)) else { return }
        // Don't take over a running manual session or another plan's session.
        if let manual = config.activeSession, !manual.isFinished(at: now) { return }
        if let other = ScheduledSessionFile.load(root: root), !other.isFinished(at: now) { return }
        let session = plan.session(startingAt: now)
        save(ScheduledSessionFile(session: session), to: ScheduledSessionFile.file(root: root))
        ShieldController.applySession(session)
        post(.scheduledSessionStarted(session: session))
        Nudges.send(title: "\(plan.name) has started", body: "Distracting apps are blocked until \(SessionPlan.clockLabel(plan.endMinute)).")
    }

    public func intervalDidEnd(for activity: DeviceActivityName) {
        switch ActivityNames.parse(activity) {
        case let .plan(planID):
            endPlan(planID)
        case let .session(sessionID):
            // Manual session reached its end while the app was closed.
            guard config.activeSession?.id == sessionID else { return }
            ShieldController.clearSession()
            Nudges.send(title: "Session complete 🎉", body: "Open Unscroll to collect your XP.")
        case let .relock(intentionID):
            // The usage threshold never fired (app barely used): relock when the window closes.
            if let intention = config.intentions.first(where: { $0.id == intentionID }) { ShieldController.shield(intention) }
        case .daily, .unknown:
            break
        }
    }

    /// Only lifts shields this plan applied, never a manual session's or another plan's.
    func endPlan(_ planID: UUID) {
        guard let scheduled = ScheduledSessionFile.load(root: root), scheduled.planID == planID else { return }
        save(ScheduledSessionFile(session: nil), to: ScheduledSessionFile.file(root: root))
        let broken = OpensLedger.load(today: DayKey(scheduled.startedAt), root: root).brokenSessions.contains(scheduled.id)
        guard !broken else { return }
        ShieldController.clearSession()
        post(.scheduledSessionEnded(planID: planID))
        Nudges.send(title: "Session complete 🎉", body: "Open Unscroll to collect your XP.")
    }

    public func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        switch EventNames.parse(event) {
        case .goal:
            post(.goalExceeded)
            Nudges.send(title: "You've hit your daily goal", body: "That's \(TimeFormat.minutes(config.dailyGoalMinutes)) today. Time to put the phone down.")
        case let .milestone(minutes):
            post(.usageMilestone(minutes: minutes))
            if config.doomscrollAlertsEnabled, minutes % 60 == 0 {
                Nudges.send(title: "Still scrolling?", body: "You've spent \(TimeFormat.minutes(minutes)) on your phone today.")
            }
        case let .intention(id):
            guard let intention = config.intentions.first(where: { $0.id == id }) else { return }
            let today = DayKey(Date())
            save(LimitLedger.load(today: today, root: root).reaching(id), to: LimitLedger.file(root: root))
            if !OpensLedger.load(today: today, root: root).overridden.contains(id) { ShieldController.shield(intention) }
            post(.intentionLimitReached(intentionID: id))
        case .relock:
            guard case let .relock(id) = ActivityNames.parse(activity),
                  let intention = config.intentions.first(where: { $0.id == id }) else { return }
            ShieldController.shield(intention)
            DeviceActivityCenter().stopMonitoring([activity])
        case .unknown:
            log.notice("Unknown event \(event.rawValue, privacy: .public)")
        }
    }
}
#endif
