import Foundation

/// Playful numbers derived from counters. Nothing here is stored.
public enum FunFacts {
    /// Approximate vertical travel of one key press on a Mac keyboard.
    public static let keyTravelMillimetres = 1.0
    /// Hamlet runs to roughly 30,000 words.
    public static let hamletWords = 30_000.0

    public static func travelMetres(keys: Int) -> Double {
        Double(keys) * keyTravelMillimetres / 1000
    }

    public static func hamlets(textKeys: Int) -> Double {
        Double(textKeys) / WPMTracker.keysPerWord / hamletWords
    }

    /// Words on a typical novel page.
    public static let wordsPerPage = 250.0

    public static func novelPages(words: Int) -> Double { Double(words) / wordsPerPage }

    /// "12:00 AM"-style label for an hour 0...23.
    public static func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        return "\(h) \(hour < 12 ? "AM" : "PM")"
    }

    public struct Landmark: Equatable, Sendable {
        public let name: String
        public let metres: Double
    }

    /// The ladder, in ascending distance. Your key travel works up it one landmark at a time.
    /// Heights and lengths are approximate, from commonly cited figures.
    public static let landmarks: [Landmark] = [
        Landmark(name: "the Tower of London", metres: 27),
        Landmark(name: "the Leaning Tower of Pisa", metres: 56),
        Landmark(name: "Big Ben", metres: 96),
        Landmark(name: "the Eiffel Tower", metres: 330),
        Landmark(name: "the Burj Khalifa", metres: 828),
        Landmark(name: "the top of Mount Everest", metres: 8_849),
        Landmark(name: "the bottom of the Mariana Trench", metres: 10_935),
        Landmark(name: "the edge of space", metres: 100_000),
        Landmark(name: "the length of the Great Wall of China", metres: 21_196_000),
    ]

    /// The landmark you're working towards: the first one you haven't yet reached.
    /// Nil once you've passed the last.
    public static func nextLandmark(metres: Double) -> Landmark? {
        landmarks.first { metres < $0.metres }
    }

    /// The Fun facts line about key travel. It stays on one landmark until you reach
    /// 100% of it, then moves to the next.
    public static func travelFact(metres: Double) -> String {
        let travelled = distanceLabel(metres: metres)
        if let next = nextLandmark(metres: metres) {
            let percent = Int(metres / next.metres * 100)  // rounds down: 100% only on arrival
            return "Your keys have travelled \(travelled), \(percent)% of the way to \(next.name)."
        }
        let last = landmarks[landmarks.count - 1]
        return String(format: "Your keys have travelled %@, %.1f× %@.", travelled, metres / last.metres, last.name)
    }

    public static func distanceLabel(metres: Double) -> String {
        if metres >= 100_000 { return "\(Int(metres / 1000).formatted()) km" }
        if metres >= 1000 { return String(format: "%.2f km", metres / 1000) }
        return String(format: "%.1f m", metres)
    }
}
