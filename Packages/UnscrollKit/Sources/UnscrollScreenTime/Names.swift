#if os(iOS)
import DeviceActivity
import Foundation
import ManagedSettings

/// Stable identifiers shared between the app and its extensions.
public enum ActivityNames {
    public static var daily: DeviceActivityName { DeviceActivityName("daily") }
    static let planPrefix = "plan."
    static let sessionPrefix = "session."
    static let relockPrefix = "relock."

    public static func plan(_ id: UUID) -> DeviceActivityName {
        DeviceActivityName("\(planPrefix)\(id.uuidString)")
    }

    public static func session(_ id: UUID) -> DeviceActivityName { DeviceActivityName("\(sessionPrefix)\(id.uuidString)") }
    public static func relock(_ id: UUID) -> DeviceActivityName { DeviceActivityName("\(relockPrefix)\(id.uuidString)") }

    public enum Parsed: Equatable {
        case daily
        case plan(UUID)
        case session(UUID)
        case relock(UUID)
        case unknown
    }

    public static func parse(_ name: DeviceActivityName) -> Parsed {
        let raw = name.rawValue
        if raw == daily.rawValue { return .daily }
        func uuid(after prefix: String) -> UUID? {
            guard raw.hasPrefix(prefix) else { return nil }
            let rest = raw.dropFirst(prefix.count)
            return UUID(uuidString: String(rest.prefix(36)))
        }
        if let id = uuid(after: planPrefix) { return .plan(id) }
        if let id = uuid(after: sessionPrefix) { return .session(id) }
        if let id = uuid(after: relockPrefix) { return .relock(id) }
        return .unknown
    }
}

public enum EventNames {
    static let milestonePrefix = "milestone."
    static let intentionPrefix = "intention."
    public static var goal: DeviceActivityEvent.Name { .init("goal") }
    public static var relock: DeviceActivityEvent.Name { .init("relock") }
    /// Usage is reported in these steps; it's the resolution of the in-app screen time estimate.
    public static let milestoneStep = 15
    public static let milestoneMax = 16 * 60

    public static func milestone(_ minutes: Int) -> DeviceActivityEvent.Name { .init("\(milestonePrefix)\(minutes)") }
    public static func intention(_ id: UUID) -> DeviceActivityEvent.Name { .init("\(intentionPrefix)\(id.uuidString)") }

    public enum Parsed: Equatable {
        case goal, relock, milestone(Int), intention(UUID), unknown
    }

    public static func parse(_ name: DeviceActivityEvent.Name) -> Parsed {
        let raw = name.rawValue
        if raw == goal.rawValue { return .goal }
        if raw == relock.rawValue { return .relock }
        if raw.hasPrefix(milestonePrefix), let minutes = Int(raw.dropFirst(milestonePrefix.count)) { return .milestone(minutes) }
        if raw.hasPrefix(intentionPrefix), let id = UUID(uuidString: String(raw.dropFirst(intentionPrefix.count))) { return .intention(id) }
        return .unknown
    }
}

extension ManagedSettingsStore.Name {
    public static var session: Self { Self("session") }
    public static func intention(_ id: UUID) -> Self { Self("intention.\(id.uuidString)") }
}
#endif
