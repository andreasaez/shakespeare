import AppKit
import ShakespeareCore
import SwiftUI

enum MenuTab: String, CaseIterable, Identifiable {
    case stats = "Stats"
    case share = "Share"
    case settings = "Settings"
    var id: String { rawValue }
}

struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.colorScheme) private var systemScheme
    @State private var tab = MenuTab.stats

    var body: some View {
        let theme = model.menuTheme
        VStack(alignment: .leading, spacing: 16) {
            tabBar(theme)
            if model.monitorState != .running && !model.noticeDismissed { permissionNotice(theme) }
            tabContent(theme)
        }
        .padding(18)
        .frame(width: 340)
        .font(inter(13, .regular))
        .foregroundStyle(theme.ink)
        .tint(theme.accentTop)
        .background { theme.background }
        .environment(\.colorScheme, theme.scheme ?? systemScheme)
    }

    /// All tabs are laid out together and only the active one is visible, so the
    /// window is always as tall as the tallest tab: it never scrolls, never cuts
    /// anything off, and never resizes (or jumps) when you switch tabs.
    private func tabContent(_ theme: MenuTheme) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(MenuTab.allCases) { item in
                Group {
                    switch item {
                    case .stats: StatsTab(theme: theme)
                    case .share: ShareTab(theme: theme, isActive: tab == .share)
                    case .settings: SettingsTab(theme: theme)
                    }
                }
                .opacity(tab == item ? 1 : 0)
                .allowsHitTesting(tab == item)
                .accessibilityHidden(tab != item)
            }
        }
    }

    /// Tabs are keycaps; the active one takes the accent colour.
    private func tabBar(_ theme: MenuTheme) -> some View {
        HStack(spacing: 8) {
            ForEach(MenuTab.allCases) { item in
                let active = tab == item
                Button { tab = item } label: {
                    HStack(spacing: 4) {
                        Text(item.rawValue)
                        if item == .share && model.hasUnseenBadges && !(tab == .share && model.shareMode == .badges) {
                            Circle().fill(active ? theme.onAccent : theme.accentTop).frame(width: 5, height: 5)
                        }
                    }
                        .font(inter(12, .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(active ? theme.onAccent : theme.keyInk)
                        .keycap(top: active ? theme.accentTop : theme.keyTop,
                                side: active ? theme.accentSide : theme.keySide)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func permissionNotice(_ theme: MenuTheme) -> some View {
        let needsRestart = model.monitorState == .needsRestart
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(needsRestart ? "Restart to start counting" : "Input Monitoring needed")
                    .font(inter(14, .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button { model.noticeDismissed = true } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            Text(needsRestart
                 ? "Permission is on. macOS needs Shakespeare to restart once before it can count."
                 : "Shakespeare counts key presses. It never records what you type. Allow it in System Settings and it starts automatically.")
                .font(inter(12, .light))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            KeycapButton(theme: theme, title: needsRestart ? "Restart Shakespeare" : "Open System Settings",
                         action: needsRestart ? model.relaunch : model.openInputMonitoringSettings)
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.hairline, lineWidth: 1))
    }
}

// MARK: - Shared pieces

struct KeycapButton: View {
    let theme: MenuTheme
    let title: String
    var destructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(inter(12, .medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .foregroundStyle(destructive ? Color(hex: 0xD6403F) : theme.keyInk)
                .keycap(top: theme.keyTop, side: theme.keySide)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

func sectionLabel(_ text: String, _ theme: MenuTheme) -> some View {
    Text(text.uppercased())
        .font(inter(10, .medium)).tracking(1.2)
        .foregroundStyle(theme.secondary)
}

func menuHairline(_ theme: MenuTheme) -> some View {
    Rectangle().fill(theme.hairline).frame(height: 1)
}

// MARK: - Stats

private struct StatsTab: View {
    @EnvironmentObject private var model: AppModel
    let theme: MenuTheme
    @State private var hoveredIndex: Int?

    var body: some View {
        let _ = model.revision  // refresh when stats change
        let now = Date()
        let days = model.engine.lastDays(14, endingAt: now)
        let allTime = model.engine.summary(lastDays: nil, endingAt: now)
        let metres = FunFacts.travelMetres(keys: allTime.keys)
        let streak = "\(model.engine.streak(endingAt: now))"
        let speed = allTime.bestWPM > 0 ? "\(Int(allTime.bestWPM))" : "–"
        let hour = allTime.busiestHour.map(FunFacts.hourLabel) ?? "–"
        let hamlets = String(format: "%.2f", FunFacts.hamlets(textKeys: allTime.textKeys))

        VStack(alignment: .leading, spacing: 16) {
            header(days)
            bars(days)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                stat("flame", "Streak", streak, "days")
                    .help("Days with \(StatsEngine.streakThreshold)+ keys count toward your streak.")
                stat("speedometer", "Best speed", speed, "WPM")
                stat("clock", "Busiest hour", hour, nil)
                stat("book.closed", "Hamlets typed", hamlets, nil)
            }

            menuHairline(theme)

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Fun facts", theme)
                note("arrow.down.to.line", FunFacts.travelFact(metres: metres))
                if let day = model.engine.busiestDay() {
                    note("calendar", "Your busiest day was \(day.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())), with \(day.keys.formatted()) keys.")
                }
                if model.engine.totalWords >= 250 {
                    note("doc.text", "You've typed about \(Int(FunFacts.novelPages(words: model.engine.totalWords)).formatted()) pages of a novel so far.")
                }
            }

            if model.trackApps { topApps(allTime.topApps) }
        }
    }

    private func header(_ days: [DayCount]) -> some View {
        let index = hoveredIndex ?? days.count - 1
        let isToday = index == days.count - 1
        let caption = isToday ? "keys today" : "keys on \(days[index].date.formatted(.dateTime.weekday(.wide).month().day()))"
        return VStack(alignment: .leading, spacing: 0) {
            Text(days[index].keys.formatted())
                .font(inter(64, .light))
                .tracking(-2)
                .monospacedDigit()
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(caption)
                .font(inter(13, .light))
                .foregroundStyle(theme.secondary)
        }
    }

    private func bars(_ days: [DayCount]) -> some View {
        let peak = max(days.map(\.keys).max() ?? 1, 1)
        let active = hoveredIndex ?? days.count - 1
        return HStack(alignment: .top, spacing: 4) {
            ForEach(days.indices, id: \.self) { i in
                dayColumn(days[i], index: i, active: active, peak: peak)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keys per day, last 14 days")
    }

    private func dayColumn(_ day: DayCount, index i: Int, active: Int, peak: Int) -> some View {
        let isActive = i == active
        let fillHeight: CGFloat = day.keys == 0 ? 0 : max(4, 52 * CGFloat(day.keys) / CGFloat(peak))
        return VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(theme.barTrack)
                RoundedRectangle(cornerRadius: 4)
                    .fill(isActive ? theme.accentTop : theme.barFill)
                    .frame(height: fillHeight)
            }
            .frame(height: 52)
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(inter(9, isActive ? .medium : .regular))
                .foregroundStyle(isActive ? theme.ink : theme.secondary)
        }
        .contentShape(Rectangle())
        .onHover { inside in hoveredIndex = inside ? i : (hoveredIndex == i ? nil : hoveredIndex) }
    }

    /// A stat drawn as a keycap: small legend on top, light value below.
    private func stat(_ icon: String, _ title: String, _ value: String, _ unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .light))
                    .frame(width: 13)
                Text(title.uppercased())
                    .font(inter(9, .medium)).tracking(1)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .foregroundStyle(theme.keySecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(inter(24, .light)).monospacedDigit()
                if let unit { Text(unit).font(inter(11, .light)).foregroundStyle(theme.keySecondary) }
            }
            .foregroundStyle(theme.keyInk)
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keycap(top: theme.keyTop, side: theme.keySide, radius: 10)
    }

    private func note(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .light))
                .frame(width: 14)
            Text(text)
                .font(inter(12, .light))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(theme.secondary)
    }

    private func topApps(_ apps: [AppCount]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            menuHairline(theme)
            sectionLabel("Where you type most", theme)
            if apps.isEmpty {
                Text("Collecting… start typing.").font(inter(12, .light)).foregroundStyle(theme.secondary)
            }
            ForEach(apps, id: \.name) { app in
                HStack {
                    Text(app.name).lineLimit(1)
                    Spacer()
                    Text(app.keys.formatted()).monospacedDigit().foregroundStyle(theme.secondary)
                }
                .font(inter(13, .regular))
            }
        }
    }
}

// MARK: - Settings

private struct SettingsTab: View {
    @EnvironmentObject private var model: AppModel
    let theme: MenuTheme
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            appearance
            menuHairline(theme)
            toggles
            menuHairline(theme)
            dataSection
            footer
        }
        .confirmationDialog("Delete all Shakespeare data?", isPresented: $confirmingDelete) {
            Button("Delete everything", role: .destructive) { model.deleteAllData() }
        } message: {
            Text("This permanently erases your key counts and streak from this Mac.")
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Appearance", theme)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 8) {
                ForEach(MenuTheme.all) { option in
                    chip(option)
                }
            }
            if model.menuTheme == .system {
                Text("Follows your Mac's light and dark setting.")
                    .font(inter(11, .light)).foregroundStyle(theme.secondary)
            }
        }
    }

    private func chip(_ option: MenuTheme) -> some View {
        let selected = model.menuTheme == option
        return Button { model.menuTheme = option } label: {
            HStack(spacing: 6) {
                Circle().fill(option.swatch).frame(width: 9, height: 9)
                Text(option.name).font(inter(11, selected ? .medium : .regular)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? theme.ink : theme.hairline, lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
            Toggle(isOn: $model.trackApps) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Track top apps")
                    Text("Off by default. Stores app names next to key counts, never what you type. Turning it off erases them.")
                        .font(inter(11, .light))
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Your data", theme)
            Text("Only per-day counters are stored on this Mac, in a file only you can read.")
                .font(inter(11, .light))
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { dataButtons }
                VStack(alignment: .leading) { dataButtons }
            }
        }
    }

    private var footer: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return HStack {
            Text("Shakespeare \(version)")
                .font(inter(11, .light))
                .foregroundStyle(theme.secondary)
            Spacer()
            KeycapButton(theme: theme, title: "Quit") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    @ViewBuilder private var dataButtons: some View {
        KeycapButton(theme: theme, title: "Show in Finder", action: model.revealDataInFinder)
        KeycapButton(theme: theme, title: "Delete all data…", destructive: true) { confirmingDelete = true }
    }
}
