import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity)
    }

    /// A colour that switches with the macOS appearance.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

// MARK: - Typeface

/// Inter (bundled, SIL OFL) in light weights, so the whole app speaks in one voice.
/// Falls back to the system font if the bundled file isn't present (e.g. `swift run`).
func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    let name: String
    switch weight {
    case .ultraLight: name = "InterVariable-ExtraLight"
    case .thin: name = "InterVariable-Thin"
    case .light: name = "InterVariable-Light"
    case .medium: name = "InterVariable-Medium"
    case .semibold: name = "InterVariable-SemiBold"
    case .bold: name = "InterVariable-Bold"
    default: name = "InterVariable"
    }
    if InterAvailability.isBundled { return .custom(name, size: size) }
    return .system(size: size, weight: weight)
}

private enum InterAvailability {
    static let isBundled = NSFont(name: "InterVariable-Light", size: 12) != nil
}

// MARK: - Menu theme

/// Menu appearance: macOS light/dark by default, or any keyboard colourway.
enum MenuTheme: Hashable, Identifiable {
    case system
    case colourway(Colourway)

    static let all: [MenuTheme] = [.system] + Colourway.allCases.map { .colourway($0) }

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .system: "system"
        case .colourway(let c): c.rawValue
        }
    }

    init?(rawValue: String) {
        if rawValue == "system" { self = .system; return }
        guard let c = Colourway(rawValue: rawValue) else { return nil }
        self = .colourway(c)
    }

    var name: String {
        switch self {
        case .system: "System"
        case .colourway(let c): c.rawValue
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .colourway(let c): c.isDark ? .dark : .light
        }
    }

    var ink: Color {
        switch self {
        case .system: .primary
        case .colourway(let c): c.ink
        }
    }

    var secondary: Color {
        switch self {
        case .system: .secondary
        case .colourway(let c): c.ink.opacity(0.62)
        }
    }

    var hairline: Color {
        switch self {
        case .system: Color.primary.opacity(0.12)
        case .colourway(let c): c.ink.opacity(0.14)
        }
    }

    // Keycaps: a lighter top face over a darker side edge.
    var keyTop: Color {
        switch self {
        case .system: .adaptive(light: 0xFFFFFF, dark: 0x3A3A3F)
        case .colourway(let c): c.palette.alpha
        }
    }

    var keySide: Color {
        switch self {
        case .system: .adaptive(light: 0xD2D2D7, dark: 0x232326)
        case .colourway(let c): c.palette.alphaSide
        }
    }

    var keyInk: Color {
        switch self {
        case .system: .primary
        case .colourway(let c): c.keyInk
        }
    }

    var keySecondary: Color {
        switch self {
        case .system: .secondary
        case .colourway(let c): c.keyInk.opacity(0.58)
        }
    }

    var accentTop: Color {
        switch self {
        case .system: .adaptive(light: 0x1D1D1F, dark: 0xF5F5F7)
        case .colourway(let c): c.palette.accent
        }
    }

    var accentSide: Color {
        switch self {
        case .system: .adaptive(light: 0x6E6E73, dark: 0x8E8E93)
        case .colourway(let c): c.palette.accentSide
        }
    }

    var onAccent: Color {
        switch self {
        case .system: .adaptive(light: 0xFFFFFF, dark: 0x1D1D1F)
        case .colourway(let c): c.palette.accentLegend
        }
    }

    var barTrack: Color {
        switch self {
        case .system: Color.primary.opacity(0.07)
        case .colourway(let c): c.ink.opacity(0.09)
        }
    }

    var barFill: Color { ink.opacity(0.3) }

    @ViewBuilder var background: some View {
        switch self {
        case .system: Color.clear
        case .colourway(let c): c.bg
        }
    }

    /// Dot shown on the Appearance chip.
    var swatch: Color {
        switch self {
        case .system: .adaptive(light: 0x1D1D1F, dark: 0xF5F5F7)
        case .colourway(let c): c.palette.accent
        }
    }
}

// MARK: - Keycap styling

private struct Keycap: ViewModifier {
    let top: Color
    let side: Color
    var radius: CGFloat = 9
    var depth: CGFloat = 3

    func body(content: Content) -> some View {
        content
            .background(top, in: RoundedRectangle(cornerRadius: radius))
            .background(side, in: RoundedRectangle(cornerRadius: radius).offset(y: depth))
            .padding(.bottom, depth)
    }
}

extension View {
    /// Draws the view as a mechanical keycap.
    func keycap(top: Color, side: Color, radius: CGFloat = 9, depth: CGFloat = 3) -> some View {
        modifier(Keycap(top: top, side: side, radius: radius, depth: depth))
    }
}
