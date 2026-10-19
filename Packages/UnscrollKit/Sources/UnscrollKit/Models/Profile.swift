import Foundation

public struct Profile: Codable, Equatable, Sendable {
    public var handle: String
    public var age: Int
    public var dailyGoalMinutes: Int
    public var reportedDailyHours: Double
    public var motivations: [Motivation]
    public var onboardingComplete: Bool
    public var doomscrollAlertsEnabled: Bool
    public var createdAt: Date

    public init(
        handle: String = "",
        age: Int = 25,
        dailyGoalMinutes: Int = 120,
        reportedDailyHours: Double = 4,
        motivations: [Motivation] = [],
        onboardingComplete: Bool = false,
        doomscrollAlertsEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.handle = handle
        self.age = age
        self.dailyGoalMinutes = dailyGoalMinutes
        self.reportedDailyHours = reportedDailyHours
        self.motivations = motivations
        self.onboardingComplete = onboardingComplete
        self.doomscrollAlertsEnabled = doomscrollAlertsEnabled
        self.createdAt = createdAt
    }

    public func with<T>(_ keyPath: WritableKeyPath<Profile, T>, _ value: T) -> Profile {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

public enum Motivation: String, Codable, CaseIterable, Sendable, Identifiable {
    case focus, sleep, mentalHealth, relationships, productivity, presence

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .focus: "Better focus"
        case .sleep: "Better sleep"
        case .mentalHealth: "Mental health"
        case .relationships: "Relationships"
        case .productivity: "Productivity"
        case .presence: "Be more present"
        }
    }

    public var symbol: String {
        switch self {
        case .focus: "scope"
        case .sleep: "moon.zzz.fill"
        case .mentalHealth: "brain.head.profile"
        case .relationships: "heart.fill"
        case .productivity: "checkmark.seal.fill"
        case .presence: "leaf.fill"
        }
    }
}
