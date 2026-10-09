import SwiftUI

/// A complete keyboard colourway: case, alphas, modifiers and accent keys,
/// plus the card backdrop and text colours that go with it.
enum Colourway: String, CaseIterable, Identifiable {
    case quarto = "Quarto"
    case elsinore = "Elsinore"
    case falstaff = "Falstaff"
    case juliet = "Juliet"
    case tudorRose = "Tudor Rose"
    case arden = "Arden"
    case venice = "Venice"
    case phosphor = "Phosphor"  // retro CRT
    case synthwave = "Synthwave"  // retro
    var id: String { rawValue }

    struct Palette {
        let caseTop, caseEdge, alpha, alphaSide, mod, modSide, accent, accentSide: Color
        let alphaLegend, modLegend, accentLegend: Color

        init(_ c: UInt32, _ ce: UInt32, _ a: UInt32, _ aS: UInt32, _ m: UInt32, _ mS: UInt32,
             _ x: UInt32, _ xS: UInt32, _ aL: UInt32, _ mL: UInt32, _ xL: UInt32) {
            caseTop = Color(hex: c); caseEdge = Color(hex: ce)
            alpha = Color(hex: a); alphaSide = Color(hex: aS)
            mod = Color(hex: m); modSide = Color(hex: mS)
            accent = Color(hex: x); accentSide = Color(hex: xS)
            alphaLegend = Color(hex: aL); modLegend = Color(hex: mL); accentLegend = Color(hex: xL)
        }
    }

    var palette: Palette {
        switch self {
        //                   case     edge      alpha    side     mod      side     accent   side     legends: a        m        x
        case .quarto:    Palette(0xD9D0BD, 0xB5AA92, 0xFAF5E8, 0xCFC6AE, 0xC4AE8A, 0x9D8B6B, 0x7DC13B, 0x5A9A26, 0x6B5F48, 0x4A3F2A, 0x1E3A0C)
        case .elsinore:  Palette(0x1B2233, 0x0C111C, 0x2B3447, 0x151B29, 0x222A3C, 0x131824, 0x3CC4DC, 0x1C8CA0, 0xA9B4CC, 0x8E9AB5, 0x06303A)
        case .falstaff:  Palette(0x4A3220, 0x2E1C0E, 0xEBDCC0, 0xBFAE8E, 0x7A5238, 0x553723, 0xE98A2D, 0xB5651A, 0x6B5638, 0xF0DDBF, 0x3A1C03)
        case .juliet:    Palette(0xEDEDED, 0xC8C8CA, 0xFFFFFF, 0xCACACA, 0x1E1E20, 0x0B0B0C, 0xD8333F, 0xA01E29, 0x555555, 0xC9C9CC, 0xFFFFFF)
        case .tudorRose: Palette(0x6B1B26, 0x3F0C14, 0xF3E6C8, 0xC4B28A, 0x8E1B2D, 0x5E0F1C, 0xD9A441, 0xA9791E, 0x6B3A2A, 0xF2D9C0, 0x3A2306)
        case .arden:     Palette(0x3E5242, 0x24332A, 0xF0EBD6, 0xC1BBA0, 0x6F8A6E, 0x4B6149, 0xD9A441, 0xA9791E, 0x4A5A44, 0xF0EBD6, 0x3A2306)
        case .venice:    Palette(0xDCE6F4, 0xB0C0D8, 0xFBFDFF, 0xBFCADC, 0x2D4B8E, 0x1C3366, 0xF28A2E, 0xBE5F12, 0x4C5B78, 0xDCE6F4, 0x3A1A02)
        case .phosphor:  Palette(0x0E1A12, 0x040A06, 0x14281B, 0x08120C, 0x0F2016, 0x060F0A, 0x4DFF88, 0x1E9E4C, 0x4DFF88, 0x2BAA5A, 0x03240F)
        case .synthwave: Palette(0x1B0F3F, 0x0B0524, 0x2D1B69, 0x160C3E, 0x3B2488, 0x1E1048, 0xFF4FD8, 0xB82A9A, 0xC9B8FF, 0xE5DBFF, 0x3A0630)
        }
    }

