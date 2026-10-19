import Foundation

public struct Quest: Identifiable, Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case completeSession, sessionMinutes, beastSession, morningSession, readTip, underGoal, keepIntentions, fewOpens
    }

    public let kind: Kind
    public var id: String { kind.rawValue }
    public var title: String
    public var symbol: String
    public var target: Int
    public var xp: Int
    /// Quests that can only be judged once the day is over.
    public var resolvesAtDayEnd: Bool
}

public struct QuestProgress: Equatable, Sendable {
    public var current: Int
    public var target: Int
    public var isComplete: Bool
    public var fraction: Double { target == 0 ? 1 : min(1, Double(current) / Double(target)) }
}

public enum QuestEngine {
    public static let dailyCount = 3

    public static let catalog: [Quest] = [
        Quest(kind: .completeSession, title: "Complete a Present Session", symbol: "timer", target: 1, xp: 20, resolvesAtDayEnd: false),
        Quest(kind: .sessionMinutes, title: "Spend 60 minutes in sessions", symbol: "hourglass", target: 60, xp: 30, resolvesAtDayEnd: false),
        Quest(kind: .beastSession, title: "Finish a Beast Mode session", symbol: "flame.fill", target: 1, xp: 40, resolvesAtDayEnd: false),
        Quest(kind: .morningSession, title: "Start a session before 10 AM", symbol: "sunrise.fill", target: 1, xp: 25, resolvesAtDayEnd: false),
        Quest(kind: .readTip, title: "Read today's tip", symbol: "lightbulb.fill", target: 1, xp: 10, resolvesAtDayEnd: false),
        Quest(kind: .underGoal, title: "Use under 75% of your goal", symbol: "chart.line.downtrend.xyaxis", target: 1, xp: 40, resolvesAtDayEnd: true),
        Quest(kind: .keepIntentions, title: "Keep every intention", symbol: "checkmark.shield.fill", target: 1, xp: 30, resolvesAtDayEnd: true),
        Quest(kind: .fewOpens, title: "Open limited apps 3 times or less", symbol: "hand.raised.fill", target: 3, xp: 25, resolvesAtDayEnd: true),
    ]

    /// Three quests per day, deterministic for the day. Always includes one session quest.
    public static func quests(for day: DayKey) -> [Quest] {
        var rng = SeededRandom(seed: "quests-\(day)")
        let sessionQuests = catalog.filter { [.completeSession, .sessionMinutes, .beastSession, .morningSession].contains($0.kind) }
        let anchor = sessionQuests.randomElement(using: &rng) ?? catalog[0]
        let others = catalog.filter { $0.kind != anchor.kind }.shuffled(using: &rng).prefix(dailyCount - 1)
        return [anchor] + others
    }

    public static func progress(
        of quest: Quest,
        record: DayRecord?,
        sessions: [SessionRecord],
        dayIsOver: Bool,
        calendar: Calendar = .current
    ) -> QuestProgress {
        let completed = sessions.filter { $0.outcome == .completed }
        func result(_ current: Int, done: Bool) -> QuestProgress {
            QuestProgress(current: current, target: quest.target, isComplete: done)
        }
        switch quest.kind {
        case .completeSession:
            return result(completed.count, done: completed.count >= quest.target)
        case .sessionMinutes:
            let minutes = completed.reduce(0) { $0 + $1.actualMinutes }
            return result(minutes, done: minutes >= quest.target)
        case .beastSession:
            let count = completed.filter(\.beastMode).count
            return result(count, done: count >= quest.target)
        case .morningSession:
            let count = completed.filter { calendar.component(.hour, from: $0.startedAt) < 10 }.count
            return result(count, done: count >= quest.target)
        case .readTip:
            let read = record?.tipRead == true
            return result(read ? 1 : 0, done: read)
        case .underGoal:
            let under = record.map { !$0.goalExceeded && Double($0.screenMinutesAtLeast) < Double($0.goalMinutes) * 0.75 } ?? false
            return result(under ? 1 : 0, done: dayIsOver && under)
        case .keepIntentions:
            let kept = record.map { $0.brokenIntentions.isEmpty } ?? true
            return result(kept ? 1 : 0, done: dayIsOver && kept)
        case .fewOpens:
            let opens = record?.opens.values.reduce(0, +) ?? 0
            return result(opens, done: dayIsOver && opens <= quest.target)
        }
    }
}

extension AppState {
    public func questProgress(on day: DayKey, dayIsOver: Bool = false, calendar: Calendar = .current) -> [(Quest, QuestProgress)] {
        let record = days[day]
        let sessions = sessions(on: day, calendar: calendar)
        return QuestEngine.quests(for: day).map { quest in
            let progress = QuestEngine.progress(of: quest, record: record, sessions: sessions, dayIsOver: dayIsOver, calendar: calendar)
            let alreadyDone = record?.completedQuests.contains(quest.id) == true
            return (quest, alreadyDone ? QuestProgress(current: progress.target, target: progress.target, isComplete: true) : progress)
        }
    }

    /// Awards XP for newly completed quests (each quest pays out once per day).
    func completingQuests(on day: DayKey, at date: Date, includeDayEnd: Bool, calendar: Calendar) -> AppState {
        let seeded = ensuringDay(day)
        let done = seeded.days[day]?.completedQuests ?? []
        let newlyDone = seeded.questProgress(on: day, dayIsOver: includeDayEnd, calendar: calendar)
            .filter { quest, progress in progress.isComplete && !done.contains(quest.id) }
            .map(\.0)
        return newlyDone.reduce(seeded) { state, quest in
            state.updatingDay(day) { $0.with(\.completedQuests, $0.completedQuests.union([quest.id])) }
                .awarding(quest.xp, .quest, quest.title, at: date)
        }
    }
}
