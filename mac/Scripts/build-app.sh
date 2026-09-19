#!/bin/bash
# Builds Focus.app. There is no Xcode project: SwiftPM produces the binary and this
# script wraps it in a bundle, which is all a SwiftUI app needs to behave like one
# (a Dock icon, a menu bar, and a window that can take focus).
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Focus.app"

echo "Building ($CONFIG)…"
swift build -c "$CONFIG"

BINARY="$(swift build -c "$CONFIG" --show-bin-path)/Focus"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BINARY" "$APP/Contents/MacOS/Focus"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# An ad-hoc signature is enough to launch locally; sharing the app with anyone else
# needs a Developer ID and notarisation.
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "note: could not sign; the app will still run"

echo "Built $APP"
