import Foundation
import Testing
@testable import UnscrollKit

@Suite("State reducer")
struct ReducerTests {
    let cal = Fixtures.calendar

    @Test func ensuringDaySeedsGoalAndIntentions() {
        let intention = Intention(name: "TikTok", dailyMinutes: 20)
        let state = AppState(profile: Profile(dailyGoalMinutes: 90), intentions: [intention]).ensuringDay(Fixtures.day)
        #expect(state.days[Fixtures.day]?.goalMinutes == 90)
        #expect(state.days[Fixtures.day]?.trackedIntentions == [intention.id])
        // Idempotent: doesn't overwrite an existing record.
        let changed = state.with(\.profile, Profile(dailyGoalMinutes: 10)).ensuringDay(Fixtures.day)
        #expect(changed.days[Fixtures.day]?.goalMinutes == 90)
    }

    @Test func usageMilestonesOnlyIncrease() {
        let at = Fixtures.date(hour: 15)
        let state = AppState().applying([
            ExtensionEvent(at: at, kind: .usageMilestone(minutes: 60)),
            ExtensionEvent(at: at.addingTimeInterval(1), kind: .usageMilestone(minutes: 30)),
        ], calendar: cal)
        #expect(state.days[Fixtures.day]?.screenMinutesAtLeast == 60)
    }

    @Test func eventsAreIdempotent() {
        let event = ExtensionEvent(at: Fixtures.date(hour: 9), kind: .intentionOpened(intentionID: UUID()))
        let once = AppState().applying([event], calendar: cal)
        let twice = once.applying([event], calendar: cal)
        #expect(once == twice)
    }

    @Test func goalExceededMarksDay() {
        let state = AppState(profile: Profile(dailyGoalMinutes: 60))
            .applying([ExtensionEvent(at: Fixtures.date(hour: 20), kind: .goalExceeded)], calendar: cal)
        #expect(state.days[Fixtures.day]?.goalExceeded == true)
        #expect(state.days[Fixtures.day]?.screenMinutesAtLeast == 60)
    }

    @Test func opensBeyondLimitBreakIntention() {
        let intention = Intention(name: "IG", dailyOpens: 2)
        let events = (0..<3).map { ExtensionEvent(at: Fixtures.date(hour: 10, minute: $0), kind: .intentionOpened(intentionID: intention.id)) }
        let two = AppState(intentions: [intention]).applying(Array(events.prefix(2)), calendar: cal)
        #expect(two.days[Fixtures.day]?.opens[intention.id] == 2)
        #expect(two.days[Fixtures.day]?.brokenIntentions.isEmpty == true)
        let three = two.applying([events[2]], calendar: cal)
        #expect(three.days[Fixtures.day]?.brokenIntentions == [intention.id])
    }

    @Test func limitReachedBreaksIntention() {
        let id = UUID()
        let state = AppState().applying([ExtensionEvent(at: Fixtures.date(hour: 11), kind: .intentionLimitReached(intentionID: id))], calendar: cal)
        #expect(state.days[Fixtures.day]?.brokenIntentions == [id])
    }

    @Test func scheduledSessionLifecycleAwardsXP() {
        let plan = SessionPlan(name: "Morning", startMinute: 7 * 60, endMinute: 8 * 60)
        let start = Fixtures.date(hour: 7)
        let session = plan.session(startingAt: start)
        let started = AppState(plans: [plan]).applying([ExtensionEvent(at: start, kind: .scheduledSessionStarted(session: session))], calendar: cal)
        #expect(started.activeSession == session)
        #expect(started.activeSession?.plannedMinutes == 60)
        let ended = started.applying([ExtensionEvent(at: Fixtures.date(hour: 8), kind: .scheduledSessionEnded(planID: plan.id))], calendar: cal)
        #expect(ended.activeSession == nil)
        #expect(ended.sessionHistory.first?.outcome == .completed)
        #expect(ended.xpLedger.contains { $0.reason == .sessionCompleted && $0.amount == 60 })
    }

    @Test func scheduledEventsIgnoredWhenNotApplicable() {
        let manual = Fixtures.session(start: Fixtures.date(hour: 7), minutes: 30)
        let plan = SessionPlan(name: "P", startMinute: 420, endMinute: 480)
        let busy = AppState(activeSession: manual).applying([ExtensionEvent(at: Fixtures.date(hour: 7), kind: .scheduledSessionStarted(session: plan.session(startingAt: Fixtures.date(hour: 7))))], calendar: cal)
        #expect(busy.activeSession == manual)
        let other = AppState(activeSession: Fixtures.session(start: Fixtures.date(hour: 7), minutes: 30))
        let ended = other.applying([ExtensionEvent(at: Fixtures.date(hour: 7, minute: 10), kind: .scheduledSessionEnded(planID: UUID()))], calendar: cal)
        #expect(ended.activeSession != nil)
    }

