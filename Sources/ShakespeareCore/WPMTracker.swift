import Foundation

/// Sliding 60-second words-per-minute window (5 keys = 1 word).
///
/// Because the window is always a full minute, a short burst is averaged
/// against idle time and can only under-report, never inflate the number.
/// Timestamps live in memory only and are never persisted.
public struct WPMTracker {
    public static let windowSeconds: TimeInterval = 60
    public static let keysPerWord = 5.0

    /// 6,000 keys a minute is 1,200 WPM, far beyond human. The cap bounds memory and
    /// CPU if something floods the event stream with synthetic key presses.
    static let maxStamps = 6_000

    private var stamps: [TimeInterval] = []

    public init() {}

    /// Records a letter/space keypress and returns the WPM over the last minute.
    @discardableResult
    public mutating func record(at time: TimeInterval) -> Double {
        if let last = stamps.last, time < last { stamps.removeAll() }  // clock moved backwards
        stamps.append(time)
        if stamps.count > Self.maxStamps { stamps.removeFirst(stamps.count - Self.maxStamps) }
        let cutoff = time - Self.windowSeconds
        if let firstValid = stamps.firstIndex(where: { $0 > cutoff }), firstValid > 0 {
            stamps.removeFirst(firstValid)
        }
        return Double(stamps.count) / Self.keysPerWord
    }
}
