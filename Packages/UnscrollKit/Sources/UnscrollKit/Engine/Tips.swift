import Foundation

public struct Tip: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public let title: String
    public let body: String
    public let symbol: String
}

public struct Article: Identifiable, Equatable, Sendable {
    public var id: String { title }
    public let topic: String
    public let title: String
    public let minutes: Int
    public let paragraphs: [String]
}

public enum Tips {
    public static let all: [Tip] = [
        Tip(title: "Charge outside the bedroom", body: "Buy a $10 alarm clock and leave your phone in the kitchen overnight. Your first and last hour of the day become yours again.", symbol: "bed.double.fill"),
        Tip(title: "Go grayscale", body: "Color is a reward signal. Turn on Settings › Accessibility › Display › Color Filters › Grayscale and apps instantly feel less exciting.", symbol: "circle.lefthalf.filled"),
        Tip(title: "Move the slot machines", body: "Take social apps off your home screen and put them in a folder on the last page. One extra swipe breaks autopilot.", symbol: "square.grid.3x3.fill"),
        Tip(title: "Batch your notifications", body: "Use Scheduled Summary so non-urgent notifications arrive twice a day instead of all day long.", symbol: "bell.badge.fill"),
        Tip(title: "Name the urge", body: "When you reach for your phone, say what you want: \"I'm bored\", \"I'm anxious\". Naming the feeling weakens the reflex.", symbol: "text.bubble.fill"),
        Tip(title: "One-tab rule", body: "Before opening an app, decide what you're there to do. Do that one thing, then close it.", symbol: "1.circle.fill"),
        Tip(title: "Phone-free meals", body: "Put phones face down in the middle of the table. First one to pick theirs up does the dishes.", symbol: "fork.knife"),
        Tip(title: "Replace, don't just remove", body: "Keep a book, a sketchpad or a puzzle where you usually scroll. Boredom needs somewhere to go.", symbol: "book.fill"),
        Tip(title: "The 20-minute walk", body: "A short walk without your phone resets attention better than any app. Try it after lunch.", symbol: "figure.walk"),
        Tip(title: "Log out of the web versions", body: "Friction works both ways. Signing out of social sites on your laptop stops the switch-device loophole.", symbol: "rectangle.portrait.and.arrow.right"),
        Tip(title: "Schedule your scrolling", body: "Give yourself an allowed 20-minute window. Knowing it's coming makes it easier to wait.", symbol: "calendar.badge.clock"),
        Tip(title: "Turn off autoplay", body: "Autoplay is what turns one video into forty. Disable it in each app's settings.", symbol: "play.slash.fill"),
        Tip(title: "Tell someone your goal", body: "People who share goals with a friend are far more likely to stick with them. Add an accountability partner.", symbol: "person.2.fill"),
        Tip(title: "Single-task with sessions", body: "Start a Present Session before deep work. Even 25 minutes of uninterrupted focus adds up.", symbol: "timer"),
    ]

    public static let articles: [Article] = [
        Article(topic: "Focus", title: "Why your attention feels shorter", minutes: 3, paragraphs: [
            "Every notification is a tiny context switch. Researchers who study interruptions find it can take many minutes to get fully back into deep work after one.",
            "The fix isn't willpower; it's environment. Remove the cue (the buzz), add friction (a session or an intention), and keep a replacement activity nearby.",
            "Start small: one 25-minute session a day with everything but essentials blocked. Increase it once it feels easy.",
        ]),
        Article(topic: "Sleep", title: "The last hour before bed", minutes: 3, paragraphs: [
            "Bright, stimulating content late at night delays sleep, and scrolling in bed teaches your brain that bed is for being awake.",
            "Schedule a recurring \"Bedtime\" session that blocks everything except calls and alarms, starting an hour before you want to sleep.",
            "Charge your phone across the room. If you wake up at night, you won't reach for it on reflex.",
        ]),
        Article(topic: "ADHD", title: "Screen time strategies for ADHD brains", minutes: 4, paragraphs: [
            "Infinite feeds are especially sticky for brains that crave novelty. Limits you have to remember don't work as well as limits that enforce themselves.",
            "Use opens-based intentions instead of time limits: a hard count like \"3 opens a day\" is easier to feel than \"45 minutes\".",
            "Pair blocking with body doubling: start a group session with a friend and work alongside each other.",
        ]),
        Article(topic: "Mental health", title: "Comparison is the thief of joy", minutes: 3, paragraphs: [
            "Feeds show everyone's highlight reel. Heavy passive scrolling is consistently associated with lower mood in studies of social media use.",
            "Notice how you feel after each app. Keep the ones that leave you better off, and add intentions to the ones that don't.",
            "Active use (messaging a friend) tends to feel better than passive use (watching strangers). Bias toward the former.",
        ]),
        Article(topic: "Relationships", title: "Being there when you're there", minutes: 3, paragraphs: [
            "Simply having a phone visible on the table can make a conversation feel less close.",
            "Try phone-free meals and a session during time with family or friends. Invite them to a group so you're all in it together.",
            "If a partner or parent is your accountability buddy, frame missed goals as a chance to talk, not a punishment.",
        ]),
    ]

    public static func tip(for day: DayKey) -> Tip {
        var rng = SeededRandom(seed: "tip-\(day)")
        return all.randomElement(using: &rng) ?? all[0]
    }
}
