---
tags:
  - osc
  - clipboard
---

# `enable_osc52_clipboard_reading = false`

{{since('nightly')}}

When set to `true`, the terminal will allow access to the system clipboard by
terminal applications via an `OSC 52`
[escape sequence](../../../shell-integration.md#osc-52-clipboard-query).

The default for this option is `false`.

Only enable this option after considering its security implications.

### Security concerns

Clipboards often contain sensitive information. Enabling this option grants any
process that can write terminal output access to the local clipboard, including
programs running through SSH or a multiplexer domain. A compromised remote host
can repeatedly query and exfiltrate clipboard contents without a separate paste
gesture.

Base64 is an encoding, not encryption or access control. It does not mitigate
clipboard disclosure.

When this option is disabled, OSC 52 clipboard queries receive no response and
the clipboard is not read. When it is enabled but the operating-system clipboard
cannot be read, WezTerm OSC52 returns an empty response so the requesting
application does not wait indefinitely.
