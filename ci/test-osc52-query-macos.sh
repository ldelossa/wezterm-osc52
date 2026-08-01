#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 '/path/to/WezTerm OSC52.app'" >&2
  exit 2
fi

APP=$1
WEZTERM="$APP/Contents/MacOS/wezterm"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONFIG=$(mktemp "${TMPDIR:-/tmp}/wezterm-osc52-config.XXXXXX.lua")
OUTPUT=$(mktemp "${TMPDIR:-/tmp}/wezterm-osc52-output.XXXXXX")
MARKER="osc52-query-proof-$$"
trap 'rm -f "$CONFIG" "$OUTPUT"' EXIT

cat >"$CONFIG" <<'LUA'
return {
  enable_osc52_clipboard_reading = true,
  exit_behavior = 'Close',
  window_close_confirmation = 'NeverPrompt',
}
LUA

printf '%s' "$MARKER" | pbcopy
rm -f "$OUTPUT"
OSC52_PROBE_OUTPUT="$OUTPUT" \
  "$WEZTERM" --config-file "$CONFIG" start --always-new-process -- \
  /usr/bin/python3 "$ROOT/ci/osc52-query-probe.py"

test -f "$OUTPUT"
ACTUAL=$(<"$OUTPUT")
if [[ "$ACTUAL" != "OK:$MARKER" ]]; then
  echo "OSC 52 query integration test failed: $ACTUAL" >&2
  exit 1
fi

echo "OSC 52 query integration test passed"
