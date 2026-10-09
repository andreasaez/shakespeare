#!/usr/bin/env bash
# Builds dist/Shakespeare.app from source. No Xcode project or Apple developer
# account needed, just the Xcode command line tools.
#
#   BUNDLE_ID   override the bundle identifier (default below)
#   UNIVERSAL   set to 1 for an Apple Silicon + Intel binary (needs full Xcode; default: this Mac only)
#   SIGN_ID     codesign identity. Default: the first "Apple Development" or
#               "Developer ID Application" certificate in your keychain, else
#               "-" (ad-hoc). A real certificate keeps the Input Monitoring
#               permission across rebuilds; ad-hoc signing does not.
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
if [ -z "${SIGN_ID:-}" ]; then
  SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development|Developer ID Application/ { print $2; exit }')"
  SIGN_ID="${SIGN_ID:--}"
fi
VERSION="$(cat VERSION)"
APP="dist/Shakespeare.app"

# These values are written into Info.plist and used with sed/codesign: accept only safe shapes.
if ! [[ "$BUNDLE_ID" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; then
  echo "Invalid BUNDLE_ID '$BUNDLE_ID' (letters, digits, dots and hyphens only)." >&2; exit 1
fi
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid VERSION '$VERSION' (expected x.y.z)." >&2; exit 1
fi

# The only third-party file in the app is the Inter font. Refuse to bundle it if it changed.
(cd Resources/Fonts && shasum -a 256 -c --quiet SHA256SUMS) || {
  echo "Font checksum mismatch: Resources/Fonts does not match SHA256SUMS." >&2; exit 1; }

# Build for this Mac's own architecture. That works with just the Xcode Command Line Tools.
# A universal binary (Apple Silicon + Intel, for sharing a built app) needs full Xcode:
#   UNIVERSAL=1 ./Scripts/build-app.sh
ARCH_FLAGS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Shakespeare"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Shakespeare"
cp -R Resources/Fonts "$APP/Contents/Resources/Fonts"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
sed -e "s/__BUNDLE_ID__/$BUNDLE_ID/" -e "s/__VERSION__/$VERSION/" \
    Resources/Info.plist.in > "$APP/Contents/Info.plist"

# Hardened runtime, no entitlements: the app needs none (no network, no files
# outside its own Application Support folder).
codesign --force --sign "$SIGN_ID" --options runtime --identifier "$BUNDLE_ID" "$APP"
codesign --verify --strict "$APP"

echo "Built $APP (v$VERSION, signed: $SIGN_ID)"
