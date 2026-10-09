# Shakespeare ✒️

Fun keyboard stats in your Mac menu bar. Private by construction: it counts key presses, never what you type, and never touches the network.

- **Today and the last 14 days.** The menu opens on today's number; hover any bar for that day's count.
- **A streak that means typing.** Days with 50+ keys.
- **Honest typing speed.** Best sustained WPM over a full minute, letters and space only. Shortcuts and arrows don't count, and quitting or closing (⌘Q, ⌘W) isn't counted at all.
- **Fun facts.** Your busiest hour, how far your keys have travelled, how many *Hamlets* you've typed.
- **Top apps (optional, off by default).** Where you type most. Toggle it any time; turning it off erases stored app names.
- **Share cards, mechanical keyboard meets Shakespeare.** Nine keyboard colourways drawn as a real 75% board (*Quarto*, *Elsinore*, *Falstaff*, *Juliet*, *Tudor Rose*, *Arden*, *Venice*, plus retro *Phosphor* and *Synthwave*), with a soft bloom, solid or one of nine patterns (*Manuscript*, *Damask*, *Fleur-de-lis* … *Retro Grid*, *CRT Scanlines*, *Halftone*) behind it. Rendered on your Mac; you choose where to post.
- **Your menu, your look.** Light Inter type and keycap-style tiles. Follows macOS light/dark by default, or pick any colourway under Settings → Appearance.

## Install (from source)

Requires macOS 14 or later and the Xcode Command Line Tools (`xcode-select --install`). The full Xcode app is **not** needed. It builds for your own Mac (Apple Silicon or Intel).

```sh
git clone https://github.com/andreasaez/shakespeare.git
cd shakespeare
make install
```

`make install` is a guided installer. It runs the privacy audit, builds, signs, copies the app to `~/Applications`, launches it, and opens the macOS page where you grant the one permission it needs. Then:

1. In **System Settings → Privacy & Security → Input Monitoring**, turn on **Shakespeare**.
2. If the menu says **Restart to start counting**, click **Restart Shakespeare**.
3. Type something. The number in the menu bar goes up.

### Keep the permission across rebuilds

macOS ties the Input Monitoring permission to the app's code signature.

- **With a signing certificate** (recommended, free): the installer finds it automatically and the permission survives rebuilds. To create one, open Xcode → Settings → Accounts, add your Apple ID, then *Manage Certificates → + → Apple Development*.
- **Without one**: the app is ad-hoc signed and macOS forgets the permission on every rebuild. The installer clears the stale entry for you, so you just turn the switch on again.

If the app is running, shows no warning, but isn't counting, the permission has gone stale: run `make install` again, or reset it with `tccutil reset ListenEvent "$(defaults read ~/Applications/Shakespeare.app/Contents/Info CFBundleIdentifier)"` and allow it again.

Other commands: `UNIVERSAL=1 make app` (an Apple Silicon + Intel build for sharing; needs full Xcode), `make run` (debug run), `make test`, `make audit`, `make app` (build only, into `dist/`), `make clean`. Environment options: `BUNDLE_ID=com.you.shakespeare` for your own app identifier and `SIGN_ID="Apple Development: …"` to choose a certificate. To avoid retyping them, put those lines in a `.env` file in the repo folder (it is git-ignored).

## Update

From the folder you cloned:

```sh
git fetch
git log --oneline HEAD..origin/main     # what's new
git diff --stat HEAD origin/main        # which files changed (read them if you like)
git pull --ff-only
make install
```

`make install` quits the running app, rebuilds, replaces `~/Applications/Shakespeare.app` and reopens it. Your stats, badges and settings are kept. If you build with a signing certificate, the Input Monitoring permission carries over; with ad-hoc signing macOS asks you to allow it again, and the installer opens the right page. `make verify` reruns the safety checks on the new build.

## Uninstall

Nothing else is installed on your Mac, so removal is a few deletions. The commands read your app's identifier from the installed app, so they work for any build.

1. **Turn off "Launch at login"** in the app's Settings tab, then quit it (Settings, then Quit, or `pkill -x Shakespeare`). If you skip this, remove the stale entry in System Settings, General, Login Items & Extensions.
2. **Remove the permission, settings, app and data.** Run these in order, because the first line reads the identifier from the app before the app is deleted:

   ```sh
   BUNDLE_ID="$(defaults read ~/Applications/Shakespeare.app/Contents/Info CFBundleIdentifier)"
   tccutil reset ListenEvent "$BUNDLE_ID"                  # Input Monitoring permission
   defaults delete "$BUNDLE_ID"                            # theme and other settings
   rm -rf ~/Applications/Shakespeare.app
   rm -rf ~/Library/Application\ Support/Shakespeare       # your stats and badges
   ```

   You can also remove the permission by hand: System Settings, Privacy & Security, Input Monitoring, select Shakespeare and click the minus button.
3. **Delete the cloned repo folder** if you no longer want the source.

Want to keep the app but erase your numbers? Use **Settings, Delete all data** in the app instead.

## Privacy

Short version: only per-day counters are stored, in `~/Library/Application Support/Shakespeare/stats.json` (owner-only permissions). Full details and limits in [PRIVACY.md](PRIVACY.md); security notes in [SECURITY.md](SECURITY.md). CI enforces the promises via `Scripts/audit-privacy.sh`.

## Credits

Typeset in [Inter](https://rsms.me/inter/) v4.1 (SIL Open Font License; see `Resources/Fonts/Inter-OFL.txt`), bundled in the app so nothing is fetched at runtime. The font's SHA-256 is recorded in `Resources/Fonts/SHA256SUMS` and checked at build time.

## Layout

```
Sources/ShakespeareCore   logic: key classification, WPM, stats, storage (unit-tested)
Sources/Shakespeare       SwiftUI menu bar app, key monitor, share cards
Scripts/                  build-app.sh (bundle + sign), install.sh, audit-privacy.sh,
                          make-icon.swift (redraws Resources/AppIcon.icns in code)
```

## Contributions

This is a personal project and I'm not accepting pull requests. Fork it, change anything and install your own version. MIT licensed; see [CONTRIBUTING.md](CONTRIBUTING.md).
