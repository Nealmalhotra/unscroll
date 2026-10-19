import Foundation

public struct QuizQuestion: Identifiable, Sendable {
    public let id: String
    public let prompt: String
    public let options: [QuizOption]
}

public struct QuizOption: Identifiable, Hashable, Sendable {
    public var id: String { label }
    public let label: String
    public let value: Double
}

public enum OnboardingQuiz {
    public static let dailyHours = QuizQuestion(id: "hours", prompt: "How much time do you spend on your phone each day?", options: [
        QuizOption(label: "Under 2 hours", value: 1.5),
        QuizOption(label: "2–4 hours", value: 3),
        QuizOption(label: "4–6 hours", value: 5),
        QuizOption(label: "6–8 hours", value: 7),
        QuizOption(label: "8+ hours", value: 9),
    ])

    public static let age = QuizQuestion(id: "age", prompt: "How old are you?", options: [
        QuizOption(label: "Under 18", value: 16),
        QuizOption(label: "18–24", value: 21),
        QuizOption(label: "25–34", value: 30),
        QuizOption(label: "35–44", value: 40),
        QuizOption(label: "45–54", value: 50),
        QuizOption(label: "55+", value: 60),
    ])

    public static let firstThing = QuizQuestion(id: "morning", prompt: "Do you check your phone within 10 minutes of waking up?", options: [
        QuizOption(label: "Always", value: 3),
        QuizOption(label: "Often", value: 2),
        QuizOption(label: "Sometimes", value: 1),
        QuizOption(label: "Never", value: 0),
    ])

    public static let lostTrack = QuizQuestion(id: "lost", prompt: "How often do you lose track of time while scrolling?", options: [
        QuizOption(label: "Every day", value: 3),
        QuizOption(label: "A few times a week", value: 2),
        QuizOption(label: "Rarely", value: 1),
        QuizOption(label: "Never", value: 0),
    ])

    public static let all = [dailyHours, age, firstThing, lostTrack]

    /// Suggests a goal of roughly half the current usage, rounded to 15 minutes, between 30m and 4h.
    public static func recommendedGoalMinutes(dailyHours: Double) -> Int {
        let half = dailyHours * 60 * LifetimeProjection.targetReduction
        let rounded = Int((half / 15).rounded()) * 15
        return min(240, max(30, rounded))
    }

    /// 0–100 "attention score" shown after the quiz, purely for motivation.
    public static func habitScore(answers: [String: Double]) -> Int {
        let hours = answers[dailyHours.id] ?? 3
        let morning = answers[firstThing.id] ?? 1
        let lost = answers[lostTrack.id] ?? 1
        let raw = (hours / 9) * 50 + (morning / 3) * 25 + (lost / 3) * 25
        return Int(min(100, max(0, raw)).rounded())
    }
}
