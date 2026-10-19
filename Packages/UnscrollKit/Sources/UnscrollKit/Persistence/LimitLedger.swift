import Foundation

/// Intentions whose daily time allowance ran out today. Single writer: the monitor extension.
public struct LimitLedger: Codable, Equatable, Sendable {
    public var day: DayKey
    public var reached: Set<UUID>

    public init(day: DayKey, reached: Set<UUID> = []) {
        self.day = day
        self.reached = reached
    }

    public static func file(root: URL = SharedContainer.directory()) -> JSONFile<LimitLedger> {
        JSONFile(url: root.appendingPathComponent("limits.json"))
    }

    public static func load(today: DayKey, root: URL = SharedContainer.directory()) -> LimitLedger {
        guard let ledger = try? file(root: root).load(), ledger.day == today else { return LimitLedger(day: today) }
        return ledger
    }

    /// True when the monitor has already started today's ledger, i.e. the day's reset already ran.
    /// Lets a re-registered daily schedule avoid resetting shields in the middle of the day.
    public static func hasStarted(_ today: DayKey, root: URL = SharedContainer.directory()) -> Bool {
        (try? file(root: root).load())?.day == today
    }

    public func reaching(_ id: UUID) -> LimitLedger {
        LimitLedger(day: day, reached: reached.union([id]))
    }
}

/// The session a scheduled plan started. Single writer: the monitor extension.
/// Lets shields recognize scheduled sessions before the app has seen them, and stops a plan's end
/// from clearing a manual session's shields.
public struct ScheduledSessionFile: Codable, Equatable, Sendable {
    public var session: ActiveSession?

    public init(session: ActiveSession?) { self.session = session }

    public static func file(root: URL = SharedContainer.directory()) -> JSONFile<ScheduledSessionFile> {
        JSONFile(url: root.appendingPathComponent("scheduled.json"))
    }

    public static func load(root: URL = SharedContainer.directory()) -> ActiveSession? {
        (try? file(root: root).load())?.session
    }
}
