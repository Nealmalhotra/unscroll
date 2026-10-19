import Foundation
import Testing
@testable import UnscrollKit

@Suite("DayKey & WeekID")
struct TimeKeyTests {
    @Test func dayKeyRoundTripsThroughString() throws {
        let key = DayKey(year: 2026, month: 3, day: 7)
        #expect(key.description == "2026-03-07")
        #expect(DayKey(string: "2026-03-07") == key)
    }

    @Test(arguments: ["", "2026-13-01", "2026-01", "abc", "2026-01-32"])
    func dayKeyRejectsMalformed(_ raw: String) {
        #expect(DayKey(string: raw) == nil)
    }

    @Test func dayKeyAddsDaysAcrossMonths() {
        let key = DayKey(year: 2026, month: 1, day: 31)
        #expect(key.adding(days: 1, calendar: Fixtures.calendar) == DayKey(year: 2026, month: 2, day: 1))
        #expect(key.adding(days: -31, calendar: Fixtures.calendar) == DayKey(year: 2025, month: 12, day: 31))
    }

    @Test func dayKeyOrdering() {
        #expect(DayKey(year: 2025, month: 12, day: 31) < DayKey(year: 2026, month: 1, day: 1))
    }

    @Test func dayKeyCodableAsString() throws {
        let data = try JSONEncoder().encode([Fixtures.day])
        #expect(String(data: data, encoding: .utf8) == "[\"2026-10-19\"]")
        #expect(try JSONDecoder().decode([DayKey].self, from: data) == [Fixtures.day])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode([DayKey].self, from: Data("[\"nope\"]".utf8)) }
    }

    @Test func weekIDFormatsISOWeek() {
        let week = WeekID(Fixtures.date(hour: 12))
        #expect(week.description == "2026-W43")
    }

    @Test func weekProgressIsClamped() {
        let week = WeekID(year: 2026, week: 43)
        let utc = TimeZone(identifier: "UTC")!
        let start = week.interval(timeZone: utc).start
        #expect(week.progress(at: start.addingTimeInterval(-10), timeZone: utc) == 0)
        #expect(week.progress(at: start.addingTimeInterval(3.5 * 86_400), timeZone: utc) == 0.5)
        #expect(week.progress(at: start.addingTimeInterval(30 * 86_400), timeZone: utc) == 1)
    }

    @Test func weekMembershipIsHalfOpenAndDSTSafe() {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        // 2026-W13 contains the spring-forward switch (29 March 2026): 167 hours long.
        let dst = WeekID(year: 2026, week: 13)
        #expect(dst.interval(timeZone: berlin).duration == 167 * 3600)
        let end = dst.interval(timeZone: berlin).end
        #expect(!dst.contains(end, timeZone: berlin))
        #expect(dst.contains(end.addingTimeInterval(-1), timeZone: berlin))
    }

    @Test func planBuildsSession() {
        let plan = SessionPlan(name: "Bed", startMinute: 22 * 60, endMinute: 6 * 60, beastMode: true)
        let session = plan.session(startingAt: Fixtures.date(hour: 22))
        #expect(session.planID == plan.id)
        #expect(session.plannedMinutes == 8 * 60)
        #expect(session.beastMode)
    }
}
