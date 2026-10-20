import Foundation
import Testing
@testable import UnscrollKit

@Suite("Day finalization")
struct FinalizerTests {
    let cal = Fixtures.calendar

    @Test func successfulDayAwardsGoalIntentionAndStreakXP() {
        let intention = Intention(name: "IG", dailyMinutes: 20)
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let before = yesterday.adding(days: -1, calendar: cal)
        let state = AppState(intentions: [intention], days: [before: Fixtures.successfulDay(before)])
            .ensuringDay(yesterday)
            .finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 8), calendar: cal)
        #expect(state.days[yesterday]?.finalized == true)
        #expect(state.days[Fixtures.day] != nil)
        let reasons = state.xpLedger.map(\.reason)
        #expect(reasons.contains(.goalMet))
        #expect(reasons.contains(.intentionKept))
        #expect(state.xpLedger.first { $0.reason == .streakBonus }?.amount == XPRules.streakBonus(streak: 2))
        // XP for a finalized day is timestamped on that day, so it counts for that week.
        #expect(state.xpLedger.allSatisfy { DayKey($0.at, calendar: cal) == yesterday })
    }

    @Test func missedDayQueuesPartnerAlertAndPledge() {
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let missed = DayRecord(day: yesterday, goalMinutes: 60, goalExceeded: true)
        let state = AppState(
            days: [yesterday: missed],
            partner: AccountabilityPartner(name: "Sam", phone: "5551234567"),
            pledge: Pledge(amountDollars: 5, causeName: "Library")
        ).finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 8), calendar: cal)
        #expect(state.pendingPartnerAlerts == [yesterday])
        #expect(state.pledge?.owed == 5)
        #expect(!state.xpLedger.contains { $0.reason == .goalMet })
        #expect(state.clearingPartnerAlerts().pendingPartnerAlerts.isEmpty)
    }

    @Test func finalizingIsIdempotent() {
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let once = AppState().ensuringDay(yesterday).finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 8), calendar: cal)
        let twice = once.finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 9), calendar: cal)
        #expect(once == twice)
    }

    @Test func todayIsNeverFinalized() {
        let state = AppState().ensuringDay(Fixtures.day).finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 23), calendar: cal)
        #expect(state.days[Fixtures.day]?.finalized == false)
    }

    @Test func partnerOptOutSkipsAlert() {
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let state = AppState(
            days: [yesterday: DayRecord(day: yesterday, goalMinutes: 60, goalExceeded: true)],
            partner: AccountabilityPartner(name: "Sam", phone: "5551234567", notifyOnMissedGoal: false)
        ).finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 8), calendar: cal)
        #expect(state.pendingPartnerAlerts.isEmpty)
    }

    @Test func quietDaysWithoutRecordsKeepTheStreak() {
        let threeAgo = Fixtures.day.adding(days: -3, calendar: cal)
        let state = AppState().ensuringDay(threeAgo).finalizingDays(before: Fixtures.day, at: Fixtures.date(hour: 8), calendar: cal)
        #expect((1...3).allSatisfy { state.days[Fixtures.day.adding(days: -$0, calendar: cal)]?.finalized == true })
        #expect(state.streak(today: Fixtures.day, calendar: cal).current == 3)
    }

    @Test func backfillIsBounded() {
        let longAgo = Fixtures.day.adding(days: -400, calendar: cal)
        let state = AppState().ensuringDay(longAgo).backfillingMissingDays(before: Fixtures.day, calendar: cal)
        #expect(state.days.count == AppState.backfillLimit + 1)
    }

    @Test func goalChangeAppliesToToday() {
        let state = AppState().ensuringDay(Fixtures.day).updatingProfile(Profile(dailyGoalMinutes: 45), today: Fixtures.day)
        #expect(state.days[Fixtures.day]?.goalMinutes == 45)
        #expect(state.profile.dailyGoalMinutes == 45)
    }

    @Test func widgetSummaryCountsYesterdayBeforeTheAppFinalizesIt() {
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let twoAgo = Fixtures.day.adding(days: -2, calendar: cal)
        let state = AppState(profile: Profile(dailyGoalMinutes: 100), days: [
            twoAgo: Fixtures.successfulDay(twoAgo),
            yesterday: DayRecord(day: yesterday, goalMinutes: 100, screenMinutesAtLeast: 60),
        ])
        let summary = state.widgetSummary(now: Fixtures.date(hour: 9), calendar: cal)
        #expect(summary.streak == 2)
        #expect(summary.todayOnTrack)
        #expect(summary.goalMinutes == 100)
        #expect(summary.goalRemainingFraction == 1)
        #expect(summary.level >= 1)
        // Pure: the original state is untouched.
        #expect(state.days[yesterday]?.finalized == false)
        #expect(WidgetSummary.placeholder.goalRemainingFraction > 0)
    }
}
