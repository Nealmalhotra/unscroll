import Foundation

extension AppState {
    /// Closes out every unfinished day before `today`: awards goal/intention/streak XP,
    /// completes end-of-day quests, queues partner alerts and pledge debts for missed days.
    public func finalizingDays(before today: DayKey, at date: Date, calendar: Calendar = .current) -> AppState {
        let backfilled = backfillingMissingDays(before: today, calendar: calendar)
        let pending = backfilled.days.values.filter { !$0.finalized && $0.day < today }.map(\.day).sorted()
        return pending.reduce(backfilled) { state, day in state.finalizing(day, at: date, calendar: calendar) }
            .ensuringDay(today)
    }

    static let backfillLimit = 60

    /// A day with no record had no goal/intention events, i.e. it was a success the app simply
    /// never opened on. Creating those records keeps streaks from breaking on quiet days.
    func backfillingMissingDays(before today: DayKey, calendar: Calendar) -> AppState {
        guard let earliest = days.keys.min(), earliest < today else { return self }
        let floor = max(earliest, today.adding(days: -Self.backfillLimit, calendar: calendar))
        let missing = sequence(first: floor) { $0.adding(days: 1, calendar: calendar) }
            .prefix { $0 < today }
            .filter { days[$0] == nil }
        return missing.reduce(self) { $0.ensuringDay($1) }
    }

    func finalizing(_ day: DayKey, at date: Date, calendar: Calendar) -> AppState {
        guard let record = days[day], !record.finalized else { return self }
        let closedAt = min(date, day.adding(days: 1, calendar: calendar).startDate(calendar: calendar).addingTimeInterval(-1))
        let withQuests = completingQuests(on: day, at: closedAt, includeDayEnd: true, calendar: calendar)
        let finalized = withQuests.updatingDay(day) { $0.with(\.finalized, true) }
        guard record.isSuccess else { return finalized.recordingMiss(day) }
        let streak = finalized.streak(today: day.adding(days: 1, calendar: calendar), calendar: calendar).current
        let kept = record.keptIntentions.count
        return finalized
            .awarding(XPRules.goalMet, .goalMet, "Stayed under your daily goal", at: closedAt)
            .awarding(kept * XPRules.intentionKept, .intentionKept, "Kept \(kept) intention(s)", at: closedAt)
            .awarding(XPRules.streakBonus(streak: streak), .streakBonus, "\(streak)-day streak", at: closedAt)
    }

    func recordingMiss(_ day: DayKey) -> AppState {
        let alerts = partner?.notifyOnMissedGoal == true ? pendingPartnerAlerts + [day] : pendingPartnerAlerts
        let owedPledge = pledge.map { Pledge(amountDollars: $0.amountDollars, causeName: $0.causeName, causeURL: $0.causeURL, owed: $0.owed + $0.amountDollars) }
        return with(\.pendingPartnerAlerts, alerts).with(\.pledge, owedPledge)
    }
}
