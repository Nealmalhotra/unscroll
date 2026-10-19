#if os(iOS)
import DeviceActivity
import FamilyControls
import Foundation
import UnscrollKit

/// Registers DeviceActivity schedules so the monitor extension runs even when the app is closed.
///
/// Re-registering a running schedule makes iOS fire `intervalDidStart` again and restart threshold
/// counting, so schedules are only replaced when their inputs actually changed (fingerprints).
public enum ActivityScheduler {
    static var center: DeviceActivityCenter { DeviceActivityCenter() }
    static let dailyFingerprintKey = "scheduler.daily"
    static let plansFingerprintKey = "scheduler.plans"

    /// The always-on daily schedule: usage milestones, the goal threshold and intention time limits.
    public static func startDaily(config: SharedConfig, defaults: UserDefaults = .standard) throws {
        let fingerprint = DailyFingerprint(config: config).data
        let isRunning = center.activities.contains(ActivityNames.daily)
        guard !isRunning || defaults.data(forKey: dailyFingerprintKey) != fingerprint else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )
        center.stopMonitoring([ActivityNames.daily])
        try center.startMonitoring(ActivityNames.daily, during: schedule, events: dailyEvents(config: config))
        defaults.set(fingerprint, forKey: dailyFingerprintKey)
    }

    static func dailyEvents(config: SharedConfig) -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        let tracking = SelectionCodec.decode(config.trackingSelectionData)
        if !SelectionCodec.isEmpty(config.trackingSelectionData) {
            events[EventNames.goal] = event(tracking, minutes: config.dailyGoalMinutes)
            for minutes in stride(from: EventNames.milestoneStep, through: EventNames.milestoneMax, by: EventNames.milestoneStep) {
                events[EventNames.milestone(minutes)] = event(tracking, minutes: minutes)
            }
        }
        for intention in config.intentions {
            guard let minutes = intention.dailyMinutes, !SelectionCodec.isEmpty(intention.selectionData) else { continue }
            events[EventNames.intention(intention.id)] = event(SelectionCodec.decode(intention.selectionData), minutes: minutes)
        }
        return events
    }

    /// Counts usage already logged earlier in the interval where supported, so a restarted
    /// schedule doesn't reset today's progress toward thresholds.
    static func event(_ selection: FamilyActivitySelection, minutes: Int, includesPastActivity: Bool = true) -> DeviceActivityEvent {
        let threshold = DateComponents(minute: minutes)
        if #available(iOS 17.4, *) {
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: threshold,
                includesPastActivity: includesPastActivity
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: threshold
        )
    }

    /// One daily-repeating schedule per plan; the extension checks the weekday when it starts.
    /// (One activity per plan *and* weekday would exhaust Apple's ~20 activity limit.)
    public static func schedulePlans(_ plans: [SessionPlan], defaults: UserDefaults = .standard) throws {
        let active = plans.filter { $0.enabled && $0.isValid }.prefix(SessionRules.maximumPlans)
        let fingerprint = (try? JSONEncoder().encode(Array(active))) ?? Data()
        guard defaults.data(forKey: plansFingerprintKey) != fingerprint else { return }
        let existing = center.activities.filter {
            if case .plan = ActivityNames.parse($0) { return true }
            return false
        }
        center.stopMonitoring(existing)
        for plan in active {
            try center.startMonitoring(ActivityNames.plan(plan.id), during: schedule(for: plan))
        }
        defaults.set(fingerprint, forKey: plansFingerprintKey)
    }

    /// An end earlier than the start means the interval runs past midnight.
    static func schedule(for plan: SessionPlan) -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: DateComponents(hour: plan.startMinute / 60, minute: plan.startMinute % 60),
            intervalEnd: DateComponents(hour: plan.endMinute / 60, minute: plan.endMinute % 60),
            repeats: true
        )
    }

    /// A one-off schedule whose end lets the extension lift a manual session's shields on time.
    public static func monitorSessionEnd(_ session: ActiveSession, calendar: Calendar = .current) throws {
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: session.startedAt),
            intervalEnd: calendar.dateComponents(components, from: session.endsAt),
            repeats: false
        )
        try center.startMonitoring(ActivityNames.session(session.id), during: schedule)
    }

    public static func stopSessionMonitor(_ id: UUID) {
        center.stopMonitoring([ActivityNames.session(id)])
    }

    /// After an intentional open, re-shield the intention once it has been used for `minutesPerOpen`,
    /// or when the (≥15 minute) interval ends, whichever comes first.
    public static func monitorRelock(_ intention: Intention, now: Date = Date(), calendar: Calendar = .current) throws {
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        // DeviceActivity requires an interval of at least 15 minutes.
        let end = now.addingTimeInterval(TimeInterval(max(15, intention.minutesPerOpen + 1) * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: now),
            intervalEnd: calendar.dateComponents(components, from: end),
            repeats: false
        )
        let selection = SelectionCodec.decode(intention.selectionData)
        center.stopMonitoring([ActivityNames.relock(intention.id)])
        try center.startMonitoring(
            ActivityNames.relock(intention.id),
            during: schedule,
            events: [EventNames.relock: event(selection, minutes: intention.minutesPerOpen, includesPastActivity: false)]
        )
    }

    public static func stopAll(defaults: UserDefaults = .standard) {
        center.stopMonitoring()
        defaults.removeObject(forKey: dailyFingerprintKey)
        defaults.removeObject(forKey: plansFingerprintKey)
    }
}

/// Only the inputs that change the daily schedule's events.
struct DailyFingerprint: Encodable {
    let goal: Int
    let tracking: Data
    let limits: [String]

    init(config: SharedConfig) {
        goal = config.dailyGoalMinutes
        tracking = config.trackingSelectionData
        limits = config.intentions.compactMap { intention in
            intention.dailyMinutes.map { "\(intention.id):\($0):\(intention.selectionData.base64EncodedString())" }
        }.sorted()
    }

    var data: Data { (try? JSONEncoder().encode(self)) ?? Data() }
}
#endif
