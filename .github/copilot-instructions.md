# WezTerm OSC52 downstream instructions

This repository is an unofficial downstream of `wezterm/wezterm`. Preserve upstream behavior except for the narrowly documented OSC 52 clipboard-query patch and downstream release plumbing.

## Required invariants

- `enable_osc52_clipboard_reading` remains disabled by default.
- Disabled OSC 52 queries must not disclose clipboard contents.
- Enabled reads remain asynchronous and must not block the terminal parser.
- Mux/client clipboard requests retain pane and query identity, support concurrent requests, and terminate on response, failure, disconnect, or bounded timeout.
- The installed application remains the drop-in `WezTerm.app`, while the bundle identifier remains `com.github.ldelossa.wezterm-osc52`.
- Preserve the Help-menu fork disclosure, `README-OSC52.md`, upstream MIT notices, and bundled font licenses.
- Preserve `.upstream-sha` as the exact upstream commit represented by downstream `main`.

## Validation

Run at minimum:

```sh
cargo fmt --all -- --check
cargo test -p wezterm-term osc52
cargo test -p codec
cargo test -p wezterm-mux-server-impl clipboard_query
cargo check -p mux -p wezterm-client -p wezterm-mux-server-impl -p wezterm-gui
```

On macOS packaging changes, also run the universal build, package verification, and `ci/test-osc52-query-macos.sh` against the assembled app.

## Release boundary

AI-authored changes require human review. Automated repair agents must not merge pull requests, modify branch protection, access or request release secrets, sign or notarize artifacts, publish GitHub Releases, update the Homebrew tap, or change the default-off security policy. Release operations must execute only from reviewed default-branch workflows and the protected `release` environment.
