import CoreGraphics
import Foundation

/// Listen-only keyboard tap. It can observe key presses but cannot modify or
/// block them, and it only ever reads the numeric key code and modifier flags
/// (it never asks macOS for the character). A key code identifies which key was
/// pressed, so callers must reduce it at once (see `AppModel.handle`) and never
/// store it. macOS gates this behind Input Monitoring.
final class KeyMonitor {
    /// (keyCode, hasShortcutModifier, hasCommand, isAutoRepeat). Always called on the main thread.
    var onKey: ((Int, Bool, Bool, Bool) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }
    static func requestPermission() { _ = CGRequestListenEventAccess() }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
            switch type {
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            case .keyDown:
                let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
                let repeating = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                let flags = event.flags
                let shortcut =
                    flags.contains(.maskCommand) || flags.contains(.maskControl)
                    || flags.contains(.maskAlternate)
                monitor.onKey?(code, shortcut, flags.contains(.maskCommand), repeating)
            default:
                break
            }
            return Unmanaged.passUnretained(event)
        }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly,
                eventsOfInterest: mask, callback: callback,
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
    }

    deinit { stop() }
}
