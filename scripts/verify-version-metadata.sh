#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$ROOT/Glance/Info.plist"
PBXPROJ="$ROOT/Glance.xcodeproj/project.pbxproj"
PROJECT="$ROOT/Glance.xcodeproj"

fail() {
  echo "Version metadata mismatch:" >&2
  printf '%s\n' "$@" >&2
  exit 1
}

plist_marketing="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
plist_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
plist_marketing="${plist_marketing//$'\t'/}"
plist_marketing="${plist_marketing#"${plist_marketing%%[![:space:]]*}"}"
plist_marketing="${plist_marketing%"${plist_marketing##*[![:space:]]}"}"
plist_build="${plist_build//$'\t'/}"
plist_build="${plist_build#"${plist_build%%[![:space:]]*}"}"
plist_build="${plist_build%"${plist_build##*[![:space:]]}"}"

python3 - "$PBXPROJ" "$plist_marketing" "$plist_build" <<'PY'
import re
import sys

pbxproj, expected_marketing, expected_build = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(pbxproj, encoding="utf-8").read()
pattern = re.compile(
    r"isa = XCBuildConfiguration;\s*buildSettings = \{([^}]+)\};\s*name = (Debug|Release);",
    re.DOTALL,
)
app_configs = {}
for body, name in pattern.findall(text):
    if not re.search(r"INFOPLIST_FILE\s*=\s*Glance/Info\.plist\s*;", body):
        continue
    marketing = re.search(r"MARKETING_VERSION\s*=\s*([^;]+);", body)
    build = re.search(r"CURRENT_PROJECT_VERSION\s*=\s*([^;]+);", body)
    if marketing is None or build is None:
        print(
            "Version metadata mismatch:\n"
            f"Xcode {name} App Target is missing MARKETING_VERSION or CURRENT_PROJECT_VERSION",
            file=sys.stderr,
        )
        sys.exit(1)
    app_configs[name] = (
        marketing.group(1).strip().strip('"'),
        build.group(1).strip().strip('"'),
    )

missing = [name for name in ("Debug", "Release") if name not in app_configs]
if missing or len(app_configs) != 2:
    print(
        "Version metadata mismatch:\n"
        "Expected exactly one Glance App Target Debug and Release configuration "
        "identified by INFOPLIST_FILE = Glance/Info.plist\n"
        f"Found: {sorted(app_configs)}",
        file=sys.stderr,
    )
    sys.exit(1)

errors = [
    f"Info.plist marketing version: {expected_marketing}",
    f"Info.plist build version: {expected_build}",
]
mismatched = False
for name in ("Debug", "Release"):
    marketing, build = app_configs[name]
    errors.append(f"Xcode {name} marketing version: {marketing}")
    errors.append(f"Xcode {name} build version: {build}")
    if marketing != expected_marketing or build != expected_build:
        mismatched = True

if mismatched:
    print("Version metadata mismatch:", file=sys.stderr)
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
PY

xcode_setting() {
  local configuration="$1"
  local key="$2"
  local value
  value="$(
    xcodebuild \
      -project "$PROJECT" \
      -target Glance \
      -configuration "$configuration" \
      -showBuildSettings \
    | awk -v key="$key" '
        $1 == key && $2 == "=" {
          sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+=[[:space:]]+/, "")
          print
        }
      ' \
    | tail -n 1
  )"
  if [[ -z "$value" ]]; then
    fail "Xcode ${configuration} ${key} is missing from -showBuildSettings"
  fi
  print -r -- "$value"
}

debug_marketing="$(xcode_setting Debug MARKETING_VERSION)"
debug_build="$(xcode_setting Debug CURRENT_PROJECT_VERSION)"
release_marketing="$(xcode_setting Release MARKETING_VERSION)"
release_build="$(xcode_setting Release CURRENT_PROJECT_VERSION)"

errors=()
if [[ "$debug_marketing" != "$plist_marketing" || "$release_marketing" != "$plist_marketing" ]]; then
  errors+=(
    "Info.plist marketing version: ${plist_marketing}"
    "Xcode Debug marketing version: ${debug_marketing}"
    "Xcode Release marketing version: ${release_marketing}"
  )
fi
if [[ "$debug_build" != "$plist_build" || "$release_build" != "$plist_build" ]]; then
  errors+=(
    "Info.plist build version: ${plist_build}"
    "Xcode Debug build version: ${debug_build}"
    "Xcode Release build version: ${release_build}"
  )
fi
if (( ${#errors[@]} > 0 )); then
  fail "${errors[@]}"
fi

echo "Version metadata consistent:"
echo "  Info.plist                ${plist_marketing} / ${plist_build}"
echo "  Xcode App Target Debug    ${debug_marketing} / ${debug_build}"
echo "  Xcode App Target Release  ${release_marketing} / ${release_build}"
