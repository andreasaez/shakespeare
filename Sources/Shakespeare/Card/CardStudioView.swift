import AppKit
import ShakespeareCore
import SwiftUI

struct CardStudioView: View {
    @EnvironmentObject private var model: AppModel
    @State private var style = CardStyle()
    @State private var period = CardPeriod.week
    @State private var showApps = false
    @State private var status: String?

    private let previewScale: CGFloat = 0.36

    var body: some View {
        let content = CardContent.make(model: model, period: period, showApps: showApps)
        HStack(alignment: .top, spacing: 28) {
            CardView(content: content, style: style)
                .scaleEffect(previewScale, anchor: .topLeading)
                .frame(width: CardView.size.width * previewScale, height: CardView.size.height * previewScale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 4)

            VStack(alignment: .leading, spacing: 18) {
                section("Period") {
                    Picker("Period", selection: $period) {
                        ForEach(CardPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                }

                section("Colourway") { colourways }

                section("Backdrop") {
                    Picker("Backdrop", selection: $style.backdrop) {
                        ForEach(CardBackdrop.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    if style.backdrop == .pattern { patterns }
                }

                if model.trackApps {
                    Toggle("Show top apps on card", isOn: $showApps)
                }

                Spacer(minLength: 0)

                if let status { Text(status).font(inter(12)).foregroundStyle(.secondary) }
                HStack {
                    Button("Copy image") { copy(content) }
                    Button("Save PNG…") { save(content) }.keyboardShortcut("s")
                }
                Text("Made on your mac and saved locally.")
                    .font(inter(11)).foregroundStyle(.secondary)
            }
            .font(inter(13))
            .frame(width: 330)
        }
        .padding(28)
        .frame(minHeight: CardView.size.height * previewScale + 56)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(inter(10, .medium)).tracking(1.2).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: Colourways

    private var colourways: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
            ForEach(Colourway.allCases) { option in
                let selected = style.colourway == option
                Button { style.colourway = option } label: {
                    VStack(spacing: 5) {
                        KeyboardArt(colourway: option, legends: false)
                            .padding(7)
                            .background(option.bg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 2.5 : 1))
                        Text(option.rawValue).font(inter(11, selected ? .medium : .regular)).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var patterns: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(CardPattern.allCases) { option in
                let selected = style.pattern == option
                Button { style.pattern = option } label: {
                    VStack(spacing: 4) {
                        CardBackground(style: CardStyle(colourway: style.colourway, backdrop: .pattern, pattern: option))
                            .frame(height: 46)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: selected ? 2.5 : 1))
                        Text(option.rawValue).font(inter(10)).lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.rawValue)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Export

    private func copy(_ content: CardContent) {
        guard let png = CardRenderer.png(content: content, style: style) else { status = "Couldn't render the card."; return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
        status = "Copied to clipboard."
    }

    private func save(_ content: CardContent) {
        guard let png = CardRenderer.png(content: content, style: style) else { status = "Couldn't render the card."; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "shakespeare-card.png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url, options: .atomic)
            status = "Saved \(url.lastPathComponent)."
        } catch {
            status = "Couldn't save: \(error.localizedDescription)"
        }
    }
}

@MainActor
enum CardRenderer {
    /// Renders the card to PNG at 1080×1350, scrubbed of all metadata.
    static func png(content: CardContent, style: CardStyle) -> Data? {
        let renderer = ImageRenderer(content: CardView(content: content, style: style))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return nil }
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        return PNGScrubber.scrub(png)  // pixels only: no EXIF or other metadata
    }
}
