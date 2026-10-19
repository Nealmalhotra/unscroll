import Foundation

public struct StreakSummary: Equatable, Sendable {
    public var current: Int
    public var longest: Int
    /// True when today is still on track (no goal/intention broken yet).
    public var todayOnTrack: Bool
}

public enum StreakCalculator {
    /// Current streak counts consecutive successful finalized days ending yesterday.
    /// Today never breaks the streak until it is finalized.
    public static func summary(days: [DayKey: DayRecord], today: DayKey, calendar: Calendar = .current) -> StreakSummary {
        var current = 0
        var cursor = today.adding(days: -1, calendar: calendar)
        while let record = days[cursor], record.finalized, record.isSuccess {
            current += 1
            cursor = cursor.adding(days: -1, calendar: calendar)
        }
        let todayOnTrack = days[today]?.isSuccess ?? true
        return StreakSummary(current: current, longest: longest(days: days, calendar: calendar), todayOnTrack: todayOnTrack)
    }

    static func longest(days: [DayKey: DayRecord], calendar: Calendar) -> Int {
        let successes = days.values.filter { $0.finalized && $0.isSuccess }.map(\.day).sorted()
        var best = 0
        var run = 0
        var previous: DayKey?
        for day in successes {
            run = (previous.map { $0.adding(days: 1, calendar: calendar) == day } ?? false) ? run + 1 : 1
            best = max(best, run)
            previous = day
        }
        return best
    }
}
