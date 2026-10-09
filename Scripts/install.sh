#!/usr/bin/env bash
# One-step installer: build, sign, install to ~/Applications, launch, and walk
# you through the one permission macOS needs (Input Monitoring).
set -euo pipefail
cd "$(dirname "$0")/.."

# Optional local overrides: a git-ignored `.env` file may contain BUNDLE_ID=... and SIGN_ID=...
# (only those two keys are read, and real environment variables win). This keeps personal
# values out of the repository.
for key in BUNDLE_ID SIGN_ID; do
  if [ -z "${!key:-}" ] && [ -f .env ]; then
    val="$(grep -E "^${key}=" .env | tail -1 | cut -d= -f2- || true)"   # a missing key is fine
    if [ -n "$val" ]; then export "$key=$val"; fi
  fi
done
BUNDLE_ID="${BUNDLE_ID:-dev.shakespeare.keystats}"
export BUNDLE_ID
DEST="$HOME/Applications/Shakespeare.app"

# We delete and recreate $DEST, so be certain what it is.
if [ -z "${HOME:-}" ] || [ "$HOME" = "/" ] || [ "$DEST" != "$HOME/Applications/Shakespeare.app" ]; then
  echo "Refusing to install: HOME looks wrong ('${HOME:-}')." >&2; exit 1
fi
if ! [[ "$BUNDLE_ID" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "Invalid BUNDLE_ID '$BUNDLE_ID' (letters, digits, dots and hyphens only)." >&2; exit 1
fi

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

say "1/5  Checking your Mac"
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$MACOS_MAJOR" -lt 14 ]; then
  echo "Shakespeare needs macOS 14 (Sonoma) or later; this Mac has $(sw_vers -productVersion)." >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null; then
  echo "The Xcode Command Line Tools are missing (the full Xcode app is not needed)."
  echo "Install them with:  xcode-select --install   then run this again."
  exit 1
fi
if ! SWIFT_VERSION_LINE="$(swift --version 2>&1 | head -1)" || [[ "$SWIFT_VERSION_LINE" == *"license"* ]]; then
  echo "Swift won't run: $SWIFT_VERSION_LINE" >&2
  echo "If that mentions the Xcode license, run:  sudo xcodebuild -license accept" >&2
  exit 1
fi
echo "macOS $(sw_vers -productVersion), $(uname -m), $(echo "$SWIFT_VERSION_LINE" | sed -E 's/.*Swift version ([0-9.]+).*/Swift \1/')"

say "2/5  Privacy audit"
./Scripts/audit-privacy.sh

say "3/5  Building"
pkill -x Shakespeare 2>/dev/null || true
BUILD_LOG="$(./Scripts/build-app.sh 2>&1 | tee /dev/stderr)"
if echo "$BUILD_LOG" | grep -q 'signed: -$'; then
  ADHOC=1
  echo
  echo "⚠️  No signing certificate found, so the app is ad-hoc signed."
  echo "   macOS forgets the Input Monitoring permission every time you rebuild."
  echo "   To avoid that: Xcode → Settings → Accounts → add your Apple ID (free),"
  echo "   then 'Manage Certificates' → + → Apple Development. Re-run this script."
else
  ADHOC=0
fi

say "4/5  Installing to ~/Applications"
mkdir -p "$HOME/Applications"
FIRST_INSTALL=0
[ -d "$DEST" ] || FIRST_INSTALL=1
rm -rf "$DEST"
cp -R dist/Shakespeare.app "$DEST"

# An ad-hoc rebuild invalidates any earlier grant: macOS still lists the app as
# allowed but delivers no key events. Clear the stale entry so you re-grant cleanly.
if [ "$ADHOC" -eq 1 ]; then
  tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

say "5/5  Launching"
open "$DEST"

if [ "$FIRST_INSTALL" -eq 0 ] && [ "$ADHOC" -eq 0 ]; then
  echo
  echo "Updated. Your Input Monitoring permission carries over (signed build)."
  echo "If the menu still asks for permission, open it and follow the prompt."
  exit 0
fi

sleep 1
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true

cat <<MSG

Almost done. Shakespeare counts key presses, so macOS needs your OK once:

  1. In the System Settings window that just opened (Privacy & Security →
     Input Monitoring), turn ON "Shakespeare".
  2. If the Shakespeare menu says "Restart to start counting", click
     "Restart Shakespeare".
  3. Type something. The number in your menu bar should go up.

Shakespeare never records what you type; see PRIVACY.md.
MSG
