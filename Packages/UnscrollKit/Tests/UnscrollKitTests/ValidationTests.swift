import Foundation
import Testing
@testable import UnscrollKit

@Suite("Validation")
struct ValidationTests {
    @Test func intentionNeedsALimit() {
        let intention = Intention(name: "Instagram")
        #expect(!intention.isValid)
        #expect(intention.validationErrors.contains("Set a time limit, an opens limit, or both."))
    }

    @Test func intentionRangeChecks() {
        #expect(!Intention(name: "", dailyMinutes: 10).isValid)
        #expect(!Intention(name: "X", dailyMinutes: 0).isValid)
        #expect(!Intention(name: "X", dailyOpens: 500).isValid)
        #expect(!Intention(name: "X", dailyOpens: 3, minutesPerOpen: 0).isValid)
        #expect(Intention(name: "X", dailyMinutes: 30, dailyOpens: 3).isValid)
    }

    @Test func intentionSummary() {
        #expect(Intention(name: "X", dailyMinutes: 90, dailyOpens: 3).summary == "1h 30m · 3 opens")
        #expect(Intention(name: "X", dailyMinutes: 60).summary == "1h a day")
        #expect(Intention(name: "X", dailyOpens: 2).summary == "2 opens a day")
        #expect(Intention(name: "X").summary == "No limit")
    }

    @Test func planDurationCrossesMidnight() {
        let plan = SessionPlan(name: "Bedtime", startMinute: 22 * 60, endMinute: 7 * 60)
        #expect(plan.durationMinutes == 9 * 60)
        #expect(plan.isValid)
    }

    @Test func planValidation() {
        #expect(!SessionPlan(name: "Short", startMinute: 600, endMinute: 610).isValid)
        #expect(!SessionPlan(name: "No days", startMinute: 600, endMinute: 700, weekdays: []).isValid)
        #expect(!SessionPlan(name: "Bad day", startMinute: 600, endMinute: 700, weekdays: [9]).isValid)
        #expect(!SessionPlan(name: " ", startMinute: 600, endMinute: 700).isValid)
        #expect(!SessionPlan(name: "Bad time", startMinute: 2000, endMinute: 700).isValid)
    }

    @Test func clockLabels() {
        #expect(SessionPlan.clockLabel(0) == "12:00 AM")
        #expect(SessionPlan.clockLabel(13 * 60 + 5) == "1:05 PM")
        #expect(SessionPlan(name: "M", startMinute: 7 * 60, endMinute: 9 * 60).timeLabel == "7:00 AM – 9:00 AM")
    }

    @Test func rewardAndPartnerValidation() {
        #expect(!Reward(title: "", cost: 10).validationErrors.isEmpty)
        #expect(!Reward(title: "Book", cost: 0).validationErrors.isEmpty)
        #expect(Reward(title: "Book", cost: 10).validationErrors.isEmpty)
        #expect(!AccountabilityPartner(name: "", phone: "123").validationErrors.isEmpty)
        #expect(AccountabilityPartner(name: "Mom", phone: "+1 (555) 123-4567").validationErrors.isEmpty)
    }

    @Test func timeFormat() {
        #expect(TimeFormat.minutes(45) == "45m")
        #expect(TimeFormat.minutes(120) == "2h")
        #expect(TimeFormat.minutes(135) == "2h 15m")
    }

    @Test func profileWith() {
        let profile = Profile().with(\.handle, "neo")
        #expect(profile.handle == "neo")
        #expect(Motivation.allCases.allSatisfy { !$0.title.isEmpty && !$0.symbol.isEmpty })
    }
}
