#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/wezterm-osc52.rb" >&2
  exit 2
fi

CASK=$1
if [[ ! -f "$CASK" ]]; then
  echo "Cask does not exist: $CASK" >&2
  exit 1
fi
CASK=$(cd "$(dirname "$CASK")" && pwd)/$(basename "$CASK")

UPSTREAM_LINE_COUNT=$(grep -Ec '^[[:space:]]*# Upstream WezTerm commit: [0-9a-f]{40}$' "$CASK" || true)
if [[ "$UPSTREAM_LINE_COUNT" -ne 1 ]]; then
  echo "Cask must contain exactly one full upstream commit comment" >&2
  exit 1
fi
if [[ -n "${EXPECTED_UPSTREAM_SHA:-}" ]] && ! grep -Eq "^[[:space:]]*# Upstream WezTerm commit: ${EXPECTED_UPSTREAM_SHA}$" "$CASK"; then
  echo "Cask upstream commit comment does not match EXPECTED_UPSTREAM_SHA" >&2
  exit 1
fi

ruby -c "$CASK"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable; skipped cask style validation" >&2
  exit 0
fi

# Homebrew requires casks under a tap for style checks. Stage the candidate in
# the canonical tap checkout, then restore its original file. Never force-untap
# a temporary tap: Homebrew interprets that as permission to uninstall any
# installed cask whose token appears in the tap.
TAP=ldelossa/wezterm-osc52
brew tap "$TAP" >/dev/null
TAP_DIR=$(brew --repository "$TAP")
TARGET="$TAP_DIR/Casks/wezterm-osc52.rb"
BACKUP=$(mktemp "${TMPDIR:-/tmp}/wezterm-osc52-cask-backup.XXXXXX")
cp "$TARGET" "$BACKUP"
cleanup() {
  cp "$BACKUP" "$TARGET"
  rm -f "$BACKUP"
}
trap cleanup EXIT

cp "$CASK" "$TARGET"
brew style --cask "$TAP/wezterm-osc52"
