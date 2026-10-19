import Foundation

public enum Tier: String, Codable, CaseIterable, Sendable, Comparable {
    case bronze, silver, gold, platinum, diamond, present

    public var title: String { rawValue.capitalized }

    public var symbol: String {
        switch self {
        case .bronze: "shield.fill"
        case .silver: "shield.lefthalf.filled"
        case .gold: "star.circle.fill"
        case .platinum: "seal.fill"
        case .diamond: "diamond.fill"
        case .present: "crown.fill"
        }
    }

    /// Typical weekly XP range of competitors in this tier (used by the offline league).
    var simulatedWeeklyXP: ClosedRange<Int> {
        switch self {
        case .bronze: 150...900
        case .silver: 300...1_300
        case .gold: 500...1_800
        case .platinum: 800...2_400
        case .diamond: 1_100...3_000
        case .present: 1_500...3_800
        }
    }

    public var promoted: Tier { Tier.allCases.first { $0 > self } ?? self }
    public var demoted: Tier { Tier.allCases.last { $0 < self } ?? self }

    private var order: Int { Tier.allCases.firstIndex(of: self) ?? 0 }
    public static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.order < rhs.order }
}

public struct LeagueState: Codable, Equatable, Sendable {
    public var tier: Tier
    public var currentWeek: WeekID?
    public var lastResult: WeekResult?

    public init(tier: Tier = .bronze, currentWeek: WeekID? = nil, lastResult: WeekResult? = nil) {
        self.tier = tier
        self.currentWeek = currentWeek
        self.lastResult = lastResult
    }
}

public struct WeekResult: Codable, Equatable, Sendable {
    public var week: WeekID
    public var rank: Int
    public var from: Tier
    public var to: Tier

    public init(week: WeekID, rank: Int, from: Tier, to: Tier) {
        self.week = week
        self.rank = rank
        self.from = from
        self.to = to
    }
}

public struct Standing: Identifiable, Equatable, Sendable {
    public var id: String { handle }
    public var handle: String
    public var xp: Int
    public var rank: Int
    public var isMe: Bool

    public init(handle: String, xp: Int, rank: Int, isMe: Bool) {
        self.handle = handle
        self.xp = xp
        self.rank = rank
        self.isMe = isMe
    }
}

public enum LeagueZone: Equatable, Sendable { case promote, stay, demote }

public enum LeagueEngine {
    public static let cohortSize = 30
    public static let promoteCount = 10
    public static let demoteCount = 5

    public static func zone(rank: Int, tier: Tier, cohortSize: Int = cohortSize) -> LeagueZone {
        if rank <= promoteCount && tier != .present { return .promote }
        if rank > cohortSize - demoteCount && tier != .bronze && cohortSize > 15 { return .demote }
        return .stay
    }

    public static func ranked(_ entries: [(handle: String, xp: Int, isMe: Bool)]) -> [Standing] {
        entries
            .sorted { $0.xp != $1.xp ? $0.xp > $1.xp : ($0.isMe ? true : ($1.isMe ? false : $0.handle < $1.handle)) }
            .enumerated()
            .map { Standing(handle: $1.handle, xp: $1.xp, rank: $0 + 1, isMe: $1.isMe) }
    }

    /// Offline league: 29 deterministic competitors whose XP grows over the week.
    public static func simulatedStandings(
        week: WeekID, tier: Tier, myHandle: String, myXP: Int, progress: Double
    ) -> [Standing] {
        var rng = SeededRandom(seed: "league-\(week)-\(tier.rawValue)")
        let bots = (0..<(cohortSize - 1)).map { index -> (handle: String, xp: Int, isMe: Bool) in
            let target = Int.random(in: tier.simulatedWeeklyXP, using: &rng)
            // Each competitor has its own pace; some start strong, some finish strong.
            let pace = Double.random(in: 0.6...1.6, using: &rng)
            let curve = pow(min(1, max(0, progress)), pace)
            return (handle: BotNames.name(index: index, using: &rng), xp: Int(Double(target) * curve), isMe: false)
        }
        return ranked(bots + [(handle: myHandle.isEmpty ? "you" : myHandle, xp: myXP, isMe: true)])
    }

    public static func resolve(rank: Int, tier: Tier, cohortSize: Int = cohortSize) -> Tier {
        switch zone(rank: rank, tier: tier, cohortSize: cohortSize) {
        case .promote: tier.promoted
        case .demote: tier.demoted
        case .stay: tier
        }
    }
}

extension AppState {
    /// Rolls the offline league forward when a new week begins.
    public func rollingLeague(to week: WeekID) -> AppState {
        guard let current = league.currentWeek else {
            return with(\.league, LeagueState(tier: league.tier, currentWeek: week, lastResult: nil))
        }
        guard current != week else { return self }
        let finalStandings = LeagueEngine.simulatedStandings(
            week: current, tier: league.tier, myHandle: profile.handle, myXP: weeklyXP(current), progress: 1
        )
        let rank = finalStandings.first(where: \.isMe)?.rank ?? LeagueEngine.cohortSize
        let next = LeagueEngine.resolve(rank: rank, tier: league.tier)
        let result = WeekResult(week: current, rank: rank, from: league.tier, to: next)
        return with(\.league, LeagueState(tier: next, currentWeek: week, lastResult: result))
    }
}

enum BotNames {
    static let first = ["sky", "river", "maya", "leo", "ivy", "kai", "noor", "juno", "ezra", "luna", "milo", "ana", "theo", "zoe", "remy", "sage", "otis", "wren", "nia", "cal", "rio", "bea", "finn", "isla", "omar", "lena", "ravi", "tess", "jude", "mei"]
    static let second = ["walks", "reads", "runs", "paints", "cooks", "climbs", "hikes", "writes", "sings", "knits", "bikes", "swims", "naps", "builds", "plays"]

    static func name(index: Int, using rng: inout SeededRandom) -> String {
        let a = first[(index + Int.random(in: 0..<first.count, using: &rng)) % first.count]
        let b = second.randomElement(using: &rng) ?? "offline"
        return "\(a)_\(b)\(Int.random(in: 1...99, using: &rng))"
    }
}
