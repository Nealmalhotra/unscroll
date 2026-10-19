import Foundation

public enum XPReason: String, Codable, Sendable {
    case sessionCompleted, goalMet, intentionKept, streakBonus, quest, tipRead
}

public struct XPEntry: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var at: Date
    public var amount: Int
    public var reason: XPReason
    public var note: String

    public init(id: UUID = UUID(), at: Date, amount: Int, reason: XPReason, note: String) {
        self.id = id
        self.at = at
        self.amount = amount
        self.reason = reason
        self.note = note
    }
}

/// A user-defined real-life reward bought with XP points ("Movie night", "New book").
public struct Reward: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var emoji: String
    public var cost: Int

    public init(id: UUID = UUID(), title: String, emoji: String = "🎁", cost: Int) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.cost = cost
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if title.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Give the reward a name.") }
        if !(1...1_000_000).contains(cost) { errors.append("Cost must be between 1 and 1,000,000 points.") }
        return errors
    }
}

public struct Redemption: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var rewardID: UUID
    public var title: String
    public var cost: Int
    public var at: Date

    public init(id: UUID = UUID(), rewardID: UUID, title: String, cost: Int, at: Date) {
        self.id = id
        self.rewardID = rewardID
        self.title = title
        self.cost = cost
        self.at = at
    }
}

public struct AccountabilityPartner: Codable, Equatable, Sendable {
    public var name: String
    public var phone: String
    public var notifyOnMissedGoal: Bool

    public init(name: String, phone: String, notifyOnMissedGoal: Bool = true) {
        self.name = name
        self.phone = phone
        self.notifyOnMissedGoal = notifyOnMissedGoal
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Add your partner's name.") }
        let digits = phone.filter(\.isNumber)
        if !(7...15).contains(digits.count) { errors.append("Enter a valid phone number.") }
        return errors
    }
}

/// Honor-system commitment: miss your goal and you donate the pledge to a cause you chose.
public struct Pledge: Codable, Equatable, Sendable {
    public var amountDollars: Int
    public var causeName: String
    public var causeURL: URL?
    public var owed: Int

    public init(amountDollars: Int, causeName: String, causeURL: URL? = nil, owed: Int = 0) {
        self.amountDollars = amountDollars
        self.causeName = causeName
        self.causeURL = causeURL
        self.owed = owed
    }
}
