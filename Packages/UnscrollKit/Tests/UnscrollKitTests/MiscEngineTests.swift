import Foundation
import Testing
@testable import UnscrollKit

@Suite("Projection, quiz, tips, shield copy")
struct MiscEngineTests {
    @Test func lifetimeProjection() {
        let projection = LifetimeProjection(dailyHours: 6, age: 20)
        #expect(projection.yearsOnPhone == 15)
        #expect(projection.yearsReclaimed == 7.5)
        #expect(projection.daysPerYear == 91.25)
        #expect(LifetimeProjection(dailyHours: 30, age: 100).yearsOnPhone == 0)
        #expect(LifetimeProjection(dailyHours: -2, age: 20).yearsOnPhone == 0)
    }

    @Test(arguments: [(1.5, 45), (3.0, 90), (9.0, 240), (0.2, 30)])
    func recommendedGoal(hours: Double, expected: Int) {
        #expect(OnboardingQuiz.recommendedGoalMinutes(dailyHours: hours) == expected)
    }

    @Test func habitScore() {
        #expect(OnboardingQuiz.habitScore(answers: ["hours": 9, "morning": 3, "lost": 3]) == 100)
        #expect(OnboardingQuiz.habitScore(answers: ["hours": 0, "morning": 0, "lost": 0]) == 0)
        #expect(OnboardingQuiz.all.allSatisfy { !$0.options.isEmpty })
    }

    @Test func tipOfTheDayIsStable() {
        #expect(Tips.tip(for: Fixtures.day) == Tips.tip(for: Fixtures.day))
        #expect(!Tips.articles.isEmpty)
        #expect(Set(Tips.all.map(\.id)).count == Tips.all.count)
    }

    @Test func seededRandomIsDeterministic() {
        var a = SeededRandom(seed: "x")
        var b = SeededRandom(seed: "x")
        var c = SeededRandom(seed: "y")
        let first = a.next()
        #expect(first == b.next())
        #expect(first != c.next())
    }

    @Test func shieldCopy() {
        let session = Fixtures.session(start: Date(), minutes: 30)
        #expect(ShieldContext.session(session).copy.secondaryButton == "End session (lose XP)")
        let beast = Fixtures.session(start: Date(), minutes: 30, beast: true)
        #expect(ShieldContext.session(beast).copy.secondaryButton == nil)
        let intention = Intention(name: "TikTok", dailyMinutes: 30, dailyOpens: 3)
        #expect(ShieldContext.intentionOpens(intention, remaining: 1).copy.subtitle.contains("1 open left"))
        #expect(ShieldContext.intentionOpens(intention, remaining: 2).copy.subtitle.contains("2 opens left"))
        #expect(ShieldContext.intentionOpens(intention, remaining: 0).copy.secondaryButton == "Open anyway")
        #expect(ShieldContext.intentionTimeUp(intention).copy.subtitle.contains("30m"))
        #expect(ShieldContext.unknown.copy.secondaryButton == nil)
    }
}
