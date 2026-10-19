import Foundation
import Testing
@testable import UnscrollKit

@Suite("Quests & leagues")
struct QuestLeagueTests {
    let cal = Fixtures.calendar
    let sessionKinds: Set<Quest.Kind> = [.completeSession, .sessionMinutes, .beastSession, .morningSession]

    @Test func dailyQuestsAreDeterministicAndIncludeASessionQuest() {
        for offset in 0..<30 {
            let day = Fixtures.day.adding(days: offset, calendar: cal)
            let quests = QuestEngine.quests(for: day)
            #expect(quests == QuestEngine.quests(for: day))
            #expect(quests.count == QuestEngine.dailyCount)
            #expect(Set(quests.map(\.kind)).count == quests.count)
            #expect(sessionKinds.contains(quests[0].kind))
        }
    }

    func progress(_ kind: Quest.Kind, record: DayRecord? = nil, sessions: [SessionRecord] = [], dayIsOver: Bool = false) -> QuestProgress {
        let quest = QuestEngine.catalog.first { $0.kind == kind }!
        return QuestEngine.progress(of: quest, record: record, sessions: sessions, dayIsOver: dayIsOver, calendar: cal)
    }

    func record(minutes: Int, start: Date, beast: Bool = false, outcome: SessionOutcome = .completed) -> SessionRecord {
        SessionRecord(id: UUID(), name: "S", startedAt: start, endedAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
                      plannedMinutes: minutes, beastMode: beast, outcome: outcome, xpAwarded: 0)
    }

    @Test func sessionQuests() {
        let morning = record(minutes: 40, start: Fixtures.date(hour: 8))
        let evening = record(minutes: 30, start: Fixtures.date(hour: 19), beast: true)
        let broken = record(minutes: 100, start: Fixtures.date(hour: 12), outcome: .broken)
        #expect(progress(.completeSession, sessions: [broken]).isComplete == false)
        #expect(progress(.completeSession, sessions: [morning]).isComplete)
        #expect(progress(.sessionMinutes, sessions: [morning, broken]).current == 40)
        #expect(progress(.sessionMinutes, sessions: [morning, evening]).isComplete)
        #expect(progress(.beastSession, sessions: [morning]).isComplete == false)
        #expect(progress(.beastSession, sessions: [evening]).isComplete)
        #expect(progress(.morningSession, sessions: [evening]).isComplete == false)
        #expect(progress(.morningSession, sessions: [morning]).isComplete)
    }

    @Test func dayEndQuestsOnlyCompleteWhenDayIsOver() {
        let good = DayRecord(day: Fixtures.day, goalMinutes: 100, screenMinutesAtLeast: 50, opens: [UUID(): 2], tipRead: true)
        #expect(progress(.readTip, record: good).isComplete)
        #expect(progress(.underGoal, record: good).isComplete == false)
        #expect(progress(.underGoal, record: good, dayIsOver: true).isComplete)
        #expect(progress(.keepIntentions, record: good, dayIsOver: true).isComplete)
        #expect(progress(.fewOpens, record: good, dayIsOver: true).isComplete)
        let bad = DayRecord(day: Fixtures.day, goalMinutes: 100, screenMinutesAtLeast: 90, brokenIntentions: [UUID()], opens: [UUID(): 9])
        #expect(progress(.underGoal, record: bad, dayIsOver: true).isComplete == false)
        #expect(progress(.keepIntentions, record: bad, dayIsOver: true).isComplete == false)
        #expect(progress(.fewOpens, record: bad, dayIsOver: true).isComplete == false)
        #expect(progress(.sessionMinutes).fraction == 0)
    }

    @Test func questsPayOutOnce() {
        let day = Fixtures.day
        let quests = QuestEngine.quests(for: day)
        // Satisfy whatever session quest was chosen by completing a long beast session in the morning.
        let session = Fixtures.session(start: Fixtures.date(hour: 8), minutes: 90, beast: true)
        let ended = AppState(activeSession: session).endingSession(at: session.endsAt, outcome: .completed, calendar: cal).state
        let questXP = ended.xpLedger.filter { $0.reason == .quest }
        #expect(questXP.contains { $0.note == quests[0].title })
        let again = ended.completingQuests(on: day, at: session.endsAt, includeDayEnd: false, calendar: cal)
        #expect(again.xpLedger.filter { $0.reason == .quest }.count == questXP.count)
        #expect(again.questProgress(on: day, calendar: cal).first?.1.isComplete == true)
    }

    @Test func tiers() {
        #expect(Tier.bronze.promoted == .silver)
        #expect(Tier.present.promoted == .present)
        #expect(Tier.bronze.demoted == .bronze)
        #expect(Tier.gold.demoted == .silver)
        #expect(Tier.allCases.allSatisfy { !$0.symbol.isEmpty && !$0.title.isEmpty })
    }

    @Test func zones() {
        #expect(LeagueEngine.zone(rank: 1, tier: .gold) == .promote)
        #expect(LeagueEngine.zone(rank: 10, tier: .gold) == .promote)
        #expect(LeagueEngine.zone(rank: 11, tier: .gold) == .stay)
        #expect(LeagueEngine.zone(rank: 26, tier: .gold) == .demote)
        #expect(LeagueEngine.zone(rank: 30, tier: .bronze) == .stay)
        #expect(LeagueEngine.zone(rank: 1, tier: .present) == .stay)
        #expect(LeagueEngine.zone(rank: 12, tier: .gold, cohortSize: 12) == .stay)
        #expect(LeagueEngine.resolve(rank: 1, tier: .gold) == .platinum)
        #expect(LeagueEngine.resolve(rank: 30, tier: .gold) == .silver)
        #expect(LeagueEngine.resolve(rank: 15, tier: .gold) == .gold)
    }

    @Test func simulatedStandingsAreStableAndRanked() {
        let week = WeekID(year: 2026, week: 43)
        let a = LeagueEngine.simulatedStandings(week: week, tier: .silver, myHandle: "me", myXP: 500, progress: 0.5)
        let b = LeagueEngine.simulatedStandings(week: week, tier: .silver, myHandle: "me", myXP: 500, progress: 0.5)
        #expect(a == b)
        #expect(a.count == LeagueEngine.cohortSize)
        #expect(a.map(\.rank) == Array(1...30))
        #expect(a.filter(\.isMe).count == 1)
        #expect(zip(a, a.dropFirst()).allSatisfy { $0.xp >= $1.xp })
        let start = LeagueEngine.simulatedStandings(week: week, tier: .silver, myHandle: "", myXP: 0, progress: 0)
        #expect(start.first?.isMe == true)
        #expect(start.first { $0.isMe }?.handle == "you")
    }

    @Test func rollingLeaguePromotesWinners() {
        let week = WeekID(year: 2026, week: 42)
        let next = WeekID(year: 2026, week: 43)
        let inWeek = week.interval().start.addingTimeInterval(3600)
        let state = AppState(xpLedger: [XPEntry(at: inWeek, amount: 100_000, reason: .goalMet, note: "")])
        let started = state.rollingLeague(to: week)
        #expect(started.league.currentWeek == week)
        #expect(started.rollingLeague(to: week) == started)
        let rolled = started.rollingLeague(to: next)
        #expect(rolled.league.tier == .silver)
        #expect(rolled.league.lastResult == WeekResult(week: week, rank: 1, from: .bronze, to: .silver))
    }
}
