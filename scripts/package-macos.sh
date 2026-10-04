#!/bin/zsh
set -euo pipefail

# Local / CI packaging. Assembles dist/Glance.app with an ad-hoc signature.
# This is not a notarized or Developer ID release.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Glance (release, Universal 2)…"
swift build -c release --arch arm64 --arch x86_64 --product Glance

BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path --product Glance)/Glance"
APP="$ROOT/dist/Glance.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Glance"
chmod +x "$APP/Contents/MacOS/Glance"
cp "$ROOT/Glance/Info.plist" "$APP/Contents/Info.plist"

ARCHS="$(lipo -archs "$APP/Contents/MacOS/Glance")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
  echo "Packaged Glance binary must be Universal 2 (arm64 x86_64), got: ${ARCHS}" >&2
  exit 1
fi

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
