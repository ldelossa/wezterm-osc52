#!/bin/bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
  echo "This script must run on macOS" >&2
  exit 1
fi
if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/WezTerm-macos-VERSION.zip" >&2
  exit 2
fi

ARCHIVE=$1
REQUIRE_NOTARIZATION=${REQUIRE_NOTARIZATION:-0}
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-osc52-verify.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT

ditto -x -k "$ARCHIVE" "$STAGING"
if [[ $(find "$STAGING" -mindepth 1 -maxdepth 1 -print | wc -l | tr -d ' ') -ne 1 ]]; then
  echo "Archive must contain exactly one top-level entry" >&2
  exit 1
fi

APP="$STAGING/WezTerm.app"
PLIST="$APP/Contents/Info.plist"
test -d "$APP"
plutil -lint "$PLIST" >/dev/null
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$PLIST") == "WezTerm" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$PLIST") == "WezTerm" ]]
[[ $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST") == "com.github.ldelossa.wezterm-osc52" ]]

for bin in wezterm wezterm-gui wezterm-mux-server strip-ansi-escapes; do
  path="$APP/Contents/MacOS/$bin"
  test -x "$path"
  arches=$(lipo -archs "$path")
  [[ " $arches " == *" arm64 "* ]]
  [[ " $arches " == *" x86_64 "* ]]
done

MANIFEST="$APP/Contents/Resources/wezterm-osc52-release.json"
python3 - "$MANIFEST" <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    manifest = json.load(source)
assert manifest["unofficial"] is True
assert manifest["repository"] == "https://github.com/ldelossa/wezterm-osc52"
assert re.fullmatch(r"[0-9a-f]{40}", manifest["upstream_sha"])
assert re.fullmatch(r"[0-9a-f]{40}", manifest["downstream_sha"])
assert manifest["version"]
PY

VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$MANIFEST")
"$APP/Contents/MacOS/wezterm" --version | grep -F -- "$VERSION" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP"

if [[ "$REQUIRE_NOTARIZATION" == "1" ]]; then
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi

printf 'Verified universal WezTerm package %s\n' "$VERSION"
