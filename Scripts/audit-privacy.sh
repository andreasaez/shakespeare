#!/usr/bin/env bash
# Fails if the source starts to do anything that would break Shakespeare's
# privacy promises: reaching the network, or reading typed characters.
# Run by CI and `make audit`.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
check() { # description, regex
  if grep -rnE --include='*.swift' "$2" Sources; then
    echo "✗ $1"; fail=1
  fi
}

check "networking APIs are forbidden (the app must work fully offline)" \
  'URLSession|URLRequest|NWConnection|NWPathMonitor|CFNetwork|CFStream|WKWebView|import WebKit|import Network|Process\(\)|NSURLConnection|https?://[a-z]'
check "reading typed characters is forbidden (key codes only)" \
  'keyboardEventUnicode|charactersIgnoringModifiers|\.characters\b|keyboardGetUnicodeString|UCKeyTranslate|TISGetInputSource|NSEvent\.addGlobalMonitor|NSEvent\.addLocalMonitor|\.leftMouseDown|\.keyUp'
check "analytics/telemetry SDKs are forbidden" \
  'PostHog|Sentry|Firebase|Mixpanel|Amplitude|Telemetry'

check "running other programs or dynamic code is forbidden" \
  'NSAppleScript|osascript|NSTask|posix_spawn|popen\(|(^|[^.A-Za-z_])system\(|dlopen|dlsym|NSExpression|JavaScriptCore|evaluateJavaScript'

# Build and install scripts must not download or run anything from the internet.
if grep -nE 'curl|wget|git clone|npm |pip |brew |nc -|bash -c|eval ' Scripts/build-app.sh Scripts/install.sh; then
  echo "✗ build/install scripts must not fetch or evaluate remote content"; fail=1
fi

# The package must stay dependency-free.
if grep -nE '\.package\(' Package.swift; then
  echo "✗ third-party Swift packages are forbidden (zero-dependency policy)"; fail=1
fi

if grep -q 'com.apple.security.network' -r Resources 2>/dev/null; then
  echo "✗ network entitlement present"; fail=1
fi

[ "$fail" -eq 0 ] && echo "✓ privacy audit passed"
exit "$fail"
