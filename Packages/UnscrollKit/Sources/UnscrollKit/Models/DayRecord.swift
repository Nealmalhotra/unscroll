import Foundation

/// Everything known about one calendar day. Screen time is a lower bound assembled from
/// DeviceActivity threshold events, because Apple never hands raw usage to the host app.
public struct DayRecord: Codable, Equatable, Sendable {
    public var day: DayKey
    public var goalMinutes: Int
    public var screenMinutesAtLeast: Int
    public var goalExceeded: Bool
    public var brokenIntentions: Set<UUID>
    public var trackedIntentions: Set<UUID>
    public var opens: [UUID: Int]
    public var finalized: Bool
    public var tipRead: Bool
    public var completedQuests: Set<String>

    public init(
        day: DayKey,
        goalMinutes: Int,
        screenMinutesAtLeast: Int = 0,
        goalExceeded: Bool = false,
        brokenIntentions: Set<UUID> = [],
        trackedIntentions: Set<UUID> = [],
        opens: [UUID: Int] = [:],
        finalized: Bool = false,
        tipRead: Bool = false,
        completedQuests: Set<String> = []
    ) {
        self.day = day
        self.goalMinutes = goalMinutes
        self.screenMinutesAtLeast = screenMinutesAtLeast
        self.goalExceeded = goalExceeded
        self.brokenIntentions = brokenIntentions
        self.trackedIntentions = trackedIntentions
        self.opens = opens
        self.finalized = finalized
        self.tipRead = tipRead
        self.completedQuests = completedQuests
    }

    public var keptIntentions: Set<UUID> { trackedIntentions.subtracting(brokenIntentions) }

    /// A day counts toward the streak when the goal was met and every intention was kept.
    public var isSuccess: Bool { !goalExceeded && brokenIntentions.isEmpty }

    public var goalRemainingFraction: Double {
        guard goalMinutes > 0 else { return 0 }
        return max(0, 1 - Double(screenMinutesAtLeast) / Double(goalMinutes))
    }
}