    var isDark: Bool {
        switch self {
        case .elsinore, .falstaff, .tudorRose, .phosphor, .synthwave: true
        default: false
        }
    }

    /// Card / menu background.
    var bg: Color {
        switch self {
        case .quarto: Color(hex: 0xF1EEE4)
        case .elsinore: Color(hex: 0x0F1420)
        case .falstaff: Color(hex: 0x2B1D14)
        case .juliet: Color(hex: 0xF6F4F3)
        case .tudorRose: Color(hex: 0x3A0F18)
        case .arden: Color(hex: 0xE6EBDD)
        case .venice: Color(hex: 0xEEF3FA)
        case .phosphor: Color(hex: 0x050D08)
        case .synthwave: Color(hex: 0x120536)
        }
    }

    var ink: Color {
        switch self {
        case .quarto: Color(hex: 0x2A2A1E)
        case .elsinore: Color(hex: 0xE8EEF8)
        case .falstaff: Color(hex: 0xF5E8D2)
        case .juliet: Color(hex: 0x1A1A1C)
        case .tudorRose: Color(hex: 0xF8E9CF)
        case .arden: Color(hex: 0x1F2E22)
        case .venice: Color(hex: 0x14213D)
        case .phosphor: Color(hex: 0x4DFF88)
        case .synthwave: .white
        }
    }

    /// Text on an alpha key.
    var keyInk: Color {
        switch self {
        case .quarto: Color(hex: 0x2A2A1E)
        case .elsinore: Color(hex: 0xE8EEF8)
        case .falstaff: Color(hex: 0x2B1D14)
        case .juliet: Color(hex: 0x1A1A1C)
        case .tudorRose: Color(hex: 0x3A0F18)
        case .arden: Color(hex: 0x1F2E22)
        case .venice: Color(hex: 0x14213D)
        case .phosphor: Color(hex: 0x4DFF88)
        case .synthwave: .white
        }
    }

    /// Soft colour glows behind the card.
    var bloom: [Color] {
        switch self {
        case .quarto: [Color(hex: 0xB8D89A), Color(hex: 0xE8C9B0)]
        case .elsinore: [Color(hex: 0x1F7A8C), Color(hex: 0x3A3F8F)]
        case .falstaff: [Color(hex: 0xB5651A), Color(hex: 0x7A5238)]
        case .juliet: [Color(hex: 0xF2A1A8), Color(hex: 0xD9D9DE)]
        case .tudorRose: [Color(hex: 0xA3202F), Color(hex: 0xD9A441)]
        case .arden: [Color(hex: 0x9DBE98), Color(hex: 0xE6D18F)]
        case .venice: [Color(hex: 0x9DB8E8), Color(hex: 0xF5C9A0)]
        case .phosphor: [Color(hex: 0x1E9E4C), Color(hex: 0x0B4020)]
        case .synthwave: [Color(hex: 0xFF4FD8), Color(hex: 0x00F0FF)]
        }
    }
}

// MARK: - Card style

enum CardBackdrop: String, CaseIterable, Identifiable {
    case bloom = "Bloom"
    case solid = "Solid"
    case pattern = "Pattern"
    var id: String { rawValue }
}

/// Nine patterns, from Renaissance to retro, tinted by the chosen colourway.
enum CardPattern: String, CaseIterable, Identifiable {
    case manuscript = "Manuscript"
    case damask = "Damask"
    case fleurDeLis = "Fleur-de-lis"
    case sunburst = "Sunburst"
    case starfield = "Starfield"
    case tudorFloor = "Tudor Floor"
    case retroGrid = "Retro Grid"  // retro
    case scanlines = "CRT Scanlines"  // retro
    case halftone = "Halftone"  // retro
    var id: String { rawValue }
}

struct CardStyle: Equatable {
    var colourway: Colourway = .quarto
    var backdrop: CardBackdrop = .bloom
    var pattern: CardPattern = .manuscript
}
