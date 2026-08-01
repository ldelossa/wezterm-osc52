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

## Automated upstream merge

This downstream is kept current by an automated controller pipeline (`wezterm-osc52-automation`). When upstream advances:

1. An AI repair agent (DeepSeek V4 Pro) resolves merge conflicts between the downstream OSC52 patch and the new upstream tree.
2. The resolved merge is pushed to `main` (the AI only touches source code — it has no access to signing keys, release tokens, or the Homebrew tap).
3. The controller's separate, access-controlled jobs handle signing, notarization, publishing, and tap updates.

The AI repair receives full repository context (all modified files) and retries on every pipeline invocation until upstream changes again. Its scope is strictly limited to merge conflict resolution — it never signs artifacts, publishes releases, or accesses secrets.
