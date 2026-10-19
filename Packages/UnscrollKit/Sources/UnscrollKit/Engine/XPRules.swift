import Foundation

/// All XP numbers in one place so balancing is a one-file change.
public enum XPRules {
    public static let perSessionMinute = 1
    public static let beastModeMultiplier = 1.5
    public static let goalMet = 50
    public static let intentionKept = 10
    public static let streakBonusPerDay = 5
    public static let streakBonusCap = 50
    public static let tipRead = 5

    public static func sessionXP(minutes: Int, beastMode: Bool, outcome: SessionOutcome) -> Int {
        guard outcome == .completed, minutes > 0 else { return 0 }
        let base = Double(minutes * perSessionMinute)
        return Int((beastMode ? base * beastModeMultiplier : base).rounded())
    }

    public static func streakBonus(streak: Int) -> Int {
        min(streakBonusCap, max(0, streak) * streakBonusPerDay)
    }
}

/// Levels grow quadratically so early levels come quickly.
public enum Level {
    public static func xpRequired(forLevel level: Int) -> Int {
        let n = max(0, level - 1)
        return 100 * n * n
    }

    public static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp { level += 1 }
        return level
    }

    /// Progress (0...1) through the current level.
    public static func progress(forXP xp: Int) -> Double {
        let current = level(forXP: xp)
        let floor = xpRequired(forLevel: current)
        let ceiling = xpRequired(forLevel: current + 1)
        return Double(xp - floor) / Double(max(1, ceiling - floor))
    }
}
