#!/bin/zsh
set -euo pipefail

# Beta distribution artifacts (ZIP + DMG + SHA256SUMS).
# Ad-hoc signed only. Not Developer ID. Not notarized. Does not publish.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
APP="$DIST/Glance.app"
STAGE=""
ZIP_EXTRACT=""
MOUNT=""

cleanup() {
  if [[ -n "${MOUNT:-}" && -d "$MOUNT" ]]; then
    hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  fi
  if [[ -n "${STAGE:-}" && -d "$STAGE" ]]; then
    rm -rf "$STAGE"
  fi
  if [[ -n "${ZIP_EXTRACT:-}" && -d "$ZIP_EXTRACT" ]]; then
    rm -rf "$ZIP_EXTRACT"
  fi
}
trap cleanup EXIT

plist_string() {
  local file="$1"
  local key="$2"
  local value
  value="$(/usr/libexec/PlistBuddy -c "Print :${key}" "$file")"
  value="${value//$'\t'/}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

verify_app() {
  local bundle="$1"
  local label="$2"
  local info="$bundle/Contents/Info.plist"
  local binary="$bundle/Contents/MacOS/Glance"
  local icon="$bundle/Contents/Resources/AppIcon.icns"

  test -d "$bundle"
  test -f "$info"
  test -x "$binary"
  test -f "$icon"

  local marketing build identifier prohibited
  marketing="$(plist_string "$info" CFBundleShortVersionString)"
  build="$(plist_string "$info" CFBundleVersion)"
  identifier="$(plist_string "$info" CFBundleIdentifier)"
  prohibited="$(plist_string "$info" LSMultipleInstancesProhibited)"

  if [[ "$identifier" != "com.glance.app" ]]; then
    echo "${label}: expected bundle id com.glance.app, got ${identifier}" >&2
    exit 1
  fi
  if [[ "$marketing" != "$VERSION" || "$build" != "$BUILD" ]]; then
    echo "${label}: expected ${VERSION} / ${BUILD}, got ${marketing} / ${build}" >&2
    exit 1
  fi
  if [[ "$prohibited" != "true" ]]; then
    echo "${label}: LSMultipleInstancesProhibited must be true" >&2
    exit 1
  fi
}

SOURCE_PLIST="$ROOT/Glance/Info.plist"
VERSION="$(plist_string "$SOURCE_PLIST" CFBundleShortVersionString)"
BUILD="$(plist_string "$SOURCE_PLIST" CFBundleVersion)"
ZIP="$DIST/Glance-${VERSION}.zip"
DMG="$DIST/Glance-${VERSION}.dmg"
SUMS="$DIST/SHA256SUMS"

mkdir -p "$DIST"
rm -rf "$APP"
rm -f "$ZIP" "$DMG" "$SUMS"

"$ROOT/scripts/package-macos.sh"

verify_app "$APP" "assembled Glance.app"

codesign --force --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/GlanceDistStage.XXXXXX")"
ditto "$APP" "$STAGE/Glance.app"
ln -s /Applications "$STAGE/Applications"
if [[ ! -L "$STAGE/Applications" ]]; then
  echo "Failed to create Applications symlink in DMG staging" >&2
  exit 1
fi

hdiutil create \
  -ov \
  -format UDZO \
  -volname "Glance" \
  -srcfolder "$STAGE" \
  "$DMG" >/dev/null

(
  cd "$DIST"
  shasum -a 256 "Glance-${VERSION}.dmg" "Glance-${VERSION}.zip" > SHA256SUMS
  shasum -a 256 -c SHA256SUMS
)

ZIP_EXTRACT="$(mktemp -d "${TMPDIR:-/tmp}/GlanceDistZip.XXXXXX")"
ditto -x -k "$ZIP" "$ZIP_EXTRACT"
verify_app "$ZIP_EXTRACT/Glance.app" "distribution ZIP"

MOUNT="$(mktemp -d "${TMPDIR:-/tmp}/GlanceDistMount.XXXXXX")"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" >/dev/null
verify_app "$MOUNT/Glance.app" "distribution DMG"
if [[ ! -L "$MOUNT/Applications" ]]; then
  echo "DMG is missing Applications symlink" >&2
  exit 1
fi
if [[ "$(readlink "$MOUNT/Applications")" != "/Applications" ]]; then
  echo "DMG Applications symlink must point at /Applications" >&2
  exit 1
fi
hdiutil detach "$MOUNT" >/dev/null
rmdir "$MOUNT"
MOUNT=""

echo
echo "NOTE: This beta artifact is ad-hoc signed and is not notarized."
echo "Gatekeeper rejection is expected for external distribution."
if command -v spctl >/dev/null 2>&1; then
  spctl --assess --verbose "$APP" >/dev/null 2>&1 || true
fi

echo
echo "Glance distribution artifacts ready:"
echo
echo "Version: ${VERSION}"
echo "Build: ${BUILD}"
echo
echo "dist/Glance-${VERSION}.dmg"
echo "dist/Glance-${VERSION}.zip"
echo "dist/SHA256SUMS"
echo
echo "Signing: ad-hoc"
echo "Notarization: none"
