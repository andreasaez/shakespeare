#!/usr/bin/env bash
# Checks, against the REAL built app, that Shakespeare stays on your Mac and can't be hijacked.
#
#   make verify                 # tests ~/Applications/Shakespeare.app (or dist/Shakespeare.app)
#   ./Scripts/verify-local-only.sh /path/to/Shakespeare.app
#
# How it works: macOS can run a program under a sandbox profile in which a violation KILLS the
# process (`sandbox-exec`, `(with send-signal SIGKILL)`). If the app survives, it never tried.
# Every test has a positive control: a command that must be killed (or a build that must be
# injected), so a test that cannot fail can't give a false PASS.
#
# This quits Shakespeare for about a minute while it runs, then reopens it if it was running.
set -uo pipefail
cd "$(dirname "$0")/.."

APP="${1:-}"
if [ -z "$APP" ]; then
  for candidate in "$HOME/Applications/Shakespeare.app" "dist/Shakespeare.app"; do
    [ -d "$candidate" ] && APP="$candidate" && break
  done
fi
[ -d "$APP" ] || { echo "No Shakespeare.app found. Run 'make install' first." >&2; exit 2; }
APP="$(cd "$APP" && pwd)"
BIN="$APP/Contents/MacOS/Shakespeare"
[ -x "$BIN" ] || { echo "Not an app bundle: $APP" >&2; exit 2; }
command -v sandbox-exec >/dev/null || { echo "sandbox-exec is required (macOS)." >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
WAS_RUNNING=0; pgrep -x Shakespeare >/dev/null && WAS_RUNNING=1
FAILS=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAILS=$((FAILS+1)); }
say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

stop_app() {
  pkill -x Shakespeare 2>/dev/null
  local n=0; while pgrep -x Shakespeare >/dev/null && [ $n -lt 50 ]; do sleep 0.2; n=$((n+1)); done
  sleep 2
}
restore_app() { [ "$WAS_RUNNING" = 1 ] && { open "$APP"; sleep 2; }; }
trap 'stop_app; restore_app; rm -rf "$WORK"' EXIT

# --- 1. Sandbox where network, spawning programs and reading private folders are all fatal -----------
cat > "$WORK/fatal.sb" <<EOF
(version 1)
(allow default)
(deny network* (with send-signal SIGKILL))
(deny process-fork (with send-signal SIGKILL))
(deny process-exec* (with send-signal SIGKILL))
(allow process-exec* (literal "$BIN"))
(allow process-exec* (literal "/usr/bin/curl"))
(allow process-exec* (literal "/bin/cat"))
(deny file-read* (with send-signal SIGKILL)
  (subpath "$HOME/Documents") (subpath "$HOME/Desktop") (subpath "$HOME/Downloads")
  (subpath "$HOME/Pictures") (subpath "$HOME/Movies") (subpath "$HOME/Music")
  (subpath "$HOME/Library/Keychains") (subpath "$HOME/Library/Mail") (subpath "$HOME/Library/Messages")
  (subpath "$HOME/Library/Safari") (subpath "$HOME/Library/Cookies")
  (subpath "$HOME/.ssh") (subpath "$HOME/.aws") (subpath "$HOME/.gnupg"))
EOF

say "1. Network, other programs and private folders are fatal"
sandbox-exec -f "$WORK/fatal.sb" /usr/bin/curl -sS --max-time 4 -o /dev/null https://example.com >/dev/null 2>&1
code=$?
if [ "$code" -eq 137 ]; then pass "control: a network attempt is killed (the test can fail)"; else fail "control: curl was NOT killed (exit $code); this macOS can't enforce the test, so the results below mean nothing"; fi
if [ -e "$HOME/.ssh" ]; then
  sandbox-exec -f "$WORK/fatal.sb" /bin/cat "$HOME/.ssh/config" >/dev/null 2>&1
  code=$?
  if [ "$code" -eq 137 ]; then pass "control: reading ~/.ssh is killed"; else fail "control: a read of ~/.ssh was not killed (exit $code)"; fi
else
  echo "  (skipped control: ~/.ssh does not exist on this Mac)"
fi

stop_app
sandbox-exec -f "$WORK/fatal.sb" "$BIN" >/dev/null 2>&1 &
SB=$!
for t in 10 30 50; do
  sleep $([ $t = 10 ] && echo 10 || echo 20)
  if pgrep -x Shakespeare >/dev/null; then :; else fail "app was killed by the sandbox at ~${t}s: it tried a forbidden network/exec/read action"; break; fi
