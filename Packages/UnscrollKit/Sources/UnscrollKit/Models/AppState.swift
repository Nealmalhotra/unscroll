import Foundation

/// The whole persisted state of the app. Treated as an immutable value:
/// every mutation goes through a reducer method that returns a new copy.
public struct AppState: Codable, Equatable, Sendable {
    public static let schemaVersion = 1
    static let processedEventMemory = 2_000

    public var version: Int
    public var profile: Profile
    public var intentions: [Intention]
    public var plans: [SessionPlan]
    public var activeSession: ActiveSession?
    public var sessionHistory: [SessionRecord]
    public var days: [DayKey: DayRecord]
    public var xpLedger: [XPEntry]
    public var rewards: [Reward]
    public var redemptions: [Redemption]
    public var partner: AccountabilityPartner?
    public var pledge: Pledge?
    public var league: LeagueState
    /// Days whose missed goal should be reported to the accountability partner.
    public var pendingPartnerAlerts: [DayKey]
    public var processedEventIDs: [UUID]

    public init(
        profile: Profile = Profile(),
        intentions: [Intention] = [],
        plans: [SessionPlan] = [],
        activeSession: ActiveSession? = nil,
        sessionHistory: [SessionRecord] = [],
        days: [DayKey: DayRecord] = [:],
        xpLedger: [XPEntry] = [],
        rewards: [Reward] = Reward.starterRewards,
        redemptions: [Redemption] = [],
        partner: AccountabilityPartner? = nil,
        pledge: Pledge? = nil,
        league: LeagueState = LeagueState(),
        pendingPartnerAlerts: [DayKey] = [],
        processedEventIDs: [UUID] = []
    ) {
        self.version = Self.schemaVersion
        self.profile = profile
        self.intentions = intentions
        self.plans = plans
        self.activeSession = activeSession
        self.sessionHistory = sessionHistory
        self.days = days
        self.xpLedger = xpLedger
        self.rewards = rewards
        self.redemptions = redemptions
        self.partner = partner
        self.pledge = pledge
        self.league = league
        self.pendingPartnerAlerts = pendingPartnerAlerts
        self.processedEventIDs = processedEventIDs
    }

    public func with<T>(_ keyPath: WritableKeyPath<AppState, T>, _ value: T) -> AppState {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }

    // MARK: Derived values

    public var lifetimeXP: Int { RewardLedger.lifetimeXP(xpLedger) }
    public var pointsBalance: Int { RewardLedger.balance(ledger: xpLedger, redemptions: redemptions) }

    public func weeklyXP(_ week: WeekID) -> Int { RewardLedger.xp(in: week, ledger: xpLedger) }

    public func streak(today: DayKey, calendar: Calendar = .current) -> StreakSummary {
        StreakCalculator.summary(days: days, today: today, calendar: calendar)
    }

    public func sessions(on day: DayKey, calendar: Calendar = .current) -> [SessionRecord] {
        sessionHistory.filter { DayKey($0.startedAt, calendar: calendar) == day }
    }
}

extension Reward {
    public static let starterRewards: [Reward] = [
        Reward(title: "Guilt-free movie night", emoji: "🍿", cost: 500),
        Reward(title: "Fancy coffee", emoji: "☕️", cost: 250),
        Reward(title: "A new book", emoji: "📚", cost: 1_000),
        Reward(title: "Day trip with friends", emoji: "🚗", cost: 3_000),
    ]
}
