# WezTerm OSC52

> [!IMPORTANT]
> Unofficial downstream of [WezTerm](https://github.com/wezterm/wezterm). Not
> affiliated with upstream. Report issues
> [here](https://github.com/ldelossa/wezterm-osc52).

This fork adds opt-in OSC 52 clipboard reading to WezTerm, enabling native
clipboard paste from Neovim over SSH. **Releases are fully automated and
AI-driven** — every upstream change is detected, merged, built, signed,
notarized, and published without human intervention. Merge conflicts are
resolved automatically by AI.

## Install

```bash
brew tap ldelossa/wezterm-osc52
brew install --cask wezterm-osc52
```

Updates arrive automatically with `brew upgrade`. The cask conflicts with
`wezterm` and `wezterm@nightly` — uninstall those first.

## Enable OSC 52 clipboard reading

Clipboard reading is **disabled by default**. Add to `~/.config/wezterm/wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.enable_osc52_clipboard_reading = true
return config
```

Neovim uses its built-in OSC 52 provider — no plugin needed:

```lua
local osc52 = require 'vim.ui.clipboard.osc52'
vim.g.clipboard = {
  name = 'OSC 52',
  copy = { ['+'] = osc52.copy('+'), ['*'] = osc52.copy('*') },
  paste = { ['+'] = osc52.paste('+'), ['*'] = osc52.paste('*') },
}
```

## Identity

| Property | Value |
|---|---|
| App name | `WezTerm.app` |
| CLI commands | `wezterm`, `wezterm-gui`, `wezterm-mux-server`, `strip-ansi-escapes` |
| Bundle ID | `com.github.ldelossa.wezterm-osc52` |
| Cask | `wezterm-osc52` |
| Version suffix | `-osc52.N` |

The app is signed, notarized, and stapled with a Developer ID certificate.
Identity and provenance are embedded in the app bundle.

## How it works

An [automation controller](https://github.com/ldelossa/wezterm-osc52-automation)
polls upstream hourly. When `wezterm/wezterm:main` advances:

1. The downstream patch is merged into the new upstream.
2. If merge conflicts exist, **AI resolves them** using DeepSeek V4 Pro with
   full repository context.
3. A secretless universal macOS build produces an unsigned candidate.
4. An isolated signer applies Apple code signing and notarization.
5. A credential-free verifier validates the signed artifact.
6. A GitHub Release is published and the Homebrew cask is updated.

All steps are automated. No human touches the pipeline. The last known-good
release is preserved on every failure.

## Security

Enabling clipboard reading allows any process that writes terminal output to
read the clipboard — including remote hosts over SSH. Only enable this when
that trust model is acceptable.

## License

WezTerm is Copyright © 2018–Present Wez Furlong, distributed under the
[MIT License](LICENSE.md). This fork preserves all upstream licenses.
