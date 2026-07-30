# WezTerm OSC52 downstream

This repository is an unofficial fork of
[wezterm/wezterm](https://github.com/wezterm/wezterm). It exists to provide
opt-in support for applications that query the terminal for clipboard contents
with OSC 52.

It is not affiliated with or supported by the upstream WezTerm project. Report
issues specific to this build in `ldelossa/wezterm-osc52`, not upstream.

## Downstream identity

The macOS package installs as the drop-in `WezTerm.app` and retains the normal
`wezterm` command names so existing launchers and key bindings continue to
work. It uses the distinct bundle identifier
`com.github.ldelossa.wezterm-osc52` and Homebrew cask token
`wezterm-osc52`. The Help menu includes **About the OSC52 Fork**, which links
back to the downstream notice and security documentation.

Release archives are immutable, universal `arm64`/`x86_64` packages. Each app
contains `Contents/Resources/wezterm-osc52-release.json` recording the exact
upstream and downstream commits represented by that build.

## Enable clipboard querying

Clipboard reads are disabled by default. Enable them explicitly:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.enable_osc52_clipboard_reading = true

return config
```

An application can then request the system clipboard with:

```text
ESC ] 52 ; c ; ? ST
```

The terminal responds with an OSC 52 selection response containing the
base64-encoded clipboard contents. `p` selects the primary-selection clipboard
on platforms that provide one.

## Security

Enabling this setting allows any process that can write terminal output to read
the local clipboard. That includes programs running through SSH or a WezTerm
multiplexer domain. A compromised remote host can query and exfiltrate secrets
without a separate paste gesture.

Only enable the option when that trust model is acceptable. Base64 is an
encoding, not encryption or access control.

When clipboard querying is disabled, queries receive no response and clipboard
contents are not requested. When enabled but the operating-system clipboard
cannot be read, the terminal returns an empty OSC 52 response so applications
do not wait indefinitely.

## Downstream contract

The downstream implementation must preserve these properties:

- clipboard querying remains disabled by default;
- clipboard and primary selections produce correctly labeled OSC 52 responses;
- clipboard retrieval is asynchronous and does not block the terminal thread;
- local and mux-client requests return to the requesting pane;
- concurrent mux queries are correlated by query ID;
- stale, duplicate, disconnected, and timed-out responses do not panic;
- a query is forwarded only to the most recently active client focused on the
  requesting pane;
- public releases pass focused tests, general CI, Developer ID signing,
  notarization, Gatekeeper assessment, and Homebrew cask validation.

## Attribution and license

The original project is Copyright © 2018–Present Wez Furlong and distributed
under the MIT License. This fork preserves the upstream license and bundled font
license notices. The initial OSC 52 query implementation was adapted from
[wezterm PR #6239](https://github.com/wezterm/wezterm/pull/6239) by Igor and the
updated branch maintained by Len Trigg.
