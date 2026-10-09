# Security

Shakespeare is a small local app: it counts key presses on your Mac and draws share cards. It has no server, no account and no network access, so the attack surface is deliberately tiny.

## What it does and doesn't do
- **Reads** the key code and modifier flags of each key press through a *listen-only* event tap (it can't modify, block or inject keys). A key code identifies the key, so it is reduced to letter, space or other and discarded in one function (`AppModel.handle`). Only counters are kept on disk, and about 60 seconds of anonymous press timestamps (no key identity) stay in memory for the speed readout.
- **Writes** one file, `~/Library/Application Support/Shakespeare/stats.json` (folder `0700`, file `0600`), plus a PNG only when you choose a location in a save panel.
- **Never**: opens network connections, runs other programs, runs scripts or downloaded code, loads plugins, or reads files you didn't give it. There are no third-party dependencies.
- Signed with the hardened runtime and **no entitlements**.

## Defences you can verify
| Risk | Defence | Where |
|---|---|---|
| Data leaves your Mac | No networking code; CI fails if networking, telemetry or character-reading APIs appear | `Scripts/audit-privacy.sh` |
| Code runs that you didn't write | No dependencies; CI fails on new packages or on `Process`, AppleScript, `dlopen` etc. | `audit-privacy.sh`, `Package.swift` |
| A tampered or damaged `stats.json` crashes or bloats the app | The file is size-capped, then validated and clamped on load (bad dates dropped, arrays repaired, numbers bounded, names truncated) | `StatsData.sanitized()`, tests `testTamperedStatsFileCannotCrashTheApp` |
| Cards leak hidden metadata | Exported PNGs are rebuilt with only the essential chunks (no EXIF, text or timestamps); malformed input fails closed | `PNGScrubber`, tests |
| Something floods the app with fake key events | The speed tracker's buffer is capped and stored speed is clamped, so memory and CPU stay bounded | `WPMTracker`, `testKeyFloodIsBounded` |
| Memory/undefined-behaviour bugs | Tests run clean under AddressSanitizer and UBSan, including a seeded fuzz of 400 hostile stats files | `testSeededFuzzOfStatsFiles` |
| A planted symlink or stale file redirects a write | The temp file is removed and recreated with `O_EXCL \| O_NOFOLLOW` at `0600`, fsynced, then atomically renamed; a folder owned by someone else is refused | `StatsPersistence`, tests `testSaveDoesNotFollowAPlantedSymlink` |
| Two copies run and corrupt or double-count stats | An exclusive `flock` on a private lock file; a second copy waits briefly (so Restart works) and then quits. The system frees the lock if the app crashes | `InstanceLock`, live-tested |
| Invisible or bidi-override characters in app names reorder text in the menu or on cards | Control, format and bidi characters are stripped from app names on load and on record; length and count are capped | `StatsData.cleanAppName` |
| Non-Gregorian system calendars or a wrong clock corrupt day keys | Day keys always use the Gregorian calendar; events dated outside 2000–9999 are ignored | `StatsEngine.defaultCalendar`, tests |
| Log lines misread as format strings | Messages are passed to `NSLog` as arguments, never as the format | `AppModel` |
| `stats.json` swapped for a pipe, `/dev/zero`, a folder or a symlink hangs or exhausts memory at launch | Only a regular, non-symlink file up to 10 MB is read, and never more than that; anything else is moved aside | `StatsPersistence.readBounded`, tests |
| Deeply nested or huge JSON | Nesting is rejected by the decoder (tested at 400,000 levels); at most 20,000 days are kept | `testDeeplyNestedJSONIsRejectedWithoutCrashing` |
| A second copy, or a read-only data folder, makes the app refuse to start silently | A planted lock symlink is replaced; if the lock file can't be created at all the app starts without it, and only a genuinely running copy makes it quit | `InstanceLock` |
| Other users read your stats | Folder `0700` and file `0600`, enforced on every save, atomic write | `StatsPersistence`, tests |
| Build scripts do something unexpected | Inputs (`BUNDLE_ID`, `VERSION`) are validated; the install path is checked before anything is deleted; scripts never download or evaluate remote content | `Scripts/` |
| Tampered font in the bundle | The only third-party file, Inter, is checked against `Resources/Fonts/SHA256SUMS` at build time | `build-app.sh` |
| Compromised CI action | Actions are pinned to a commit SHA, the workflow token is read-only and isn't persisted; Dependabot proposes updates as reviewable PRs | `.github/` |

## Verified on the running app, not just in the source
These were checked against the compiled app and the live system, so they don't depend on trusting this repository's text:
- **The keyboard tap**, as reported by macOS itself (`CGGetEventTapList`): *listen-only* (it can't modify, block or inject events) and an event mask of keyDown only. No key-ups, modifier changes, mouse or scroll events.
- **Open files and sockets** (`lsof`): its lock file, its binary and the bundled font. **0 network sockets, 0 child processes.**
- **Imported symbols** (`nm -u`): no socket, connect, getaddrinfo, fork, exec, posix_spawn, character-translation or code-loading functions. One import deserves a note: `dlsym`. It's called only from `__initializeAvailabilityCheck`, a routine from the compiler's own runtime that reads the OS version from `/System/Library/CoreServices/SystemVersion.plist`. It isn't in this repo's source (the audit bans it there).
- **Bundled font**: byte-identical to a fresh download of Inter 4.1 from its official release.
- **Hidden characters**: none (no bidirectional or zero-width characters in any source file).
- **Git history**: no secrets or personal data; every commit uses a GitHub noreply address.

## Enforcement tests (try it yourself)
macOS can *enforce* "this program never does X" instead of us promising it. These tests run the real app inside `sandbox-exec` with a profile where a violation **kills the process**, so "it survived" means "it never tried". Each was run with a positive control (`curl` is killed under the same profile, an allowed command is not), because a test that can't fail proves nothing.

| Test | Result |
|---|---|
| Any network use fatal; app runs 60 s with its key tap active | survived, 0 sockets |
| Spawning or executing any other program fatal | survived |
| Reading Documents, Desktop, Downloads, Pictures, Keychains, Mail, Messages, Safari, cookies, `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.config` fatal | survived |
| The full unit-test suite (stats loading/saving, lock, PNG export, fuzzers) with network and those reads fatal | 48/48 passed |
| A clean clone built with network use fatal | built; zero dependencies fetched |
| Injecting a malicious dylib with `DYLD_INSERT_LIBRARIES` | **blocked** on the real build and on the ad-hoc build a fork gets; the same attack **succeeds** against a build without the hardened runtime, which is what protects it |
| An app name like `[click](https://evil)` or `%@ %n` | rendered as plain text, never a link |

Run them yourself with `make verify` (`Scripts/verify-local-only.sh`). It quits the app for about a minute, runs the network, spawn, private-folder and injection checks with their controls, and reopens it.

One test result deserves an honest note. Under a profile that forbids *all* writes under your home folder except the app's data folder, caches, saved state and preferences, the app sometimes dies when run from `~/Applications` (8 of 10 runs), but **never** when the identical signed copy runs from outside your home folder (0 of 10). The attempted writes are metadata touches inside the app's own install location and appear only under that restrictive launch; no single file accounts for them. In normal use nothing in the bundle changes: after a 30-second run all 7 files were byte-identical (contents, size, permissions, modification times, extended attributes) and the signature still verified. The source writes only to the app's data folder and to a PNG you choose in a Save dialog.

Gatekeeper's `spctl --assess` reports a locally built app as "rejected" because it isn't notarised by Apple. That's expected for anything built from source and is not a security finding.

## Threat model
In scope: a malformed or hostile `stats.json`, hostile build inputs, and accidental data collection or leaks by future changes.
Out of scope: malware already running as you (it can already read your keystrokes and your files), and a compromised macOS.

## Using it safely
- **Build it yourself.** Anything with Input Monitoring can observe keys; don't grant that to a binary you didn't build from source you've read. This is a ~2,500-line app with no dependencies.
- **Be careful sharing a built `.app`.** A signed build carries your Apple Team ID in its signature. Share source, not binaries.
- **Treat `stats.json` and cards as personal.** They show when and how much you type, and (if you opt in to *Track top apps*) which apps you use.
- Turning *Track top apps* off erases stored app names; **Delete all data…** removes everything.

## Reporting a vulnerability
Use GitHub's **Report a vulnerability** (Security tab → *Report a vulnerability*) on this repo rather than a public issue.

## If you fork it
- Never commit signing certificates, provisioning profiles, `.env` files or exported cards (all are in `.gitignore`).
- Set your commit email to your GitHub **noreply** address (GitHub → Settings → Emails) and enable *Block command line pushes that expose my email*, so your real address isn't published in git history.
- If you add stored fields, keep them to counters, document them in `PRIVACY.md` and cover them with a test, so the privacy promises stay true for your fork.
