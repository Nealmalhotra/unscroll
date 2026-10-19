import Foundation

/// The subset of state the extensions need. Written by the app whenever settings change.
public struct SharedConfig: Codable, Equatable, Sendable {
    public var dailyGoalMinutes: Int
    public var doomscrollAlertsEnabled: Bool
    /// Encoded `FamilyActivitySelection` of everything to track ("All Apps & Categories").
    public var trackingSelectionData: Data
    public var intentions: [Intention]
    public var plans: [SessionPlan]
    public var activeSession: ActiveSession?

    public init(
        dailyGoalMinutes: Int = 120,
        doomscrollAlertsEnabled: Bool = true,
        trackingSelectionData: Data = Data(),
        intentions: [Intention] = [],
        plans: [SessionPlan] = [],
        activeSession: ActiveSession? = nil
    ) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.doomscrollAlertsEnabled = doomscrollAlertsEnabled
        self.trackingSelectionData = trackingSelectionData
        self.intentions = intentions
        self.plans = plans
        self.activeSession = activeSession
    }

    public init(state: AppState, trackingSelectionData: Data) {
        self.init(
            dailyGoalMinutes: state.profile.dailyGoalMinutes,
            doomscrollAlertsEnabled: state.profile.doomscrollAlertsEnabled,
            trackingSelectionData: trackingSelectionData,
            intentions: state.intentions,
            plans: state.plans,
            activeSession: state.activeSession
        )
    }

    public static func file(root: URL = SharedContainer.directory()) -> JSONFile<SharedConfig> {
        JSONFile(url: root.appendingPathComponent("config.json"))
    }

    public static func load(root: URL = SharedContainer.directory()) -> SharedConfig {
        (try? file(root: root).load()) ?? SharedConfig()
    }
}

/// Everything decided on the shield today. Single writer: the shield action extension.
public struct OpensLedger: Codable, Equatable, Sendable {
    public var day: DayKey
    /// Intentional opens per intention.
    public var counts: [UUID: Int]
    /// When each temporarily unlocked intention should be shielded again.
    public var unlockedUntil: [UUID: Date]
    /// Time-limited intentions the user chose to ignore for the rest of today.
    public var overridden: Set<UUID>
    /// Sessions the user ended from the shield; extensions must not treat them as active.
    public var brokenSessions: Set<UUID>

    public init(
        day: DayKey,
        counts: [UUID: Int] = [:],
        unlockedUntil: [UUID: Date] = [:],
        overridden: Set<UUID> = [],
        brokenSessions: Set<UUID> = []
    ) {
        self.day = day
        self.counts = counts
        self.unlockedUntil = unlockedUntil
        self.overridden = overridden
        self.brokenSessions = brokenSessions
    }

    public static func file(root: URL = SharedContainer.directory()) -> JSONFile<OpensLedger> {
        JSONFile(url: root.appendingPathComponent("opens.json"))
    }

    /// Today's ledger; a ledger from a previous day reads as empty.
    public static func load(today: DayKey, root: URL = SharedContainer.directory()) -> OpensLedger {
        guard let ledger = try? file(root: root).load(), ledger.day == today else { return OpensLedger(day: today) }
        return ledger
    }

    public func count(for id: UUID) -> Int { counts[id] ?? 0 }

    public func remaining(for intention: Intention) -> Int? {
        intention.dailyOpens.map { max(0, $0 - count(for: intention.id)) }
    }

    public func recordingOpen(_ id: UUID, until: Date) -> OpensLedger {
        OpensLedger(
            day: day,
            counts: counts.merging([id: count(for: id) + 1]) { _, new in new },
            unlockedUntil: unlockedUntil.merging([id: until]) { _, new in new },
            overridden: overridden,
            brokenSessions: brokenSessions
        )
    }

    public func overriding(_ id: UUID) -> OpensLedger {
        OpensLedger(day: day, counts: counts, unlockedUntil: unlockedUntil, overridden: overridden.union([id]), brokenSessions: brokenSessions)
    }

    public func breakingSession(_ id: UUID) -> OpensLedger {
        OpensLedger(day: day, counts: counts, unlockedUntil: unlockedUntil, overridden: overridden, brokenSessions: brokenSessions.union([id]))
    }
}
