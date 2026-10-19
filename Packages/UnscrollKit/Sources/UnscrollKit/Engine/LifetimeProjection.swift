import Foundation

/// The onboarding "shock and reframe": how much of your remaining life goes to your phone,
/// and how much you get back by cutting usage.
public struct LifetimeProjection: Equatable, Sendable {
    public var yearsOnPhone: Double
    public var yearsReclaimed: Double
    public var daysPerYear: Double

    public static let lifeExpectancy = 80
    public static let targetReduction = 0.5

    public init(dailyHours: Double, age: Int, reduction: Double = targetReduction, lifeExpectancy: Int = lifeExpectancy) {
        let hours = min(24, max(0, dailyHours))
        let remainingYears = Double(max(0, lifeExpectancy - age))
        // Years are full 24-hour years, matching how this stat is usually quoted.
        yearsOnPhone = hours * remainingYears / 24
        yearsReclaimed = yearsOnPhone * min(1, max(0, reduction))
        daysPerYear = hours * 365 / 24
    }
}
