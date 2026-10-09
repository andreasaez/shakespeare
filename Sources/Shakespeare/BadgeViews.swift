import AppKit
import ShakespeareCore
import SwiftUI

enum ShareMode: String, CaseIterable, Identifiable {
    case card = "Card"
    case badges = "Badges"
    var id: String { rawValue }
}

/// Each badge is a keycap in one of the card colourways, with an engraved symbol.
enum BadgeStyle {
    static func colourway(_ id: String) -> Colourway {
        switch id {
        case "couplet": .quarto
        case "sonnet": .synthwave
        case "soliloquy": .venice
        case "scene": .juliet
        case "act": .arden
        case "comedy": .falstaff
        case "macbeth": .elsinore
        case "hamlet": .tudorRose
        case "tenhamlets": .phosphor
        default: .synthwave
        }
    }

    static func symbol(_ id: String) -> String {
        switch id {
        case "couplet": "quote.opening"
        case "sonnet": "heart"
        case "soliloquy": "bubble.left"
        case "scene": "theatermasks"
        case "act": "book.closed"
        case "comedy": "face.smiling"
        case "macbeth": "moon.stars"
        case "hamlet": "crown"
        case "tenhamlets": "books.vertical"
        default: "building.columns"
        }
    }
}

// MARK: - Keycap badge

/// Drawn with the exact key geometry, sheen and colours used for the accent keys
/// in `KeyboardArt` (esc, return, arrows), so a badge looks like a key lifted
/// off its card's keyboard.
struct BadgeKeycap: View {
    enum Look { case earnedNow, earnedBefore, locked }

    let id: String
    let size: CGFloat
    var look = Look.earnedNow
    var lockedTop: Color = .gray.opacity(0.18)
    var lockedSide: Color = .gray.opacity(0.28)
    var lockedInk: Color = .gray.opacity(0.5)

    var body: some View {
        let cw = BadgeStyle.colourway(id)
        let p = cw.palette
        let locked = look == .locked
        let top = locked ? lockedTop : p.accent
        let side = locked ? lockedSide : p.accentSide
        let ink = locked ? lockedInk : p.accentLegend
        let sheen = Color.white.opacity(cw.isDark ? 0.10 : 0.30)
        Canvas { ctx, canvas in
            let u = min(canvas.width, canvas.height)
            // Same proportions as a 1u key in KeyboardArt.
            let base = CGRect(x: 0.05 * u, y: 0.05 * u, width: 0.90 * u, height: 0.90 * u)
            ctx.fill(Path(roundedRect: base, cornerRadius: 0.14 * u), with: .color(side))
            let face = CGRect(x: base.minX + 0.07 * u, y: base.minY + 0.02 * u,
                              width: base.width - 0.14 * u, height: base.height - 0.16 * u)
            ctx.fill(Path(roundedRect: face, cornerRadius: 0.12 * u), with: .color(top))
            if !locked {
                // Light from above, a touch of depth at the bottom: a gradient face, not a flat fill.
                ctx.fill(Path(roundedRect: face, cornerRadius: 0.12 * u),
                         with: .linearGradient(Gradient(colors: [sheen, .clear]),
                                               startPoint: CGPoint(x: 0, y: face.minY),
                                               endPoint: CGPoint(x: 0, y: face.midY + 0.1 * u)))
                ctx.fill(Path(roundedRect: face, cornerRadius: 0.12 * u),
                         with: .linearGradient(Gradient(colors: [.clear, side.opacity(0.35)]),
                                               startPoint: CGPoint(x: 0, y: face.midY),
                                               endPoint: CGPoint(x: 0, y: face.maxY)))
            }
        }
        .overlay {
            // Engraved symbol, centred on the key face (offset up by the side height).
            Image(systemName: BadgeStyle.symbol(id))
                .font(.system(size: size * 0.34, weight: .light))
                .foregroundStyle(ink)
                .offset(y: -size * 0.04)
        }
        .frame(width: size, height: size)
        .shadow(color: locked ? .clear : p.accent.opacity(0.5), radius: size * 0.16, y: size * 0.07)
        .opacity(look == .earnedBefore ? 0.5 : 1)
    }
}

