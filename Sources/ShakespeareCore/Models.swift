import Foundation

/// Everything Shakespeare stores about one calendar day. Only counters:
/// no characters, no key sequences, no timestamps finer than an hour.
public struct DayRecord: Codable, Equatable {
    public var keys = 0
    /// Letter and space presses (the WPM-eligible keys).
    public var textKeys = 0
    public var bestWPM = 0.0
    /// Key presses per hour of day, index 0...23.
    public var hours = [Int](repeating: 0, count: 24)
    /// Key presses per app name. Empty unless the user opted in to app tracking.
    public var apps: [String: Int] = [:]

    public init() {}
}

public struct StatsData: Codable, Equatable {
    public var version = 1
    /// Keyed by local calendar day, "yyyy-MM-dd".
    public var days: [String: DayRecord] = [:]

    public init() {}
}

extension StatsData {
    public static let maxDays = 20_000
    static let maxCount = 1_000_000_000
    /// Faster than any human types; also bounds what an event flood could record.
    static let maxWPM = 400.0
    static let maxAppsPerDay = 200
    static let maxAppNameLength = 100

    /// Repairs or drops anything implausible, so a hand-edited or damaged stats file
    /// can never crash the app (wrong-length arrays, negative or huge numbers) or
    /// bloat memory.
    public func sanitized() -> StatsData {
        var clean = StatsData()
        clean.version = version
        for key in days.keys.sorted().suffix(Self.maxDays) where Self.isValidDayKey(key) {
            guard let day = days[key] else { continue }
            var fixed = DayRecord()
            fixed.keys = Self.clamp(day.keys)
            fixed.textKeys = Self.clamp(day.textKeys)
            fixed.bestWPM = day.bestWPM.isFinite ? min(max(day.bestWPM, 0), Self.maxWPM) : 0
            for hour in 0..<24 where hour < day.hours.count { fixed.hours[hour] = Self.clamp(day.hours[hour]) }
            for (name, count) in day.apps.sorted(by: { $0.key < $1.key }) {
                guard let cleaned = Self.cleanAppName(name) else { continue }
                if fixed.apps[cleaned] == nil, fixed.apps.count >= Self.maxAppsPerDay { continue }
                fixed.apps[cleaned] = Self.clamp(fixed.apps[cleaned, default: 0] + Self.clamp(count))
            }
            clean.days[key] = fixed
        }
        return clean
    }

    /// Strips control, bidirectional-override and other invisible characters (e.g. U+202E, which
    /// can visually reorder neighbouring text), trims whitespace and limits the length.
    /// Returns nil if nothing printable is left.
    public static func cleanAppName(_ name: String) -> String? {
        let blocked: Set<Unicode.GeneralCategory> =
            [.control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .surrogate, .unassigned]
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: name.unicodeScalars.filter { !blocked.contains($0.properties.generalCategory) })
        let cleaned = String(String(scalars).prefix(maxAppNameLength)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func clamp(_ value: Int) -> Int { min(max(value, 0), maxCount) }

    /// "yyyy-MM-dd" with a plausible month and day.
    static func isValidDayKey(_ key: String) -> Bool {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let month = Int(parts[1]), let day = Int(parts[2]) else { return false }
        return (1...12).contains(month) && (1...31).contains(day)
    }
}

public struct DayCount: Equatable {
    public let date: Date
    public let keys: Int
}

public struct AppCount: Equatable {
    public let name: String
    public let keys: Int
}

public struct RangeSummary: Equatable {
    public var keys = 0
    public var textKeys = 0
    public var bestWPM = 0.0
    public var busiestHour: Int?
    public var topApps: [AppCount] = []
}
