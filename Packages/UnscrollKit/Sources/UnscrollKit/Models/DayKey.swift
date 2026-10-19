import Foundation

/// A calendar day identifier ("yyyy-MM-dd") that is stable across processes and time zones changes
/// within a single day. Used as a dictionary key for per-day records.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Parses "yyyy-MM-dd". Returns nil for malformed input.
    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func startDate(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, calendar: Calendar = .current) -> DayKey {
        let date = calendar.date(byAdding: .day, value: days, to: startDate(calendar: calendar)) ?? startDate(calendar: calendar)
        return DayKey(date, calendar: calendar)
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // Encode as a plain string so JSON stays readable and usable as an object key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let key = DayKey(string: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid day key: \(raw)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// ISO-8601 week identifier, e.g. "2026-W43". Leaderboards reset weekly.
public struct WeekID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let week: Int

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    public init(_ date: Date) {
        let calendar = Calendar.iso8601Week
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        self.init(year: parts.yearForWeekOfYear ?? 1970, week: parts.weekOfYear ?? 1)
    }

    public var description: String { String(format: "%04d-W%02d", year, week) }

    /// Start (Monday 00:00) and end of this week in the given time zone.
    public func interval(timeZone: TimeZone = .current) -> DateInterval {
        var calendar = Calendar.iso8601Week
        calendar.timeZone = timeZone
        let start = calendar.date(from: DateComponents(weekOfYear: week, yearForWeekOfYear: year)) ?? Date(timeIntervalSince1970: 0)
        // Add a calendar week rather than 7×24h so DST weeks (167 or 169 hours) are exact.
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
        return DateInterval(start: start, end: end)
    }

    /// Half-open membership: next Monday 00:00 belongs to the next week.
    public func contains(_ date: Date, timeZone: TimeZone = .current) -> Bool {
        let range = interval(timeZone: timeZone)
        return range.start <= date && date < range.end
    }

    /// Fraction of the week elapsed at `date`, clamped to 0...1.
    public func progress(at date: Date, timeZone: TimeZone = .current) -> Double {
        let range = interval(timeZone: timeZone)
        let elapsed = date.timeIntervalSince(range.start) / range.duration
        return min(1, max(0, elapsed))
    }
}

extension Calendar {
    static var iso8601Week: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }
}