/// A badge on a small bloom plate in its colourway: a miniature of its card,
/// so badges share the cards' soft gradient atmosphere.
struct BadgeTile: View {
    let id: String
    let size: CGFloat
    var look = BadgeKeycap.Look.earnedNow
    var lockedPlate: Color = .gray.opacity(0.15)
    var lockedTop: Color = .gray.opacity(0.18)
    var lockedSide: Color = .gray.opacity(0.28)
    var lockedInk: Color = .gray.opacity(0.5)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.24)
        ZStack {
            if look == .locked {
                shape.fill(lockedPlate)
            } else {
                CardBackground(style: CardStyle(colourway: BadgeStyle.colourway(id), backdrop: .bloom))
                    .clipShape(shape)
                    .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 1))
                    .opacity(look == .earnedBefore ? 0.42 : 1)
            }
            BadgeKeycap(id: id, size: size * 0.64, look: look,
                        lockedTop: lockedTop, lockedSide: lockedSide, lockedInk: lockedInk)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Shareable badge card

/// Same layout as the stats card: a light hero, a stats row, and the keyboard.
struct BadgeCardView: View {
    static let size = CGSize(width: 1080, height: 1350)
    private static let inset: CGFloat = 88

    let status: BadgeStatus
    let monthLabel: String

    var body: some View {
        let cw = BadgeStyle.colourway(status.badge.id)
        let secondary = cw.ink.opacity(0.62)
        ZStack {
            CardBackground(style: CardStyle(colourway: cw, backdrop: .bloom))
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("SHAKESPEARE").font(inter(28, .medium)).tracking(7)
                    Spacer()
                    Text(monthLabel.uppercased()).font(inter(24, .regular)).tracking(3).foregroundStyle(secondary)
                }
                .foregroundStyle(cw.ink)

                Spacer(minLength: 56)

                BadgeKeycap(id: status.badge.id, size: 230)
                    .shadow(color: .black.opacity(cw.isDark ? 0.5 : 0.2), radius: 28, y: 16)

                Spacer().frame(height: 32)

                Text(status.badge.name)
                    .font(inter(150, .light)).tracking(-5)
                    .minimumScaleFactor(0.4).lineLimit(1)
                    .foregroundStyle(cw.ink)
                Text(status.badge.blurb)
                    .font(inter(38, .light))
                    .foregroundStyle(secondary)

                Spacer().frame(height: 48)

                Rectangle().fill(cw.ink.opacity(0.18)).frame(height: 2)
                HStack(alignment: .top, spacing: 0) {
                    stat(status.badge.words.formatted(), "words in a month", cw)
                    stat("×\(max(status.timesEarned, 1))", "times earned", cw)
                    stat(status.firstEarned.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "–", "first earned", cw)
                }
                .padding(.top, 32)

                Spacer(minLength: 30)

                KeyboardArt(colourway: cw)
                    .frame(width: Self.size.width - 2 * Self.inset)
                    .shadow(color: .black.opacity(cw.isDark ? 0.45 : 0.18), radius: 24, y: 14)

                Spacer().frame(height: 34)

                HStack {
                    Text("To type, or not to type.").font(inter(26, .light))
                    Spacer()
                }
                .foregroundStyle(secondary)
            }
            .padding(Self.inset)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    private func stat(_ value: String, _ label: String, _ cw: Colourway) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(inter(64, .light))
                .minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(cw.ink)
            Text(label.uppercased())
                .font(inter(18, .regular)).tracking(3)
                .foregroundStyle(cw.ink.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@MainActor
enum BadgeRenderer {
    static func png(status: BadgeStatus, monthLabel: String) -> Data? {
        let renderer = ImageRenderer(content: BadgeCardView(status: status, monthLabel: monthLabel))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        return PNGScrubber.scrub(png)  // pixels only: no EXIF or other metadata
    }
}

// MARK: - Share tab

/// One tab for everything you can share: your stats card, or your badges.
struct ShareTab: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    let theme: MenuTheme
    /// True while the Share tab is the visible one (all tabs are laid out at once).
    let isActive: Bool
    @State private var status: String?

    private let cardScale: CGFloat = 0.22

    var body: some View {
        let _ = model.revision
        VStack(spacing: 14) {
            Picker("Share", selection: $model.shareMode) {
                ForEach(ShareMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden()

            switch model.shareMode {
            case .card: card
            case .badges: badges
            }

            Text("Made on your mac and saved locally.")
                .font(inter(11, .light)).foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: isActive && model.shareMode == .badges) { _, viewing in
            if viewing { model.markBadgesSeen() }
        }
    }

    // MARK: Card

    private var card: some View {
        let content = CardContent.make(model: model, period: .week, showApps: false)
        return VStack(spacing: 14) {
            CardView(content: content, style: CardStyle())
                .scaleEffect(cardScale, anchor: .topLeading)
                .frame(width: CardView.size.width * cardScale, height: CardView.size.height * cardScale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            Text("Your week on a keyboard.")
                .font(inter(12, .light)).foregroundStyle(theme.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "card")
            } label: {
                Text("Open card studio")
                    .font(inter(13, .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .foregroundStyle(theme.onAccent)
                    .keycap(top: theme.accentTop, side: theme.accentSide)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Badges

    @ViewBuilder
    private var badges: some View {
        let now = Date()
        let statuses = model.engine.badgeStatuses(now: now)
        let earned = statuses.filter(\.isEarnedThisMonth).count
        let selected = statuses.first { $0.id == model.selectedBadgeID }
            ?? statuses.last(where: \.isEarnedThisMonth) ?? statuses.last(where: \.isCollected) ?? statuses[0]
        let monthLabel = now.formatted(.dateTime.month(.wide).year())

        VStack(alignment: .leading, spacing: 14) {
            header(earned: earned, total: statuses.count, now: now)
            progress(model.engine.nextBadge(now: now))
            menuHairline(theme)
            collection(statuses, selected: selected)
            detail(selected, monthLabel: monthLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func header(earned: Int, total: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(earned)").font(inter(48, .light)).tracking(-1.5).monospacedDigit()
                Text("of \(total) earned in \(now.formatted(.dateTime.month(.wide)))")
                    .font(inter(14, .light)).foregroundStyle(theme.secondary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Text("Progress resets on the 1st. Your collection stays.")
                .font(inter(11, .light)).foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func progress(_ next: (badge: Badge, progress: Double, words: Int)?) -> some View {
        if let next {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next: \(next.badge.name)").font(inter(13, .medium))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text("\(next.words.formatted()) / \(next.badge.words.formatted())")
                        .font(inter(11, .light)).foregroundStyle(theme.secondary).monospacedDigit()
                        .lineLimit(1)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.barTrack)
                        Capsule().fill(theme.accentTop).frame(width: max(6, geo.size.width * next.progress))
                    }
                }
                .frame(height: 6)
            }
        } else {
            Text("Every badge earned this month. See you on the 1st.")
                .font(inter(13, .light)).foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func collection(_ statuses: [BadgeStatus], selected: BadgeStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 8) {
                ForEach(statuses) { cell($0, selected: $0.id == selected.id) }
            }
            HStack(spacing: 12) {
                legend(.earnedNow, "this month")
                legend(.earnedBefore, "earned before")
                legend(.locked, "not yet")
            }
        }
    }

    private func look(_ item: BadgeStatus) -> BadgeKeycap.Look {
        item.isEarnedThisMonth ? .earnedNow : (item.isCollected ? .earnedBefore : .locked)
    }

    private func legend(_ look: BadgeKeycap.Look, _ text: String) -> some View {
        HStack(spacing: 4) {
            BadgeTile(id: "couplet", size: 16, look: look, lockedPlate: theme.keyTop.opacity(0.5),
                      lockedTop: theme.keyTop.opacity(0.5), lockedSide: theme.keySide.opacity(0.5), lockedInk: .clear)
            Text(text).font(inter(10, .light)).foregroundStyle(theme.secondary).lineLimit(1)
        }
    }

    private func cell(_ item: BadgeStatus, selected: Bool) -> some View {
        Button { model.selectedBadgeID = item.id; status = nil } label: {
            VStack(spacing: 3) {
                BadgeTile(id: item.id, size: 52, look: look(item), lockedPlate: theme.keyTop.opacity(0.4),
                          lockedTop: theme.keyTop.opacity(0.6), lockedSide: theme.keySide.opacity(0.6),
                          lockedInk: theme.keySecondary.opacity(0.7))
                    .overlay(alignment: .topTrailing) {
                        if item.isEarnedThisMonth {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.accentTop, theme.keyTop)
                                .offset(x: 3, y: -3)
                        }
                    }
                Text(item.timesEarned > 1 ? "×\(item.timesEarned)" : " ")
                    .font(inter(9, .medium)).foregroundStyle(theme.secondary)
            }
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? theme.ink.opacity(0.5) : .clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.badge.name), \(item.isEarnedThisMonth ? "earned this month" : item.isCollected ? "earned before" : "locked")")
    }

    /// The selected badge, with the full width for its text and actions.
    private func detail(_ item: BadgeStatus, monthLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            menuHairline(theme)
            HStack(alignment: .center, spacing: 12) {
                BadgeTile(id: item.id, size: 52, look: look(item), lockedPlate: theme.keyTop.opacity(0.4),
                          lockedTop: theme.keyTop.opacity(0.6), lockedSide: theme.keySide.opacity(0.6),
                          lockedInk: theme.keySecondary.opacity(0.7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.badge.name).font(inter(17, .regular))
                    Text(item.badge.blurb).font(inter(12, .light)).foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.badge.words.formatted()) words in a month")
                Text(history(item))
            }
            .font(inter(11, .light)).foregroundStyle(theme.secondary)
            .fixedSize(horizontal: false, vertical: true)

            if item.isCollected {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { shareButtons(item, monthLabel) }
                    VStack(alignment: .leading, spacing: 8) { shareButtons(item, monthLabel) }
                }
                if let status {
                    Text(status).font(inter(11, .light)).foregroundStyle(theme.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func shareButtons(_ item: BadgeStatus, _ monthLabel: String) -> some View {
        KeycapButton(theme: theme, title: "Copy image") { copy(item, monthLabel) }
        KeycapButton(theme: theme, title: "Save PNG…") { save(item, monthLabel) }
    }

    private func history(_ item: BadgeStatus) -> String {
        guard let first = item.firstEarned else { return "Not earned yet" }
        let times = item.timesEarned == 1 ? "earned once" : "earned in \(item.timesEarned) months"
        return "First earned \(first.formatted(.dateTime.month(.abbreviated).day().year())), \(times)"
    }

    private func copy(_ item: BadgeStatus, _ monthLabel: String) {
        guard let png = BadgeRenderer.png(status: item, monthLabel: monthLabel) else { status = "Couldn't render the badge."; return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
        status = "Copied to clipboard."
    }

    private func save(_ item: BadgeStatus, _ monthLabel: String) {
        guard let png = BadgeRenderer.png(status: item, monthLabel: monthLabel) else { status = "Couldn't render the badge."; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "shakespeare-\(item.badge.id).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url, options: .atomic)
            status = "Saved \(url.lastPathComponent)."
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }
}
