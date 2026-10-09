import ShakespeareCore
import SwiftUI

enum CardPeriod: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Last 7 days"
    var id: String { rawValue }

    var days: Int { self == .today ? 1 : 7 }
}

/// Everything shown on the card. Built from counters only; app names are
/// included solely when the user has opted in *and* chosen to show them.
struct CardContent {
    var period: CardPeriod
    var dateLabel: String
    var keys: Int
    var streak: Int
    var bestWPM: Int
    var busiestHour: String?
    var hamlets: Double
    var topApps: [AppCount]

    @MainActor
    static func make(model: AppModel, period: CardPeriod, showApps: Bool, now: Date = Date()) -> CardContent {
        let summary = model.engine.summary(lastDays: period.days, endingAt: now, appLimit: 3)
        let label: String
        if period == .today {
            label = now.formatted(.dateTime.weekday(.wide).month(.wide).day())
        } else {
            let start = Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now
            label = "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(now.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return CardContent(
            period: period, dateLabel: label.uppercased(), keys: summary.keys,
            streak: model.engine.streak(endingAt: now), bestWPM: Int(summary.bestWPM),
            busiestHour: summary.busiestHour.map(FunFacts.hourLabel),
            hamlets: FunFacts.hamlets(textKeys: summary.textKeys),
            topApps: showApps && model.trackApps ? summary.topApps : [])
    }
}

/// The shareable card, on a fixed 1080×1350 canvas (4:5): a light, quiet
/// layout with the colourway's keyboard as the hero.
struct CardView: View {
    static let size = CGSize(width: 1080, height: 1350)
    private static let inset: CGFloat = 88

    let content: CardContent
    let style: CardStyle

    var body: some View {
        let cw = style.colourway
        let secondary = cw.ink.opacity(0.62)
        ZStack {
            CardBackground(style: style)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("SHAKESPEARE")
                        .font(inter(28, .medium)).tracking(7)
                    Spacer()
                    Text(content.dateLabel)
                        .font(inter(24, .regular)).tracking(3)
                        .foregroundStyle(secondary)
                }
                .foregroundStyle(cw.ink)

                Spacer(minLength: 20)

                Text(content.keys.formatted())
                    .font(inter(250, .light))
                    .tracking(-8)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .foregroundStyle(cw.ink)
                Text(content.period == .today ? "keys pressed today" : "keys pressed this week")
                    .font(inter(38, .light))
                    .foregroundStyle(secondary)

                Spacer().frame(height: 56)

                Rectangle().fill(cw.ink.opacity(0.18)).frame(height: 2)
                HStack(alignment: .top, spacing: 0) {
                    stat("\(content.streak)", "day streak", cw)
                    stat(content.bestWPM > 0 ? "\(content.bestWPM)" : "–", "best WPM", cw)
                    stat(content.busiestHour ?? "–", "busiest hour", cw)
                    stat(String(format: "%.2f", content.hamlets), "Hamlets", cw)
                }
                .padding(.top, 32)

                if !content.topApps.isEmpty {
                    HStack(spacing: 24) {
                        Text("WHERE I TYPE").font(inter(20, .medium)).tracking(3).foregroundStyle(secondary)
                        ForEach(content.topApps, id: \.name) { app in
                            Text("\(app.name) \(app.keys.formatted())").font(inter(26, .light)).lineLimit(1)
                        }
                    }
                    .foregroundStyle(cw.ink)
                    .padding(.top, 30)
                }

                Spacer(minLength: 30)

                KeyboardArt(colourway: cw)
                    .frame(width: Self.size.width - 2 * Self.inset)
                    .shadow(color: .black.opacity(cw.isDark ? 0.45 : 0.18), radius: 24, y: 14)

                Spacer().frame(height: 34)

                HStack {
                    Text("To type, or not to type.")
                        .font(inter(26, .light))
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
