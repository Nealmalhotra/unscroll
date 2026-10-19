import Foundation

/// Messages that the Screen Time extensions (which run in separate, short-lived processes)
/// leave for the host app. Each is written as its own file so writers never contend.
public struct ExtensionEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var at: Date
    public var kind: Kind

    public init(id: UUID = UUID(), at: Date = Date(), kind: Kind) {
        self.id = id
        self.at = at
        self.kind = kind
    }

    public enum Kind: Codable, Equatable, Sendable {
        /// Total usage of tracked apps passed `minutes` today.
        case usageMilestone(minutes: Int)
        /// Total usage passed the daily goal.
        case goalExceeded
        /// An intention's time allowance was used up.
        case intentionLimitReached(intentionID: UUID)
        /// The user chose to open an intention-limited app from the shield.
        case intentionOpened(intentionID: UUID)
        /// A scheduled session's interval started (extension applied shields).
        /// Carries the session so the app and the extensions agree on its ID.
        case scheduledSessionStarted(session: ActiveSession)
        /// A scheduled session's interval ended (extension removed shields).
        case scheduledSessionEnded(planID: UUID)
        /// The user broke the active session from the shield ("I really need this").
        case sessionBrokenFromShield(sessionID: UUID)
    }
}
