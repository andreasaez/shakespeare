import Foundation

/// Aggregates keypresses into per-day counters and answers stats queries.
/// Not thread-safe: use from a single actor/thread.
public final class StatsEngine {
    public static let streakThreshold = 50

    public private(set) var data: StatsData
    public private(set) var isDirty = false
    let calendar: Calendar
    private var wpm = WPMTracker()

    /// Day keys use the Gregorian calendar in the user's time zone, whatever calendar the
    /// system is set to. A Japanese-era or Buddhist-year calendar would otherwise produce
    /// keys like "0008-10-09" that sort wrongly and look invalid.
    public static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Events dated outside these years (a wrong or reset system clock) are ignored.
    static let validYears = 2000...9999

    public init(data: StatsData = StatsData(), calendar: Calendar = StatsEngine.defaultCalendar) {
        self.data = data.sanitized()
        self.calendar = calendar
    }

    // MARK: - Recording

    /// - Parameter app: front-most app name, or nil when app tracking is off.
    public func record(_ kind: KeyKind, at date: Date, app: String? = nil) {
        guard kind != .ignored else { return }
        guard Self.validYears.contains(calendar.component(.year, from: date)) else { return }
        let key = dayKey(date)
        var day = data.days[key] ?? DayRecord()
        day.keys += 1
        day.hours[calendar.component(.hour, from: date)] += 1
        if let app, let name = StatsData.cleanAppName(app),
           day.apps[name] != nil || day.apps.count < StatsData.maxAppsPerDay {
            day.apps[name, default: 0] += 1
        }
        if kind.countsTowardWPM {
            day.textKeys += 1
            let current = wpm.record(at: date.timeIntervalSinceReferenceDate)
            day.bestWPM = max(day.bestWPM, min(current, StatsData.maxWPM))
        }
        data.days[key] = day
        isDirty = true
    }

    public func markSaved() { isDirty = false }

    /// Removes every stored app name, keeping all other stats.
    public func clearApps() {
        for key in data.days.keys { data.days[key]?.apps = [:] }
        isDirty = true
    }

    /// Removes one app's name from every day, keeping all key counts. Returns whether anything changed.
    @discardableResult
    public func removeApp(named name: String) -> Bool {
        var changed = false
        for key in data.days.keys where data.days[key]?.apps.removeValue(forKey: name) != nil { changed = true }
        if changed { isDirty = true }
        return changed
    }

    public func reset() {
        data = StatsData()
        wpm = WPMTracker()
        isDirty = true
    }

    // MARK: - Queries

    public func keys(on date: Date) -> Int { data.days[dayKey(date)]?.keys ?? 0 }

    /// The last `n` days ending at `now`, oldest first.
    public func lastDays(_ n: Int, endingAt now: Date) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(n, 0)).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return DayCount(date: day, keys: keys(on: day))
        }
    }

    /// Consecutive days with at least `threshold` keys. A quiet *today* does not
    /// break the streak, since the day isn't over yet.
    public func streak(endingAt now: Date, threshold: Int = streakThreshold) -> Int {
        var day = calendar.startOfDay(for: now)
        if keys(on: day) < threshold {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while keys(on: day) >= threshold, count <= data.days.count {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// The day with the most key presses ever (earliest wins a tie), or nil with no data.
    public func busiestDay() -> DayCount? {
        var best: (key: String, keys: Int)?
        for key in data.days.keys.sorted() {
            let keys = data.days[key]?.keys ?? 0
            if keys > (best?.keys ?? 0) { best = (key, keys) }
        }
        guard let best, let date = date(fromDayKey: best.key) else { return nil }
        return DayCount(date: date, keys: best.keys)
    }

    /// Summary of the last `days` days, or of all recorded history when nil.
    public func summary(lastDays days: Int?, endingAt now: Date, appLimit: Int = 5) -> RangeSummary {
        let keysInRange: [String]
        if let days {
            keysInRange = lastDays(days, endingAt: now).map { dayKey($0.date) }
        } else {
            keysInRange = Array(data.days.keys)
        }
        var result = RangeSummary()
        var hours = [Int](repeating: 0, count: 24)
        var apps: [String: Int] = [:]
        for key in keysInRange {
            guard let day = data.days[key] else { continue }
            result.keys += day.keys
            result.textKeys += day.textKeys
            result.bestWPM = max(result.bestWPM, day.bestWPM)
            for hour in 0..<24 { hours[hour] += day.hours[hour] }
            for (name, count) in day.apps { apps[name, default: 0] += count }
        }
        if let peak = hours.max(), peak > 0 { result.busiestHour = hours.firstIndex(of: peak) }
        result.topApps = apps
            .map { AppCount(name: $0.key, keys: $0.value) }
            .sorted { ($0.keys, $1.name) > ($1.keys, $0.name) }
            .prefix(appLimit)
            .map { $0 }
        return result
    }

    // MARK: - Helpers

    func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
