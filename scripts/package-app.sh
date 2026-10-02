#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Glance…"
swift build -c release --product Glance

BIN="$(swift build -c release --show-bin-path)/Glance"
APP="$ROOT/dist/Glance.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Glance"
cp "$ROOT/Glance/Info.plist" "$APP/Contents/Info.plist"

ICON="$ROOT/Glance/AppIcon.icns"
if [[ ! -f "$ICON" ]]; then
  echo "Missing canonical icon at $ICON" >&2
  exit 1
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc sign so Gatekeeper doesn't immediately kill a local debug build.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Packed $APP"
echo "Run with: open \"$APP\""
