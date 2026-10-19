import Foundation

/// Text shown on Apple's shield screen. Kept platform-free so it can be unit tested;
/// the ShieldConfiguration extension maps it onto `ShieldConfiguration`.
public struct ShieldCopy: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var primaryButton: String
    public var secondaryButton: String?
}

/// What the secondary shield button should do. Shared by the configuration and action extensions.
public enum ShieldContext: Equatable, Sendable {
    case session(ActiveSession)
    case intentionOpens(Intention, remaining: Int)
    case intentionTimeUp(Intention)
    case unknown

    public var copy: ShieldCopy {
        switch self {
        case let .session(session) where session.beastMode:
            ShieldCopy(
                title: "Beast Mode 🔥",
                subtitle: "\"\(session.name)\" is locked until \(Self.time(session.endsAt)). You've got this.",
                primaryButton: "Back to life",
                secondaryButton: nil
            )
        case let .session(session):
            ShieldCopy(
                title: "You're in a Present Session",
                subtitle: "\"\(session.name)\" ends at \(Self.time(session.endsAt)). Finish it to earn your XP.",
                primaryButton: "Stay present",
                secondaryButton: "End session (lose XP)"
            )
        case let .intentionOpens(intention, remaining) where remaining > 0:
            ShieldCopy(
                title: "Is this intentional?",
                subtitle: "\(intention.name): \(remaining) open\(remaining == 1 ? "" : "s") left today, \(intention.minutesPerOpen) min each.",
                primaryButton: "Never mind",
                secondaryButton: "Open \(intention.name)"
            )
        case let .intentionOpens(intention, _):
            ShieldCopy(
                title: "You're out of opens",
                subtitle: "You planned to open \(intention.name) \(intention.dailyOpens ?? 0) times today. Opening again breaks your intention.",
                primaryButton: "Keep my word",
                secondaryButton: "Open anyway"
            )
        case let .intentionTimeUp(intention):
            ShieldCopy(
                title: "Time's up for today",
                subtitle: "You've used your \(TimeFormat.minutes(intention.dailyMinutes ?? 0)) for \(intention.name). Continuing breaks your intention.",
                primaryButton: "Keep my word",
                secondaryButton: "Ignore limit today"
            )
        case .unknown:
            ShieldCopy(title: "Be present", subtitle: "This app is blocked by Unscroll.", primaryButton: "Close", secondaryButton: nil)
        }
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
