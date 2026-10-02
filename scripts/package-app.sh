#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Glance…"
swift build -c release --product Glance

BIN="$(swift build -c release --show-bin-path)/Glance"
APP="$ROOT/dist/Glance.app"

python3 "$ROOT/scripts/generate-icon.py"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Glance"
cp "$ROOT/Glance/Info.plist" "$APP/Contents/Info.plist"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
elif [[ -f "$ROOT/Resources/AppIcon.png" ]]; then
  cp "$ROOT/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.png"
fi

# Ad-hoc sign so Gatekeeper doesn't immediately kill a local debug build.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "Packed $APP"
echo "Run with: open \"$APP\""
