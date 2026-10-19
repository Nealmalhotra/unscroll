import Foundation
@testable import UnscrollKit

enum Fixtures {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    static let day = DayKey(year: 2026, month: 10, day: 19)

    /// A date on `day` at the given hour (UTC).
    static func date(_ day: DayKey = day, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    static func session(start: Date, minutes: Int, beast: Bool = false, planID: UUID? = nil) -> ActiveSession {
        ActiveSession(
            planID: planID, name: "Focus", startedAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(minutes * 60)),
            mode: .blockSelected, beastMode: beast, selectionData: Data()
        )
    }

    static func successfulDay(_ day: DayKey, goal: Int = 120) -> DayRecord {
        DayRecord(day: day, goalMinutes: goal, screenMinutesAtLeast: 30, finalized: true)
    }

    static func tempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("unscroll-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
