import Foundation

public enum BlockMode: String, Codable, CaseIterable, Sendable {
    /// Block only the selected apps/categories.
    case blockSelected
    /// Block everything except the selected apps (plus system essentials).
    case allowSelected

    public var title: String {
        switch self {
        case .blockSelected: "Block selected apps"
        case .allowSelected: "Block all except selected"
        }
    }
}

/// A recurring Present Session (e.g. "Morning", "Bedtime", "Deep work").
public struct SessionPlan: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    /// Minutes after midnight.
    public var startMinute: Int
    public var endMinute: Int
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    public var weekdays: Set<Int>
    public var mode: BlockMode
    public var beastMode: Bool
    public var selectionData: Data
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        startMinute: Int,
        endMinute: Int,
        weekdays: Set<Int> = Set(1...7),
        mode: BlockMode = .blockSelected,
        beastMode: Bool = false,
        selectionData: Data = Data(),
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
        self.mode = mode
        self.beastMode = beastMode
        self.selectionData = selectionData
        self.enabled = enabled
    }

    /// Duration in minutes, handling plans that cross midnight.
    public var durationMinutes: Int {
        let raw = endMinute - startMinute
        return raw > 0 ? raw : raw + 24 * 60
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Give your session a name.") }
        if weekdays.isEmpty { errors.append("Pick at least one day.") }
        if !weekdays.isSubset(of: Set(1...7)) { errors.append("Invalid weekday.") }
        if !(0..<1440).contains(startMinute) || !(0..<1440).contains(endMinute) { errors.append("Invalid time.") }
        // Apple's DeviceActivity requires schedules of at least 15 minutes.
        if durationMinutes < SessionRules.minimumMinutes { errors.append("Sessions must be at least 15 minutes.") }
        return errors
    }

    public var isValid: Bool { validationErrors.isEmpty }

    /// Builds the session a plan produces when its interval starts at `date`.
    public func session(startingAt date: Date) -> ActiveSession {
        ActiveSession(
            planID: id, name: name, startedAt: date,
            endsAt: date.addingTimeInterval(TimeInterval(durationMinutes * 60)),
            mode: mode, beastMode: beastMode, selectionData: selectionData
        )
    }

    public static func clockLabel(_ minute: Int) -> String {
        let hour = minute / 60
        let mins = minute % 60
        let suffix = hour < 12 ? "AM" : "PM"
        let display = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", display, mins, suffix)
    }

    public var timeLabel: String { "\(Self.clockLabel(startMinute)) – \(Self.clockLabel(endMinute))" }
}

public enum SessionRules {
    /// Apple allows about 20 monitored activities; daily tracking and relocks need some of them.
    public static let maximumPlans = 10
    public static let minimumMinutes = 15
    public static let maximumMinutes = 12 * 60
}

/// The session currently blocking apps, whether started manually or by a schedule.
public struct ActiveSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var planID: UUID?
    public var name: String
    public var startedAt: Date
    public var endsAt: Date
    public var mode: BlockMode
    public var beastMode: Bool
    public var selectionData: Data
    public var groupID: String?

    public init(
        id: UUID = UUID(),
        planID: UUID? = nil,
        name: String,
        startedAt: Date,
        endsAt: Date,
        mode: BlockMode,
        beastMode: Bool,
        selectionData: Data,
        groupID: String? = nil
    ) {
        self.id = id
        self.planID = planID
        self.name = name
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.mode = mode
        self.beastMode = beastMode
        self.selectionData = selectionData
        self.groupID = groupID
    }

    public var plannedMinutes: Int { max(0, Int(endsAt.timeIntervalSince(startedAt) / 60)) }

    public func remaining(at now: Date) -> TimeInterval { max(0, endsAt.timeIntervalSince(now)) }

    public func progress(at now: Date) -> Double {
        let total = endsAt.timeIntervalSince(startedAt)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / total))
    }

    public func isFinished(at now: Date) -> Bool { now >= endsAt }
}

public enum SessionOutcome: String, Codable, Sendable {
    case completed
    case broken
}

public struct SessionRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var startedAt: Date
    public var endedAt: Date
    public var plannedMinutes: Int
    public var beastMode: Bool
    public var outcome: SessionOutcome
    public var xpAwarded: Int

    public init(
        id: UUID,
        name: String,
        startedAt: Date,
        endedAt: Date,
        plannedMinutes: Int,
        beastMode: Bool,
        outcome: SessionOutcome,
        xpAwarded: Int
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedMinutes = plannedMinutes
        self.beastMode = beastMode
        self.outcome = outcome
        self.xpAwarded = xpAwarded
    }

    public var actualMinutes: Int { max(0, Int(endedAt.timeIntervalSince(startedAt) / 60)) }
}
