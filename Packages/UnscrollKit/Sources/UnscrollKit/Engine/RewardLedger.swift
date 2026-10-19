import Foundation

public enum RedemptionError: Error, Equatable, LocalizedError {
    case insufficientPoints(needed: Int, available: Int)

    public var errorDescription: String? {
        switch self {
        case let .insufficientPoints(needed, available):
            "You need \(needed - available) more points for this reward."
        }
    }
}

/// Points = XP earned − XP spent on rewards. XP itself (for levels/leaderboards) is never reduced.
public enum RewardLedger {
    public static func lifetimeXP(_ ledger: [XPEntry]) -> Int { ledger.reduce(0) { $0 + $1.amount } }

    public static func balance(ledger: [XPEntry], redemptions: [Redemption]) -> Int {
        lifetimeXP(ledger) - redemptions.reduce(0) { $0 + $1.cost }
    }

    public static func xp(in week: WeekID, ledger: [XPEntry], timeZone: TimeZone = .current) -> Int {
        ledger.filter { week.contains($0.at, timeZone: timeZone) }.reduce(0) { $0 + $1.amount }
    }

    public static func redeem(
        _ reward: Reward,
        ledger: [XPEntry],
        redemptions: [Redemption],
        at date: Date
    ) -> Result<Redemption, RedemptionError> {
        let available = balance(ledger: ledger, redemptions: redemptions)
        guard available >= reward.cost else {
            return .failure(.insufficientPoints(needed: reward.cost, available: available))
        }
        return .success(Redemption(rewardID: reward.id, title: reward.title, cost: reward.cost, at: date))
    }
}
