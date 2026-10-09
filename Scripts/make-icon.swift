#!/usr/bin/env swift
// Draws the Shakespeare app icon in code and writes Resources/AppIcon.icns.
// Run from the repo root:  swift Scripts/make-icon.swift
// The icon is a cream keycap engraved with "S" on a Tudor-crimson and gold bloom,
// the same visual language as the share cards. Needs macOS (AppKit + iconutil).
import AppKit
import CoreText

CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "Resources/Fonts/InterVariable.ttf") as CFURL, .process, nil)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

/// Draws on a 1024×1024 canvas (y up). Apple's template: an ~824pt rounded body with a margin.
func draw(_ ctx: CGContext) {
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

    // Soft drop shadow under the whole icon.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath); ctx.setFillColor(color(0x6B1B26)); ctx.fillPath()
    ctx.restoreGState()

    // Background: crimson, with gold and ember blooms.
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    ctx.drawLinearGradient(gradient([color(0xA3202F), color(0x4A0E17)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.drawRadialGradient(gradient([color(0xD9A441, 0.80), color(0xD9A441, 0)]),
                           startCenter: CGPoint(x: 250, y: 840), startRadius: 0,
                           endCenter: CGPoint(x: 250, y: 840), endRadius: 640, options: [])
    ctx.drawRadialGradient(gradient([color(0xE07A5F, 0.45), color(0xE07A5F, 0)]),
                           startCenter: CGPoint(x: 830, y: 200), startRadius: 0,
                           endCenter: CGPoint(x: 830, y: 200), endRadius: 560, options: [])
    // Light catching the top edge.
    ctx.drawLinearGradient(gradient([color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 700), options: [])
    ctx.restoreGState()

    // The keycap: darker side, raised face, soft sheen.
    let side = CGRect(x: 272, y: 270, width: 480, height: 480)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 46, color: color(0x000000, 0.45))
    ctx.addPath(CGPath(roundedRect: side, cornerWidth: 104, cornerHeight: 104, transform: nil))
    ctx.setFillColor(color(0xC4B28A)); ctx.fillPath()
    ctx.restoreGState()

    let face = CGRect(x: 310, y: 322, width: 404, height: 410)
    let facePath = CGPath(roundedRect: face, cornerWidth: 84, cornerHeight: 84, transform: nil)
    ctx.addPath(facePath); ctx.setFillColor(color(0xF6EBD0)); ctx.fillPath()
    ctx.saveGState()
    ctx.addPath(facePath); ctx.clip()
    ctx.drawLinearGradient(gradient([color(0xFFFFFF, 0.55), color(0xFFFFFF, 0)]),
                           start: CGPoint(x: 512, y: face.maxY), end: CGPoint(x: 512, y: face.midY), options: [])
    ctx.drawLinearGradient(gradient([color(0xC4B28A, 0), color(0xC4B28A, 0.35)]),
                           start: CGPoint(x: 512, y: face.midY), end: CGPoint(x: 512, y: face.minY), options: [])
    ctx.restoreGState()

    // The engraved letter.
    let font = NSFont(name: "InterVariable-Medium", size: 330) ?? NSFont.systemFont(ofSize: 330, weight: .medium)
    let text = NSAttributedString(string: "S", attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: color(0x8E1B2D))!,
    ])
    let size = text.size()
    text.draw(at: CGPoint(x: face.midX - size.width / 2, y: face.midY - size.height / 2 - 4))
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.interpolationQuality = .high
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Standard macOS iconset: 16–512pt at 1x and 2x.
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Shakespeare-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
    let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
    try renderPNG(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
}
if let preview = ProcessInfo.processInfo.environment["ICON_PREVIEW"] {
    try renderPNG(pixels: 1024).write(to: URL(fileURLWithPath: preview))
}

let output = "Resources/AppIcon.icns"
let tool = Process()
tool.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
tool.arguments = ["-c", "icns", iconset.path, "-o", output]
try tool.run(); tool.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard tool.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output)")
