import SwiftUI

/// Card backdrop at any size. All art is procedural (no image assets) and
/// scales relative to a 1080pt-wide card.
struct CardBackground: View {
    let style: CardStyle

    var body: some View {
        let cw = style.colourway
        ZStack {
            cw.bg
            switch style.backdrop {
            case .solid:
                EmptyView()
            case .bloom:
                Canvas { ctx, size in Self.bloom(&ctx, size, cw) }
            case .pattern:
                Canvas { ctx, size in Self.draw(style.pattern, in: &ctx, size: size, tint: cw.ink.opacity(cw.isDark ? 0.14 : 0.12)) }
            }
        }
    }

    // MARK: Bloom

    private static func bloom(_ ctx: inout GraphicsContext, _ size: CGSize, _ cw: Colourway) {
        let rect = Path(CGRect(origin: .zero, size: size))
        let strength = cw.isDark ? 0.55 : 0.6
        ctx.fill(rect, with: .radialGradient(
            Gradient(colors: [cw.bloom[0].opacity(strength), .clear]),
            center: CGPoint(x: size.width * 0.12, y: size.height * 0.08),
            startRadius: 0, endRadius: size.width * 0.95))
        ctx.fill(rect, with: .radialGradient(
            Gradient(colors: [cw.bloom[1].opacity(strength), .clear]),
            center: CGPoint(x: size.width * 0.95, y: size.height * 0.92),
            startRadius: 0, endRadius: size.width * 1.0))
    }

    // MARK: Patterns

    private static func draw(_ p: CardPattern, in ctx: inout GraphicsContext, size: CGSize, tint: Color) {
        let s = size.width / 1080
        switch p {
        case .manuscript: manuscript(&ctx, size, s, tint)
        case .damask: damask(&ctx, size, s, tint)
        case .fleurDeLis: fleur(&ctx, size, s, tint)
        case .sunburst: sunburst(&ctx, size, s, tint)
        case .starfield: starfield(&ctx, size, s, tint)
        case .tudorFloor: tudorFloor(&ctx, size, s, tint)
        case .retroGrid: retroGrid(&ctx, size, s, tint)
        case .scanlines: scanlines(&ctx, size, s, tint)
        case .halftone: halftone(&ctx, size, s, tint)
        }
    }

    private static func manuscript(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        var y = 120 * s
        while y < size.height {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(line, with: .color(tint), lineWidth: 2 * s)
            y += 56 * s
        }
        var margin = Path()
        margin.move(to: CGPoint(x: 96 * s, y: 0))
        margin.addLine(to: CGPoint(x: 96 * s, y: size.height))
        ctx.stroke(margin, with: .color(tint), lineWidth: 3 * s)
    }

    private static func damask(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let step = 120 * s
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
            while x < size.width + step {
                var d = Path()
                d.move(to: CGPoint(x: x, y: y - step / 2))
                d.addLine(to: CGPoint(x: x + step / 2, y: y))
                d.addLine(to: CGPoint(x: x, y: y + step / 2))
                d.addLine(to: CGPoint(x: x - step / 2, y: y))
                d.closeSubpath()
                ctx.stroke(d, with: .color(tint), lineWidth: 2 * s)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 7 * s, y: y - 7 * s, width: 14 * s, height: 14 * s)), with: .color(tint))
                x += step
            }
            y += step / 2
            row += 1
        }
    }

    private static func fleur(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let step = 150 * s
        let glyph = Text("⚜").font(.system(size: 64 * s)).foregroundColor(tint)
        var row = 0
        var y = step / 2
        while y < size.height + step {
            var x = row.isMultiple(of: 2) ? step / 2 : step
            while x < size.width + step {
                ctx.draw(glyph, at: CGPoint(x: x, y: y))
                x += step
            }
            y += step * 0.8
            row += 1
        }
    }

    private static func sunburst(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let origin = CGPoint(x: size.width / 2, y: size.height * 0.92)
        let rays = 24
        let radius = size.height * 1.4
        for i in 0..<rays where i.isMultiple(of: 2) {
            // CGFloat angles keep cos/sin unambiguous across Swift toolchains.
            let a0 = CGFloat.pi + CGFloat.pi * CGFloat(i) / CGFloat(rays)
            let a1 = CGFloat.pi + CGFloat.pi * CGFloat(i + 1) / CGFloat(rays)
            var wedge = Path()
            wedge.move(to: origin)
            wedge.addLine(to: CGPoint(x: origin.x + radius * cos(a0), y: origin.y + radius * sin(a0)))
            wedge.addLine(to: CGPoint(x: origin.x + radius * cos(a1), y: origin.y + radius * sin(a1)))
            wedge.closeSubpath()
            ctx.fill(wedge, with: .color(tint))
        }
    }

    private static func starfield(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        var seed: UInt64 = 0x5EED_5BA6  // fixed seed: the sky is the same every render
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 40) / CGFloat(1 << 24)
        }
        for _ in 0..<160 {
            let r = (1 + next() * 3) * s
            let rect = CGRect(x: next() * size.width, y: next() * size.height, width: r, height: r)
            ctx.fill(Path(ellipseIn: rect), with: .color(tint))
        }
    }

    private static func tudorFloor(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let tile = 135 * s
        var row = 0
        var y: CGFloat = 0
        while y < size.height {
            var col = 0
            var x: CGFloat = 0
            while x < size.width {
                if (row + col).isMultiple(of: 2) {
                    ctx.fill(Path(CGRect(x: x, y: y, width: tile, height: tile)), with: .color(tint))
                }
                x += tile
                col += 1
            }
            y += tile
            row += 1
        }
    }

    private static func retroGrid(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let horizon = size.height * 0.5
        let vanishing = CGPoint(x: size.width / 2, y: horizon)
        for i in -14...14 {
            var line = Path()
            line.move(to: vanishing)
            line.addLine(to: CGPoint(x: size.width / 2 + CGFloat(i) * 220 * s, y: size.height))
            ctx.stroke(line, with: .color(tint), lineWidth: 2 * s)
        }
        for i in 1...12 {
            let t = pow(CGFloat(i) / 12, 2.2)
            let y = horizon + (size.height - horizon) * t
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(line, with: .color(tint), lineWidth: 2 * s)
        }
    }

    private static func scanlines(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        var y: CGFloat = 0
        while y < size.height {
            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 2 * s)), with: .color(tint))
            y += 6 * s
        }
    }

    private static func halftone(_ ctx: inout GraphicsContext, _ size: CGSize, _ s: CGFloat, _ tint: Color) {
        let step = 36 * s
        var row = 0
        var y: CGFloat = 0
        while y < size.height + step {
            var x: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
            while x < size.width + step {
                let r = (2 + 12 * (y / size.height)) * s  // dots grow toward the bottom
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(tint))
                x += step
            }
            y += step * 0.86
            row += 1
        }
    }
}
