import Foundation

/// What the home/lock screen widget shows. Computed from the saved state without writing anything,
/// so the widget stays correct after midnight even if the app hasn't been opened yet.
public struct WidgetSummary: Codable, Equatable, Sendable {
    public var streak: Int
    public var longestStreak: Int
    public var todayOnTrack: Bool
    public var screenMinutes: Int
    public var goalMinutes: Int
    public var weeklyXP: Int
    public var level: Int

    public init(streak: Int, longestStreak: Int, todayOnTrack: Bool, screenMinutes: Int, goalMinutes: Int, weeklyXP: Int, level: Int) {
        self.streak = streak
        self.longestStreak = longestStreak
        self.todayOnTrack = todayOnTrack
        self.screenMinutes = screenMinutes
        self.goalMinutes = goalMinutes
        self.weeklyXP = weeklyXP
        self.level = level
    }

    public static let placeholder = WidgetSummary(streak: 7, longestStreak: 12, todayOnTrack: true, screenMinutes: 45, goalMinutes: 120, weeklyXP: 340, level: 4)

    public var goalRemainingFraction: Double {
        guard goalMinutes > 0 else { return 0 }
        return max(0, 1 - Double(screenMinutes) / Double(goalMinutes))
    }
}

extension AppState {
    public func widgetSummary(now: Date = Date(), calendar: Calendar = .current) -> WidgetSummary {
        let today = DayKey(now, calendar: calendar)
        // Close out past days virtually (pure; nothing is saved) so a new day counts immediately.
        let settled = finalizingDays(before: today, at: now, calendar: calendar)
        let streak = settled.streak(today: today, calendar: calendar)
        let record = settled.days[today]
        return WidgetSummary(
            streak: streak.current,
            longestStreak: streak.longest,
            todayOnTrack: streak.todayOnTrack,
            screenMinutes: record?.screenMinutesAtLeast ?? 0,
            goalMinutes: record?.goalMinutes ?? profile.dailyGoalMinutes,
            weeklyXP: settled.weeklyXP(WeekID(now)),
            level: Level.level(forXP: settled.lifetimeXP)
        )
    }
}