    @Test func breakingFromShieldRespectsBeastMode() {
        let normal = Fixtures.session(start: Fixtures.date(hour: 9), minutes: 60)
        let beast = Fixtures.session(start: Fixtures.date(hour: 9), minutes: 60, beast: true)
        let at = Fixtures.date(hour: 9, minute: 20)
        let brokenNormal = AppState(activeSession: normal).applying([ExtensionEvent(at: at, kind: .sessionBrokenFromShield(sessionID: normal.id))], calendar: cal)
        #expect(brokenNormal.activeSession == nil)
        #expect(brokenNormal.sessionHistory.first?.outcome == .broken)
        #expect(brokenNormal.lifetimeXP == 0)
        let brokenBeast = AppState(activeSession: beast).applying([ExtensionEvent(at: at, kind: .sessionBrokenFromShield(sessionID: beast.id))], calendar: cal)
        #expect(brokenBeast.activeSession == beast)
    }

    @Test func startingSessionValidates() {
        let start = Fixtures.date(hour: 9)
        #expect(AppState().startingSession(Fixtures.session(start: start, minutes: 5)) == .failure(.tooShort))
        #expect(AppState().startingSession(Fixtures.session(start: start, minutes: 800)) == .failure(.tooLong))
        let running = AppState(activeSession: Fixtures.session(start: start, minutes: 30))
        #expect(running.startingSession(Fixtures.session(start: start, minutes: 30)) == .failure(.alreadyRunning))
        #expect((try? AppState().startingSession(Fixtures.session(start: start, minutes: 30)).get())?.activeSession != nil)
    }

    @Test func breakingSessionManually() throws {
        let start = Fixtures.date(hour: 9)
        #expect(AppState().breakingSession(at: start) == .failure(.noSession))
        let beast = AppState(activeSession: Fixtures.session(start: start, minutes: 30, beast: true))
        #expect(beast.breakingSession(at: start.addingTimeInterval(60), calendar: cal) == .failure(.beastModeLocked))
        // Once time is up even Beast Mode completes normally.
        let done = try beast.breakingSession(at: start.addingTimeInterval(31 * 60), calendar: cal).get()
        #expect(done.sessionHistory.first?.outcome == .completed)
        #expect(done.sessionHistory.first?.xpAwarded == 45)
    }

    @Test func reconcilingCompletesExpiredSession() {
        let start = Fixtures.date(hour: 9)
        let state = AppState(activeSession: Fixtures.session(start: start, minutes: 30))
        #expect(state.reconcilingSession(at: start.addingTimeInterval(600), calendar: cal) == state)
        let reconciled = state.reconcilingSession(at: start.addingTimeInterval(7200), calendar: cal)
        #expect(reconciled.activeSession == nil)
        #expect(reconciled.sessionHistory.first?.actualMinutes == 30)
    }

    @Test func endingWithoutSessionIsNoOp() {
        let result = AppState().endingSession(at: Date(), outcome: .completed)
        #expect(result.record == nil)
    }

    @Test func tipReadOncePerDay() {
        let at = Fixtures.date(hour: 8)
        let once = AppState().markingTipRead(on: Fixtures.day, at: at, calendar: cal)
        let twice = once.markingTipRead(on: Fixtures.day, at: at, calendar: cal)
        #expect(once == twice)
        #expect(once.xpLedger.contains { $0.reason == .tipRead })
    }

    @Test func redeemingSpendsPointsNotXP() throws {
        let reward = Reward(title: "Coffee", cost: 100)
        let poor = AppState(xpLedger: [XPEntry(at: Date(), amount: 50, reason: .goalMet, note: "")])
        #expect(poor.redeeming(reward, at: Date()) == .failure(.insufficientPoints(needed: 100, available: 50)))
        let rich = poor.with(\.xpLedger, [XPEntry(at: Date(), amount: 150, reason: .goalMet, note: "")])
        let after = try rich.redeeming(reward, at: Date()).get()
        #expect(after.pointsBalance == 50)
        #expect(after.lifetimeXP == 150)
        #expect(RedemptionError.insufficientPoints(needed: 100, available: 50).errorDescription == "You need 50 more points for this reward.")
    }

    @Test func sessionErrorsHaveMessages() {
        let all: [AppState.SessionError] = [.alreadyRunning, .tooShort, .tooLong, .beastModeLocked, .noSession]
        #expect(all.allSatisfy { !($0.errorDescription ?? "").isEmpty })
    }
}
