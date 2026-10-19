import Foundation
import Testing
@testable import UnscrollKit

@Suite("XP, levels & streaks")
struct XPAndStreakTests {
    @Test func sessionXP() {
        #expect(XPRules.sessionXP(minutes: 30, beastMode: false, outcome: .completed) == 30)
        #expect(XPRules.sessionXP(minutes: 30, beastMode: true, outcome: .completed) == 45)
        #expect(XPRules.sessionXP(minutes: 30, beastMode: true, outcome: .broken) == 0)
        #expect(XPRules.sessionXP(minutes: 0, beastMode: false, outcome: .completed) == 0)
    }

    @Test func streakBonusIsCapped() {
        #expect(XPRules.streakBonus(streak: 0) == 0)
        #expect(XPRules.streakBonus(streak: 3) == 15)
        #expect(XPRules.streakBonus(streak: 100) == XPRules.streakBonusCap)
    }

    @Test func levels() {
        #expect(Level.level(forXP: 0) == 1)
        #expect(Level.level(forXP: 99) == 1)
        #expect(Level.level(forXP: 100) == 2)
        #expect(Level.level(forXP: 400) == 3)
        #expect(Level.progress(forXP: 250) == 0.5)
    }

    @Test func streakCountsConsecutiveDaysEndingYesterday() {
        let cal = Fixtures.calendar
        let today = Fixtures.day
        let days = (1...3).map { today.adding(days: -$0, calendar: cal) }
            .reduce(into: [DayKey: DayRecord]()) { $0[$1] = Fixtures.successfulDay($1) }
        let summary = StreakCalculator.summary(days: days, today: today, calendar: cal)
        #expect(summary.current == 3)
        #expect(summary.longest == 3)
        #expect(summary.todayOnTrack)
    }

    @Test func streakBreaksOnFailureOrGap() {
        let cal = Fixtures.calendar
        let today = Fixtures.day
        var failed = Fixtures.successfulDay(today.adding(days: -2, calendar: cal))
        failed.goalExceeded = true
        let days: [DayKey: DayRecord] = [
            today.adding(days: -1, calendar: cal): Fixtures.successfulDay(today.adding(days: -1, calendar: cal)),
            failed.day: failed,
            today.adding(days: -3, calendar: cal): Fixtures.successfulDay(today.adding(days: -3, calendar: cal)),
            today.adding(days: -4, calendar: cal): Fixtures.successfulDay(today.adding(days: -4, calendar: cal)),
            today: DayRecord(day: today, goalMinutes: 60, brokenIntentions: [UUID()]),
        ]
        let summary = StreakCalculator.summary(days: days, today: today, calendar: cal)
        #expect(summary.current == 1)
        #expect(summary.longest == 2)
        #expect(!summary.todayOnTrack)
    }

    @Test func unfinalizedDaysDontCount() {
        let cal = Fixtures.calendar
        let yesterday = Fixtures.day.adding(days: -1, calendar: cal)
        let days = [yesterday: DayRecord(day: yesterday, goalMinutes: 60)]
        #expect(StreakCalculator.summary(days: days, today: Fixtures.day, calendar: cal).current == 0)
    }

    @Test func dayRecordDerivedValues() {
        let kept = UUID(), broken = UUID()
        let record = DayRecord(day: Fixtures.day, goalMinutes: 100, screenMinutesAtLeast: 25, brokenIntentions: [broken], trackedIntentions: [kept, broken])
        #expect(record.keptIntentions == [kept])
        #expect(!record.isSuccess)
        #expect(record.goalRemainingFraction == 0.75)
        #expect(DayRecord(day: Fixtures.day, goalMinutes: 0).goalRemainingFraction == 0)
    }
}
