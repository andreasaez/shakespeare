import AppKit
import ServiceManagement
import ShakespeareCore

@MainActor
final class AppModel: ObservableObject {
    enum MonitorState {
        case running
        case needsPermission
        /// Permission is granted but macOS won't hand a running app its key tap until it relaunches.
        case needsRestart
    }

    private enum Defaults {
        static let trackApps = "trackApps"
        static let menuTheme = "menuTheme"
        static let seenBadgeTotal = "seenBadgeTotal"
    }

    /// Bumped (throttled) whenever stats change, to refresh views.
    @Published private(set) var revision = 0
    @Published private(set) var monitorState = MonitorState.needsPermission
    /// Session-only: the notice returns on next launch if counting still isn't running.
    @Published var noticeDismissed = false
    @Published private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// Opt-in. Off by default: when on, the name of the front-most app is
    /// stored next to a key count. Turning it off erases stored app names.
    @Published var trackApps: Bool {
        didSet {
            UserDefaults.standard.set(trackApps, forKey: Defaults.trackApps)
            if !trackApps {
                engine.clearApps()
                saveNow()
            }
            bump()
        }
    }

    /// Menu appearance chosen in Settings. `.system` follows macOS light/dark.
    @Published var menuTheme: MenuTheme {
        didSet { UserDefaults.standard.set(menuTheme.rawValue, forKey: Defaults.menuTheme) }
    }

    /// Which badge the Badges and Share tabs are showing, and what Share is showing.
    @Published var selectedBadgeID: String?
    @Published var shareMode = ShareMode.card

    let engine: StatsEngine
    private let persistence = StatsPersistence()
    private let monitor = KeyMonitor()
    private var bumpPending = false

    /// Held for the life of the app so only one copy counts keys and writes stats.
    private let instanceLock: InstanceLock?

    init() {
        // Take the lock before reading any data. A second copy would double-count and overwrite saves.
        switch InstanceLock.acquire(directory: persistence.directory) {
        case .acquired(let lock):
            instanceLock = lock
        case .heldByAnotherCopy:
            NSLog("%@", "Shakespeare is already running; quitting this copy.")
            exit(0)
        case .unavailable:
            // Couldn't create the lock file. Starting without it beats a silent exit that looks like a crash.
            NSLog("%@", "Shakespeare could not create its lock file; continuing without it.")
            instanceLock = nil
        }
        engine = StatsEngine(data: persistence.load())
        // Tidy up app names recorded before keys pressed in Shakespeare itself were excluded.
        if let ownName = NSRunningApplication.current.localizedName { engine.removeApp(named: ownName) }
        trackApps = UserDefaults.standard.bool(forKey: Defaults.trackApps)
        menuTheme = MenuTheme(rawValue: UserDefaults.standard.string(forKey: Defaults.menuTheme) ?? "") ?? .system

        monitor.onKey = { [weak self] code, shortcut, command, repeating in
            // The event tap runs on the main run loop.
            MainActor.assumeIsolated {
                self?.handle(code: code, shortcut: shortcut, command: command, repeating: repeating)
            }
        }
        startMonitoringWhenPermitted()

        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow(); self?.bump() }
        }
        let flush: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main, using: flush)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main, using: flush)
    }

    // MARK: - Key handling

    private func handle(code: Int, shortcut: Bool, command: Bool, repeating: Bool) {
        guard !repeating else { return }  // held keys count once
        let kind = KeyClassifier.kind(keyCode: code, hasShortcutModifier: shortcut, hasCommand: command)
        guard kind != .ignored else { return }  // ⌘Q / ⌘W: quitting and closing aren't typing
        // Keys pressed while Shakespeare itself is in front (Esc to close the menu, ⌘S in the
        // card studio, a filename in the Save panel) still count toward totals, but aren't
        // filed under an app: they're interface noise, not "where you type".
        let front = trackApps ? NSWorkspace.shared.frontmostApplication : nil
        let app = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front?.localizedName
        engine.record(kind, at: Date(), app: app)
        bump()
    }

    private func startMonitoringWhenPermitted() {
        refreshMonitor()
        guard monitorState != .running else { return }
        if monitorState == .needsPermission { KeyMonitor.requestPermission() }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                self.refreshMonitor()
                if self.monitorState == .running { timer.invalidate() }
            }
        }
    }

    private func refreshMonitor() {
        if monitor.isRunning || monitor.start() {
            monitorState = .running
        } else {
            monitorState = KeyMonitor.hasPermission ? .needsRestart : .needsPermission
        }
    }

    // MARK: - Badges

    /// Total (badge, month) earnings so far; used only to know when to show a dot.
    private var badgeTotal: Int { engine.badgeStatuses(now: Date()).reduce(0) { $0 + $1.timesEarned } }

    var hasUnseenBadges: Bool {
        let _ = revision
        return badgeTotal > UserDefaults.standard.integer(forKey: Defaults.seenBadgeTotal)
    }

    func markBadgesSeen() {
        UserDefaults.standard.set(badgeTotal, forKey: Defaults.seenBadgeTotal)
        bump()
    }

    // MARK: - Queries used by views

    var todayCount: Int { engine.keys(on: Date()) }

    // MARK: - Actions

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("%@", "Shakespeare: launch-at-login change failed: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func revealDataInFinder() {
        saveNow()
        NSWorkspace.shared.activateFileViewerSelecting([persistence.url])
    }

    func deleteAllData() {
        engine.reset()
        try? persistence.delete()
        bump()
    }

    func relaunch() {
        saveNow()
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApplication.shared.terminate(nil) }
        }
    }

    func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    func saveNow() {
        guard engine.isDirty else { return }
        do {
            try persistence.save(engine.data)
            engine.markSaved()
        } catch {
            NSLog("%@", "Shakespeare: could not save stats: \(error.localizedDescription)")
        }
    }

    /// Coalesces rapid typing into at most ~2 view refreshes per second.
    private func bump() {
        guard !bumpPending else { return }
        bumpPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            MainActor.assumeIsolated {
                self?.bumpPending = false
                self?.revision &+= 1
            }
        }
    }
}
