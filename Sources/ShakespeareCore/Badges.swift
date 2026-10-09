import Foundation

/// A literary milestone, measured in words typed within a calendar month.
/// Progress resets on the 1st; the collection (how many months you earned
/// each badge) never does.
public struct Badge: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// Words needed in one month (5 letter/space keys = 1 word).
    public let words: Int
    public let blurb: String

    public init(id: String, name: String, words: Int, blurb: String) {
        self.id = id; self.name = name; self.words = words; self.blurb = blurb
    }
}

public struct BadgeStatus: Identifiable, Equatable {
    public let badge: Badge
    /// The day this month's total crossed the threshold; nil if not yet this month.
    public let earnedThisMonthOn: Date?
    /// Months in which you earned this badge, including the current one.
    public let timesEarned: Int
    /// The first day you ever earned it.
    public let firstEarned: Date?

    public init(badge: Badge, earnedThisMonthOn: Date?, timesEarned: Int, firstEarned: Date?) {
        self.badge = badge; self.earnedThisMonthOn = earnedThisMonthOn
        self.timesEarned = timesEarned; self.firstEarned = firstEarned
    }

    public var id: String { badge.id }
    public var isEarnedThisMonth: Bool { earnedThisMonthOn != nil }
    /// In your collection: earned in any month, ever.
    public var isCollected: Bool { timesEarned > 0 }
}

public enum BadgeCatalog {
    /// Word counts for the plays are approximate, from commonly cited figures.
    public static let all: [Badge] = [
        Badge(id: "couplet", name: "Couplet", words: 20, blurb: "Two lines, one rhyme."),
        Badge(id: "sonnet", name: "Sonnet", words: 120, blurb: "Fourteen lines and a volta."),
        Badge(id: "soliloquy", name: "Soliloquy", words: 260, blurb: "To type, or not to type."),
        Badge(id: "scene", name: "Scene", words: 2_000, blurb: "Exit, pursued by a bear."),
        Badge(id: "act", name: "Act", words: 6_000, blurb: "Curtain up on act one."),
        Badge(id: "comedy", name: "Comedy of Errors", words: 14_000, blurb: "Shakespeare's shortest play."),
        Badge(id: "macbeth", name: "Macbeth", words: 18_000, blurb: "The Scottish play. We said it."),
        Badge(id: "hamlet", name: "Hamlet", words: 30_000, blurb: "Shakespeare's longest play."),
        Badge(id: "tenhamlets", name: "Ten Hamlets", words: 300_000, blurb: "Something is rotten in your keyboard."),
        Badge(id: "complete", name: "Complete Works", words: 884_000, blurb: "The whole First Folio, in one month."),
    ]
}

extension StatsEngine {
    /// Lifetime words typed (used for the "Hamlets typed" fun fact).
    public var totalWords: Int {
        data.days.values.reduce(0) { $0 + $1.textKeys } / Int(WPMTracker.keysPerWord)
    }

    /// Words typed in the calendar month containing `date`.
    public func monthWords(containing date: Date) -> Int {
        let month = monthKey(date)
        let keys = data.days.filter { $0.key.hasPrefix(month) }.reduce(0) { $0 + $1.value.textKeys }
        return keys / Int(WPMTracker.keysPerWord)
    }

    /// Every badge, with this month's progress and the lifetime collection,
    /// all derived from the per-day counters. Nothing extra is stored.
    public func badgeStatuses(now: Date) -> [BadgeStatus] {
        let current = monthKey(now)
        var timesEarned: [String: Int] = [:]
        var firstEarned: [String: Date] = [:]
        var earnedThisMonth: [String: Date] = [:]

        var month = ""
        var cumulativeKeys = 0
        var nextIndex = 0
        for key in data.days.keys.sorted() {  // "yyyy-MM-dd" sorts chronologically
            let thisMonth = String(key.prefix(7))
            if thisMonth != month {
                month = thisMonth
                cumulativeKeys = 0
                nextIndex = 0
            }
            cumulativeKeys += data.days[key]?.textKeys ?? 0
            let words = cumulativeKeys / Int(WPMTracker.keysPerWord)
            while nextIndex < BadgeCatalog.all.count, words >= BadgeCatalog.all[nextIndex].words {
                let id = BadgeCatalog.all[nextIndex].id
                timesEarned[id, default: 0] += 1
                if let day = date(fromDayKey: key) {
                    if firstEarned[id] == nil { firstEarned[id] = day }
                    if month == current { earnedThisMonth[id] = day }
                }
                nextIndex += 1
            }
        }
        return BadgeCatalog.all.map {
            BadgeStatus(badge: $0, earnedThisMonthOn: earnedThisMonth[$0.id],
                        timesEarned: timesEarned[$0.id] ?? 0, firstEarned: firstEarned[$0.id])
        }
    }

    /// The next badge to earn this month and progress (0...1) toward it,
    /// or nil once every badge is earned this month.
    public func nextBadge(now: Date) -> (badge: Badge, progress: Double, words: Int)? {
        let words = monthWords(containing: now)
        guard let badge = BadgeCatalog.all.first(where: { words < $0.words }) else { return nil }
        let previous = BadgeCatalog.all.last(where: { $0.words <= words })?.words ?? 0
        let span = Double(badge.words - previous)
        return (badge, span > 0 ? Double(words - previous) / span : 0, words)
    }

    func monthKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
