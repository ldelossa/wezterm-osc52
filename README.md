# WezTerm OSC52 downstream

> [!IMPORTANT]
> This is an unofficial downstream build of
> [WezTerm](https://github.com/wezterm/wezterm). It is not affiliated with or
> supported by the upstream WezTerm project. Report downstream issues in
> [`ldelossa/wezterm-osc52`](https://github.com/ldelossa/wezterm-osc52), not to
> upstream.

This fork adds opt-in support for applications that query the terminal for
clipboard contents with OSC 52. Its primary use case is native host-clipboard
paste from Neovim running over SSH, without a terminal-specific user-variable
workaround.

The fork is intended to track upstream `main`, produce immutable universal
macOS releases, and install as a drop-in replacement through a dedicated
Homebrew cask.

## User-visible identity

The installed application and command names remain compatible with upstream:

- application: `WezTerm.app`
- commands: `wezterm`, `wezterm-gui`, `wezterm-mux-server`, and
  `strip-ansi-escapes`
- macOS application name: `WezTerm`

The downstream remains distinguishable where identity and provenance matter:

- bundle identifier: `com.github.ldelossa.wezterm-osc52`
- Homebrew cask token: `wezterm-osc52`
- repository: `ldelossa/wezterm-osc52`
- release version suffix: `-osc52.N`
- Help-menu item: **About the OSC52 Fork**
- embedded release manifest:
  `WezTerm.app/Contents/Resources/wezterm-osc52-release.json`

The manifest records the immutable version and exact upstream and downstream
Git commits represented by the build.

## OSC 52 clipboard querying

Clipboard reading is disabled by default. Enable it explicitly in
`wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.enable_osc52_clipboard_reading = true

return config
```

An application can then request the host clipboard with:

```text
ESC ] 52 ; c ; ? ST
```

WezTerm responds with a base64-encoded OSC 52 selection response. Selection
`c` addresses the clipboard and `p` addresses the primary selection on
platforms that provide one.

Neovim can use its built-in OSC 52 provider:

```lua
local osc52 = require 'vim.ui.clipboard.osc52'

vim.g.clipboard = {
  name = 'OSC 52 read/write',
  copy = {
    ['+'] = osc52.copy('+'),
    ['*'] = osc52.copy('*'),
  },
  paste = {
    ['+'] = osc52.paste('+'),
    ['*'] = osc52.paste('*'),
  },
}
```

See [README-OSC52.md](README-OSC52.md) for the detailed behavior, validation
contract, attribution, and security model.

## Security model

Enabling clipboard reading allows any process that can write terminal output
to request the host clipboard. This includes applications reached through SSH
or a WezTerm multiplexer connection. A compromised remote host can therefore
read and exfiltrate clipboard secrets without a separate paste gesture.

The downstream contract requires that:

- clipboard reading remains disabled by default;
- disabled queries never request or disclose clipboard contents;
- clipboard access remains asynchronous and does not block the terminal
  parser;
- mux requests preserve pane and query identity;
- concurrent requests are correlated independently;
- failures, duplicates, disconnects, and timeouts do not panic or hang;
- remote queries are forwarded only to the most recently active client focused
  on the requesting pane.

Only enable clipboard reads when this trust model is acceptable. Base64 is an
encoding, not encryption or access control.

## Implementation overview

The downstream patch crosses the same boundaries as a normal WezTerm
clipboard operation:

1. `wezterm-escape-parser` recognizes OSC 52 query syntax.
2. `term` checks the default-off configuration and requests clipboard contents
   asynchronously.
3. `mux` routes local queries to the GUI clipboard provider.
4. `codec`, `wezterm-client`, and `wezterm-mux-server-impl` carry remote
   requests and responses with query IDs and pane correlation.
5. `wezterm-gui` reads the operating-system clipboard and completes the
   callback.
6. The terminal writes the correctly labeled, base64-encoded OSC 52 response
   to the requesting pane.

The initial implementation was adapted from
[upstream PR #6239](https://github.com/wezterm/wezterm/pull/6239) and Len
Trigg's refreshed branch, then updated for current upstream and hardened for
concurrency and failure handling.

## Source and branch model

- `upstream` points to `wezterm/wezterm`.
- `origin` points to `ldelossa/wezterm-osc52`.
- downstream `main` is the last reviewed, tested source accepted for release.
- [`.upstream-sha`](.upstream-sha) records the exact upstream commit represented
  by downstream `main`.
- source changes enter `main` through pull requests and required checks.
- AI-authored conflict repairs require human review and cannot merge or
  release code.

The repository intentionally carries a small downstream patch rather than
merging stale feature-branch history wholesale. This makes future upstream
merges and conflict review easier to audit.

## CI and release pipeline

### Pull-request contract

[`.github/workflows/downstream-contract.yml`](.github/workflows/downstream-contract.yml)
runs with read-only repository permissions and validates:

- nightly Rust formatting;
- focused terminal OSC 52 tests;
- codec round trips;
- mux query correlation;
- relevant integration crates;
- universal `arm64` and `x86_64` release builds;
- ad-hoc package assembly and structural verification.

The inherited upstream workflows provide broader Linux, macOS, Windows, Nix,
and formatting coverage.

### Universal macOS package

[`ci/build-macos-universal.sh`](ci/build-macos-universal.sh):

1. writes the immutable downstream version to a temporary `.tag`;
2. compiles all four packaged binaries for `aarch64-apple-darwin` and
   `x86_64-apple-darwin`;
3. restores the prior source-tree state after the build.

[`ci/package-macos.sh`](ci/package-macos.sh):

1. assembles the drop-in `WezTerm.app`;
2. combines each architecture with `lipo`;
3. embeds release provenance;
4. applies hardened-runtime entitlements;
5. signs with a Developer ID Application identity;
6. submits the archive with `notarytool`;
7. staples and validates the notarization ticket;
8. verifies code signing and Gatekeeper assessment;
9. creates an immutable ZIP and SHA-256 checksum.

[`ci/verify-macos-package.sh`](ci/verify-macos-package.sh) independently checks
archive layout, bundle identity, both architectures, the embedded manifest,
reported command version, code signing, and—when required—notarization and
Gatekeeper.

### Manual trusted release

[`.github/workflows/release-macos.yml`](.github/workflows/release-macos.yml) is
manual-only. It uses the protected `release` environment to build, sign,
notarize, staple, verify, and upload a **draft** GitHub Release. Publishing the
first release remains a human action.

The release environment uses these secrets; none belong in repository files:

- `MACOS_CERTIFICATE_P12`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_APPLE_ID`
- `MACOS_APP_PASSWORD`
- `MACOS_TEAM_ID`

The expected signing identity is a **Developer ID Application** certificate.
`Apple Distribution` or `Mac App Distribution` certificates are for App Store
distribution and are not used by this Homebrew release path.

### Homebrew

[`ci/generate-homebrew-cask.py`](ci/generate-homebrew-cask.py) renders
[`ci/wezterm-osc52.rb.template`](ci/wezterm-osc52.rb.template) with the exact
immutable release version and archive SHA-256.

The resulting cask:

- is named `wezterm-osc52`;
- installs `WezTerm.app` and the normal CLI command names;
- conflicts with `wezterm` and `wezterm@nightly`;
- retains the downstream bundle identifier;
- never uses `sha256 :no_check` or a mutable nightly URL.

The public tap will be `ldelossa/homebrew-wezterm-osc52`. It is not created or
published until the first signed and notarized release passes local validation.

## Local validation

Focused source validation:

```bash
cargo +nightly fmt --all -- --check
cargo test -p wezterm-term osc52
cargo test -p codec
cargo test -p wezterm-mux-server-impl clipboard_query
cargo check -p mux -p wezterm-client -p wezterm-mux-server-impl -p wezterm-gui
```

Build universal inputs and an ad-hoc development package:

```bash
VERSION="$(ci/tag-name.sh)-osc52.1"
VERSION="$VERSION" ci/build-macos-universal.sh
VERSION="$VERSION" SIGN_IDENTITY=- ci/package-macos.sh
```

A trusted local package uses a Developer ID identity and Keychain notary
profile:

```bash
VERSION="$(ci/tag-name.sh)-osc52.1"
VERSION="$VERSION" \
  SIGN_IDENTITY='Developer ID Application: Louis DeLosSantos (X447KQR49A)' \
  NOTARY_PROFILE=wezterm-osc52 \
  ci/package-macos.sh
```

Run the real GUI/TTY clipboard test against an extracted app:

```bash
ci/test-osc52-query-macos.sh '/path/to/WezTerm.app'
```

## Planned automatic upstream releases

The trusted manual release is deliberately implemented before unattended
nightlies. Once the first release and Homebrew cutover are proven, scheduled
automation will:

1. poll `wezterm/wezterm:main` daily;
2. exit without building when `.upstream-sha` is unchanged;
3. claim one exact upstream SHA and merge it into a temporary sync branch;
4. run the focused and general source contracts;
5. build, sign, notarize, staple, and verify one immutable candidate;
6. publish the GitHub Release only after all trust checks pass;
7. update the tap only after the public asset and checksum are verified;
8. leave the last known-good cask untouched after any failure.

Only one source-repair incident may be active. If upstream advances while the
channel is blocked, the latest observed SHA is queued and probed without
rebasing underneath active repair work. Copilot may propose source conflict
repairs, but it cannot merge, access release secrets, sign, notarize, publish,
or update the tap.

The detailed latest-wins and failure behavior is maintained in the project
planning artifacts outside this checkout and will be implemented after the
first manual release.

## Current status

The feature and real local-to-SSH-to-Neovim clipboard workflow have passed.
Universal package assembly and Developer ID identity discovery have also
passed. The first notarized release, Homebrew tap, host cutover, and scheduled
upstream publication are still pending.

See [TODO.md](TODO.md) for the exact resume point and remaining checklist.

## Attribution and licenses

WezTerm is Copyright © 2018–Present Wez Furlong and is distributed under the
[MIT License](LICENSE.md). This fork preserves the upstream license and bundled
font license notices.

Upstream documentation and project information remain available at
[wezterm.org](https://wezterm.org/) and
[github.com/wezterm/wezterm](https://github.com/wezterm/wezterm).
