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

ruby -c "$CASK"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is unavailable; skipped cask style validation" >&2
  exit 0
fi

TAP="wezterm-osc52-ci/style-${GITHUB_RUN_ID:-local}-$$"
brew tap-new --no-git "$TAP" >/dev/null
cleanup() {
  brew untap --force "$TAP" >/dev/null 2>&1 || true
}
trap cleanup EXIT

TAP_DIR=$(brew --repository "$TAP")
mkdir -p "$TAP_DIR/Casks"
cp "$CASK" "$TAP_DIR/Casks/wezterm-osc52.rb"
brew style --cask "$TAP/wezterm-osc52"
