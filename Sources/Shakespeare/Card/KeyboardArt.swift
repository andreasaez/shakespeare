import SwiftUI

/// A 75% mechanical keyboard drawn in code, in any colourway.
/// Decorative only: it does not reflect which keys you actually pressed.
struct KeyboardArt: View {
    let colourway: Colourway
    var legends = true

    private enum Cap { case alpha, mod, accent }
    private struct Key {
        let label: String
        let width: Double
        let cap: Cap
    }

    private static func alphas(_ labels: [String]) -> [Key] { labels.map { Key(label: $0, width: 1, cap: .alpha) } }
    private static func key(_ label: String, _ width: Double = 1, _ cap: Cap = .mod) -> Key {
        Key(label: label, width: width, cap: cap)
    }

    /// Six rows, 16 units wide each.
    private static let rows: [[Key]] = [
        [key("esc", 1, .accent)]
            + (1...12).map { Key(label: "F\($0)", width: 1, cap: (5...9).contains($0) ? .mod : .alpha) }
            + [key("#"), key("del"), key("")],
        alphas(["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="])
            + [key("⌫", 2), key("pgup")],
        [key("tab", 1.5)] + alphas(["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "[", "]"])
            + [Key(label: "\\", width: 1.5, cap: .alpha), key("pgdn")],
        [key("caps", 1.75)] + alphas(["A", "S", "D", "F", "G", "H", "J", "K", "L", ";", "'"])
            + [key("return", 2.25, .accent), key("home")],
        [key("shift", 2.25)] + alphas(["Z", "X", "C", "V", "B", "N", "M", ",", ".", "/"])
            + [key("shift", 1.75), key("↑", 1, .accent), key("end")],
        [key("ctrl", 1.25), key("opt", 1.25), key("cmd", 1.25), Key(label: "", width: 6.25, cap: .alpha),
         key("cmd"), key("fn"), key("ctrl"), key("←", 1, .accent), key("↓", 1, .accent), key("→", 1, .accent)],
    ]

    // Case padding and lip, in key units.
    private static let pad = 0.38
    private static let lip = 0.1
    static let aspectRatio = (16 + 2 * pad) / (6 + 2 * pad + lip)

    var body: some View {
        Canvas { ctx, size in draw(&ctx, size) }
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .accessibilityHidden(true)
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let p = colourway.palette
        let u = size.width / (16 + 2 * Self.pad)
        let pad = Self.pad * u
        let lip = Self.lip * u
        let caseRect = CGRect(x: 0, y: 0, width: size.width, height: size.height - lip)

        // Case: lip, body, then the dark well the keys sit in.
        ctx.fill(Path(roundedRect: caseRect.offsetBy(dx: 0, dy: lip), cornerRadius: 0.5 * u), with: .color(p.caseEdge))
        ctx.fill(Path(roundedRect: caseRect, cornerRadius: 0.5 * u),
                 with: .linearGradient(Gradient(colors: [p.caseTop, p.caseTop.opacity(0.88)]),
                                       startPoint: .zero, endPoint: CGPoint(x: 0, y: caseRect.maxY)))
        ctx.stroke(Path(roundedRect: caseRect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 0.5 * u),
                   with: .color(.white.opacity(colourway.isDark ? 0.08 : 0.35)), lineWidth: max(1, u * 0.03))
        let well = caseRect.insetBy(dx: pad * 0.55, dy: pad * 0.55)
        ctx.fill(Path(roundedRect: well, cornerRadius: 0.32 * u), with: .color(p.caseEdge.opacity(0.7)))

        let sheen = Color.white.opacity(colourway.isDark ? 0.10 : 0.30)
        for (r, row) in Self.rows.enumerated() {
            var x = pad
            let y = pad + Double(r) * u
            for key in row {
                let cell = CGRect(x: x, y: y, width: key.width * u, height: u)
                x += key.width * u
                let (top, side, legend) = colours(for: key.cap, p)

                let base = cell.insetBy(dx: 0.05 * u, dy: 0.05 * u)
                ctx.fill(Path(roundedRect: base, cornerRadius: 0.14 * u), with: .color(side))
                let face = CGRect(x: base.minX + 0.07 * u, y: base.minY + 0.02 * u,
                                  width: base.width - 0.14 * u, height: base.height - 0.16 * u)
                ctx.fill(Path(roundedRect: face, cornerRadius: 0.12 * u), with: .color(top))
                ctx.fill(Path(roundedRect: face, cornerRadius: 0.12 * u),
                         with: .linearGradient(Gradient(colors: [sheen, .clear]),
                                               startPoint: CGPoint(x: 0, y: face.minY),
                                               endPoint: CGPoint(x: 0, y: face.midY + 0.1 * u)))

                if legends, !key.label.isEmpty {
                    let isAlpha = key.cap == .alpha && key.label.count == 1
                    let fontSize = (isAlpha ? 0.34 : 0.24) * u
                    ctx.draw(Text(key.label).font(inter(fontSize, .medium)).foregroundColor(legend),
                             at: CGPoint(x: face.midX, y: face.midY), anchor: .center)
                }
            }
        }
    }

    private func colours(for cap: Cap, _ p: Colourway.Palette) -> (Color, Color, Color) {
        switch cap {
        case .alpha: (p.alpha, p.alphaSide, p.alphaLegend)
        case .mod: (p.mod, p.modSide, p.modLegend)
        case .accent: (p.accent, p.accentSide, p.accentLegend)
        }
    }
}