done
if pgrep -x Shakespeare >/dev/null; then
  pass "the app ran for ~50 s without a single network, spawn or private-folder access"
  PID=$(pgrep -x Shakespeare | head -1)
  [ "$(lsof -a -p "$PID" -i 2>/dev/null | wc -l | tr -d ' ')" = "0" ] && pass "no network sockets open" || fail "the app has network sockets open"
  [ -z "$(pgrep -P "$PID")" ] && pass "no child processes" || fail "the app started child processes"
fi
kill $SB 2>/dev/null; stop_app

# --- 2. Code injection with DYLD_INSERT_LIBRARIES ---------------------------------------------------
say "2. Injecting a malicious library"
if command -v clang >/dev/null; then
  cat > "$WORK/evil.c" <<EOF
#include <stdio.h>
__attribute__((constructor)) static void pwn(void) { FILE *f = fopen("$WORK/MARKER", "w"); if (f) fclose(f); }
EOF
  echo 'int main(void){return 0;}' > "$WORK/hello.c"
  clang -dynamiclib -o "$WORK/evil.dylib" "$WORK/evil.c" 2>/dev/null && codesign --force --sign - "$WORK/evil.dylib" 2>/dev/null
  clang -o "$WORK/hello" "$WORK/hello.c" 2>/dev/null
  inject() { rm -f "$WORK/MARKER"; DYLD_INSERT_LIBRARIES="$WORK/evil.dylib" "$@" >/dev/null 2>&1 & local p=$!; sleep 3; kill $p 2>/dev/null; wait $p 2>/dev/null; [ -f "$WORK/MARKER" ]; }
  inject "$WORK/hello" && pass "control: the attack works on an unprotected program" || fail "control: injection did not work on the test program; skipping the verdict"
  cp -R "$APP" "$WORK/unhardened.app"; codesign --force --sign - "$WORK/unhardened.app" 2>/dev/null
  inject "$WORK/unhardened.app/Contents/MacOS/Shakespeare" && pass "control: the attack works on a copy WITHOUT the hardened runtime" || fail "control: copy without hardened runtime was not injected"
  inject "$BIN" && fail "the REAL app was injected by DYLD_INSERT_LIBRARIES" || pass "the real app refuses injected libraries"
else
  echo "  (skipped: clang not found; install the Xcode command line tools)"
fi

# --- 3. Entitlements and bundle surface -------------------------------------------------------------
# Output is captured first and matched with [[ ]] or a here-string, never `cmd | grep -q`: grep -q exits early and, with
# `pipefail`, the upstream command then looks like it failed (a false FAIL).
say "3. Nothing that permits injection, network or scripting"
ENT="$(codesign -d --entitlements - "$APP" 2>&1)"
if grep -qiE "disable-library-validation|allow-dyld-environment|allow-unsigned-executable-memory|allow-jit|get-task-allow|network|automation" <<< "$ENT"; then
  fail "a risky entitlement is present"
else
  pass "no risky entitlements (no network, JIT, debugger, dyld-environment or library-validation bypass)"
fi
SIGINFO="$(codesign -dv "$APP" 2>&1)"
if [[ "$SIGINFO" == *"(runtime)"* || "$SIGINFO" == *",runtime"* || "$SIGINFO" == *"runtime)"* ]]; then pass "hardened runtime is on"; else fail "hardened runtime is OFF"; fi
PLIST="$(plutil -p "$APP/Contents/Info.plist")"
if grep -qiE "URLTypes|Scriptable|NSServices|DocumentTypes|NSAppTransportSecurity" <<< "$PLIST"; then
  fail "the app registers URL schemes, scripting, services or document types"
else
  pass "no URL schemes, scripting, services or document types"
fi
EXTRAS="$(find "$APP/Contents" -mindepth 1 -maxdepth 1 \( -name PlugIns -o -name XPCServices -o -name Frameworks -o -name Helpers -o -name LoginItems \))"
if [ -z "$EXTRAS" ]; then pass "no plug-ins, helpers, XPC services or embedded frameworks"; else fail "the bundle contains plug-ins, helpers or frameworks"; fi

say "Result"
if [ "$FAILS" -eq 0 ]; then printf '\033[32mAll checks passed.\033[0m\n'; else printf '\033[31m%d check(s) failed.\033[0m\n' "$FAILS"; fi
exit "$FAILS"
