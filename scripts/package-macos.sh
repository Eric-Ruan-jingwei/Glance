#!/bin/zsh
set -euo pipefail

# Local / CI packaging. Assembles dist/Glance.app with an ad-hoc signature.
# This is not a notarized or Developer ID release.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Glance (release)…"
swift build -c release --product Glance

BIN="$(swift build -c release --show-bin-path)/Glance"
APP="$ROOT/dist/Glance.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Glance"
chmod +x "$APP/Contents/MacOS/Glance"
cp "$ROOT/Glance/Info.plist" "$APP/Contents/Info.plist"

ICON="$ROOT/Glance/AppIcon.icns"
if [[ ! -f "$ICON" ]]; then
  echo "Missing canonical icon at $ICON" >&2
  exit 1
fi
cp "$ICON" "$APP/Contents/Resources/AppIcon.icns"

if ! command -v codesign >/dev/null 2>&1; then
  echo "codesign is required for local/CI packaging" >&2
  exit 1
fi
codesign --force --sign - "$APP"

echo "Packed $APP"
echo "Local/CI app (ad-hoc signed, not notarized): open \"$APP\""
