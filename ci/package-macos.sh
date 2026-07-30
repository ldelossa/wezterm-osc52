#!/bin/bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
  echo "This script must run on macOS" >&2
  exit 1
fi

VERSION=${VERSION:-"$(ci/tag-name.sh)-osc52.1"}
TARGET_DIR=${TARGET_DIR:-target}
OUTPUT_DIR=${OUTPUT_DIR:-dist}
SIGN_IDENTITY=${SIGN_IDENTITY:--}
NOTARY_PROFILE=${NOTARY_PROFILE:-}
PACKAGED_BINS=(wezterm wezterm-gui wezterm-mux-server strip-ansi-escapes)
ARCHES=(aarch64-apple-darwin x86_64-apple-darwin)

if [[ ! "$VERSION" =~ ^[0-9A-Za-z._-]+$ ]]; then
  echo "VERSION contains unsupported characters: $VERSION" >&2
  exit 2
fi
if [[ ! -s .upstream-sha ]] || ! grep -Eq '^[0-9a-f]{40}$' .upstream-sha; then
  echo ".upstream-sha must contain one full Git commit SHA" >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(cd "$OUTPUT_DIR" && pwd)
STAGING=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-osc52-package.XXXXXX")
APP="$STAGING/WezTerm.app"
ARCHIVE="$OUTPUT_DIR/WezTerm-macos-$VERSION.zip"
CHECKSUM="$ARCHIVE.sha256"
trap 'rm -rf "$STAGING"' EXIT

# Assemble the drop-in app while retaining the downstream bundle identifier.
ditto assets/macos/WezTerm.app "$APP"
rm -f "$APP"/*.dylib
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto assets/shell-integration "$APP/Contents/Resources"
ditto assets/shell-completion "$APP/Contents/Resources/shell-completion"
tic -xe wezterm -o "$APP/Contents/Resources/terminfo" termwiz/data/wezterm.terminfo

for bin in "${PACKAGED_BINS[@]}"; do
  inputs=()
  for arch in "${ARCHES[@]}"; do
    input="$TARGET_DIR/$arch/release/$bin"
    if [[ ! -x "$input" ]]; then
      echo "Missing release binary: $input" >&2
      exit 1
    fi
    inputs+=("$input")
  done
  lipo -create "${inputs[@]}" -output "$APP/Contents/MacOS/$bin"
done

if [[ "$VERSION" =~ ^([0-9]{4})([0-9]{2})([0-9]{2}) ]]; then
  BUNDLE_VERSION="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
else
  BUNDLE_VERSION="0.1.0"
fi
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $BUNDLE_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$PLIST"

DOWNSTREAM_SHA=$(git rev-parse HEAD)
UPSTREAM_SHA=$(tr -d '\n' <.upstream-sha)
cat >"$APP/Contents/Resources/wezterm-osc52-release.json" <<EOF
{
  "version": "$VERSION",
  "upstream_sha": "$UPSTREAM_SHA",
  "downstream_sha": "$DOWNSTREAM_SHA",
  "repository": "https://github.com/ldelossa/wezterm-osc52",
  "unofficial": true
}
EOF

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --options runtime --entitlements ci/macos-entitlement.plist \
    --deep --sign - "$APP"
else
  codesign --force --options runtime --timestamp \
    --entitlements ci/macos-entitlement.plist --deep \
    --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --keepParent "$APP" "$ARCHIVE"

NOTARIZED=0
if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Notarization requires a Developer ID signature" >&2
    exit 2
  fi
  xcrun notarytool submit "$ARCHIVE" --wait --keychain-profile "$NOTARY_PROFILE"
  NOTARIZED=1
elif [[ -n "${MACOS_APPLE_ID:-}" || -n "${MACOS_APP_PASSWORD:-}" || -n "${MACOS_TEAM_ID:-}" ]]; then
  if [[ -z "${MACOS_APPLE_ID:-}" || -z "${MACOS_APP_PASSWORD:-}" || -z "${MACOS_TEAM_ID:-}" ]]; then
    echo "MACOS_APPLE_ID, MACOS_APP_PASSWORD, and MACOS_TEAM_ID are all required" >&2
    exit 2
  fi
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Notarization requires a Developer ID signature" >&2
    exit 2
  fi
  xcrun notarytool submit "$ARCHIVE" --wait \
    --apple-id "$MACOS_APPLE_ID" \
    --password "$MACOS_APP_PASSWORD" \
    --team-id "$MACOS_TEAM_ID"
  NOTARIZED=1
fi

if [[ $NOTARIZED -eq 1 ]]; then
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
  rm -f "$ARCHIVE"
  ditto -c -k --keepParent "$APP" "$ARCHIVE"
fi

shasum -a 256 "$ARCHIVE" >"$CHECKSUM"
REQUIRE_NOTARIZATION=$NOTARIZED ci/verify-macos-package.sh "$ARCHIVE"
printf 'Package: %s\nChecksum: %s\n' "$ARCHIVE" "$CHECKSUM"
