import Foundation

/// A self-chosen limit on an app or category: a daily time allowance and/or a number of opens.
/// Exceeding it never hard-locks the user; it costs the day's credit for the intention.
public struct Intention: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    /// Encoded `FamilyActivitySelection` (opaque to the core so it stays platform-independent).
    public var selectionData: Data
    public var dailyMinutes: Int?
    public var dailyOpens: Int?
    /// Minutes an app stays unlocked after an intentional "open".
    public var minutesPerOpen: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        selectionData: Data = Data(),
        dailyMinutes: Int? = nil,
        dailyOpens: Int? = nil,
        minutesPerOpen: Int = 5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.selectionData = selectionData
        self.dailyMinutes = dailyMinutes
        self.dailyOpens = dailyOpens
        self.minutesPerOpen = minutesPerOpen
        self.createdAt = createdAt
    }

    public static let minutesRange = 1...720
    public static let opensRange = 1...200

    /// Validation errors suitable for showing directly in the UI.
    public var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Give your intention a name.") }
        if dailyMinutes == nil && dailyOpens == nil { errors.append("Set a time limit, an opens limit, or both.") }
        if let minutes = dailyMinutes, !Self.minutesRange.contains(minutes) { errors.append("Time limit must be 1–720 minutes.") }
        if let opens = dailyOpens, !Self.opensRange.contains(opens) { errors.append("Opens limit must be 1–200.") }
        if !(1...60).contains(minutesPerOpen) { errors.append("Minutes per open must be 1–60.") }
        return errors
    }

    public var isValid: Bool { validationErrors.isEmpty }

    public var summary: String {
        switch (dailyMinutes, dailyOpens) {
        case let (minutes?, opens?): "\(TimeFormat.minutes(minutes)) · \(opens) opens"
        case let (minutes?, nil): "\(TimeFormat.minutes(minutes)) a day"
        case let (nil, opens?): "\(opens) opens a day"
        case (nil, nil): "No limit"
        }
    }
}

public enum TimeFormat {
    /// "1h 30m", "45m", "2h".
    public static func minutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(rest)m"
        }
    }
}
