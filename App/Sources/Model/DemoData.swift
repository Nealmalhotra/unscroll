#if DEBUG
import Foundation
import UnscrollKit

/// Seeds a realistic two-week history for Simulator demos and screenshots.
/// Launch with the `-demo` argument. Never compiled into release builds.
enum DemoData {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static func state(now: Date = Date(), calendar: Calendar = .current) -> AppState {
        let today = DayKey(now, calendar: calendar)
        let social = Intention(name: "Social media", dailyMinutes: 45, dailyOpens: 5)
        let video = Intention(name: "Short video", dailyMinutes: 20)
        let profile = Profile(handle: "present_pat", age: 27, dailyGoalMinutes: 150, reportedDailyHours: 5,
                              motivations: [.focus, .sleep], onboardingComplete: true)
        let plans = [
            SessionPlan(name: "Morning routine", startMinute: 7 * 60, endMinute: 8 * 60, weekdays: Set(2...6), mode: .allowSelected),
            SessionPlan(name: "Bedtime", startMinute: 22 * 60, endMinute: 7 * 60, beastMode: true),
        ]
        let base = AppState(profile: profile, intentions: [social, video], plans: plans,
                            partner: AccountabilityPartner(name: "Alex", phone: "5551234567"))
        let history = (1...13).reversed().reduce(base) { state, offset in
            seedDay(state, day: today.adding(days: -offset, calendar: calendar), offset: offset, social: social.id, calendar: calendar)
        }
        let morning = ActiveSession(name: "Morning focus", startedAt: now.addingTimeInterval(-7_200), endsAt: now.addingTimeInterval(-3_600),
                                    mode: .blockSelected, beastMode: false, selectionData: Data())
        let finalized = history.finalizingDays(before: today, at: now, calendar: calendar)
        let withToday = (try? finalized.startingSession(morning).get())?
            .endingSession(at: morning.endsAt, outcome: .completed, calendar: calendar).state ?? finalized
        return withToday
            .applying([
                ExtensionEvent(at: now.addingTimeInterval(-3_600), kind: .usageMilestone(minutes: 75)),
                ExtensionEvent(at: now.addingTimeInterval(-3_000), kind: .intentionOpened(intentionID: social.id)),
                ExtensionEvent(at: now.addingTimeInterval(-2_000), kind: .intentionOpened(intentionID: social.id)),
            ], calendar: calendar)
            .with(\.league, LeagueState(tier: .silver, currentWeek: WeekID(now), lastResult: WeekResult(week: WeekID(now.addingTimeInterval(-7 * 86_400)), rank: 4, from: .bronze, to: .silver)))
    }

    private static func seedDay(_ state: AppState, day: DayKey, offset: Int, social: UUID, calendar: Calendar) -> AppState {
        let start = calendar.date(byAdding: .hour, value: 9, to: day.startDate(calendar: calendar)) ?? day.startDate(calendar: calendar)
        let minutes = [95, 120, 140, 80, 160, 110, 70, 130, 100, 90, 150, 85, 105][offset % 13]
        var events = [ExtensionEvent(at: start.addingTimeInterval(36_000), kind: .usageMilestone(minutes: minutes))]
        if minutes >= 150 { events.append(ExtensionEvent(at: start.addingTimeInterval(36_100), kind: .goalExceeded)) }
        if offset == 6 { events.append(ExtensionEvent(at: start, kind: .intentionLimitReached(intentionID: social))) }
        let session = ActiveSession(name: offset % 3 == 0 ? "Deep work" : "Focus", startedAt: start,
                                    endsAt: start.addingTimeInterval(TimeInterval((30 + offset % 4 * 15) * 60)),
                                    mode: .blockSelected, beastMode: offset % 4 == 0, selectionData: Data())
        let withSession = (try? state.ensuringDay(day).startingSession(session).get())?
            .endingSession(at: session.endsAt, outcome: .completed, calendar: calendar).state ?? state
        return withSession.applying(events, calendar: calendar)
    }
}
#endif
