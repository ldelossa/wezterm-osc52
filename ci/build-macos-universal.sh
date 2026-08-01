#!/bin/bash
set -euo pipefail

if [[ $(uname -s) != Darwin ]]; then
  echo "This script must run on macOS" >&2
  exit 1
fi

VERSION=${VERSION:-"$(ci/tag-name.sh)-osc52.1"}
TARGET_DIR=${TARGET_DIR:-target}
mkdir -p "$TARGET_DIR"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
export CARGO_TARGET_DIR="$TARGET_DIR"
PACKAGES=(wezterm wezterm-gui wezterm-mux-server strip-ansi-escapes)
TARGETS=(aarch64-apple-darwin x86_64-apple-darwin)
TOOLCHAIN=${RUSTUP_TOOLCHAIN:-stable}
TAG_FILE=.tag
TAG_BACKUP=

RUSTUP=$(command -v rustup || true)
if [[ -z "$RUSTUP" ]] && command -v brew >/dev/null 2>&1; then
  RUSTUP_PREFIX=$(brew --prefix rustup 2>/dev/null || true)
  if [[ -x "$RUSTUP_PREFIX/bin/rustup" ]]; then
    RUSTUP="$RUSTUP_PREFIX/bin/rustup"
  fi
fi
if [[ -z "$RUSTUP" ]]; then
  echo "rustup is required to install both macOS Rust targets" >&2
  exit 1
fi

# Homebrew installs rustup keg-only, so put its cargo/rustc proxies first.
RUSTUP_BIN=$(dirname "$RUSTUP")
export PATH="$RUSTUP_BIN:$PATH"
"$RUSTUP" toolchain install "$TOOLCHAIN" --profile minimal
export RUSTC
RUSTC=$("$RUSTUP" which --toolchain "$TOOLCHAIN" rustc)
export RUSTDOC
RUSTDOC=$("$RUSTUP" which --toolchain "$TOOLCHAIN" rustdoc)
CARGO=("$RUSTUP" run "$TOOLCHAIN" cargo)

if [[ -e "$TAG_FILE" ]]; then
  TAG_BACKUP=$(mktemp "${TMPDIR:-/tmp}/wezterm-tag.XXXXXX")
  cp "$TAG_FILE" "$TAG_BACKUP"
fi

restore_tag() {
  if [[ -n "$TAG_BACKUP" ]]; then
    mv "$TAG_BACKUP" "$TAG_FILE"
  else
    rm -f "$TAG_FILE"
  fi
}
trap restore_tag EXIT

printf '%s\n' "$VERSION" >"$TAG_FILE"
for target in "${TARGETS[@]}"; do
  "$RUSTUP" target add --toolchain "$TOOLCHAIN" "$target"
  # Force the build-time version to observe .tag even after an earlier local build.
  "${CARGO[@]}" clean -p wezterm-version --release --target "$target"
  "${CARGO[@]}" build --locked --release --target "$target" \
    -p wezterm \
    -p wezterm-gui \
    -p wezterm-mux-server \
    -p strip-ansi-escapes

done

for package in "${PACKAGES[@]}"; do
  for target in "${TARGETS[@]}"; do
    test -x "$TARGET_DIR/$target/release/$package"
  done
done

printf 'Built universal inputs for %s\n' "$VERSION"
