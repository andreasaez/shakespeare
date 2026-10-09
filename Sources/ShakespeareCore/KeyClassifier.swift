import Foundation

public enum KeyKind: Equatable {
    case letter
    case space
    /// Digits, punctuation, arrows, shortcuts, function keys, etc.
    case other
    /// Quit and close shortcuts (⌘Q, ⌘W). Housekeeping, not typing: not counted at all.
    case ignored

    /// Letters and space are the only keys that count toward WPM.
    public var countsTowardWPM: Bool { self == .letter || self == .space }
}

/// Classifies a key by its hardware key code. A key code identifies a key, and on a
/// known layout that is a letter, so it is reduced straight away to a coarse class
/// (letter, space, other, ignored) and never stored. What protects typed text is that
/// nothing downstream keeps key identity or order; see
/// `testStoredStatsDoNotDependOnWhichKeysWereTyped`.
public enum KeyClassifier {
    // Virtual key codes for the 26 letter keys (ANSI positions).
    private static let letterCodes: Set<Int> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17,
        31, 32, 34, 35, 37, 38, 40, 45, 46,
    ]
    private static let spaceCode = 49
    private static let quitCode = 12   // Q
    private static let closeCode = 13  // W

    /// - Parameters:
    ///   - hasShortcutModifier: true when ⌘, ⌃ or ⌥ is held, which makes the keypress a
    ///     shortcut rather than typing.
    ///   - hasCommand: true when ⌘ is held. ⌘Q and ⌘W (with or without ⇧/⌥) quit apps and
    ///     close windows, so they're ignored entirely. Like the letter keys, this follows
    ///     key positions, so it matches US-layout shortcuts.
    public static func kind(keyCode: Int, hasShortcutModifier: Bool, hasCommand: Bool = false) -> KeyKind {
        if hasCommand, keyCode == quitCode || keyCode == closeCode { return .ignored }
        if hasShortcutModifier { return .other }
        if keyCode == spaceCode { return .space }
        return letterCodes.contains(keyCode) ? .letter : .other
    }
}
