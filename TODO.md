# WezTerm OSC52 continuation checklist

This file is the restart handoff for the first trusted macOS release and
Homebrew cutover.

## Current checkpoint

- Repository: `https://github.com/ldelossa/wezterm-osc52`
- Local checkout: `/Users/louis/git/ts/sstool/wezterm-osc52/source`
- Current branch: `drop-in-packaging`
- Current pull request: [`#2`](https://github.com/ldelossa/wezterm-osc52/pull/2)
- PR head before this documentation update: `1850a774`
- Downstream `main`: `305eea26`
- Pinned upstream commit: `46a166d6dc8188ede1a32a96375e308081ebafc5`
- PR #1 containing the OSC 52 feature is merged.
- PR #2 contains the drop-in identity, Help-menu disclosure, universal package
  scripts, CI, manual draft-release workflow, and cask template.
- The working tree should be clean after this documentation is committed and
  pushed.

At the time this handoff was written, PR #2 was mergeable. Both formatting
checks passed. The downstream macOS contract and inherited upstream platform
builds were still running. Recheck rather than assuming their final state.

## Proven locally

- [x] OSC 52 reads remain disabled by default.
- [x] Focused terminal OSC 52 tests pass.
- [x] Codec request/response round-trip tests pass.
- [x] Concurrent mux query-correlation tests pass.
- [x] Relevant Rust integration crates compile.
- [x] A real macOS GUI pane queried and returned a known `pbcopy` marker.
- [x] OSC 52 copy/write still updates the host clipboard.
- [x] The real path `Mac WezTerm → SSH linux → Neovim → host clipboard` works
  for both read/paste and copy.
- [x] All four release binaries have been built for `arm64` and `x86_64`.
- [x] A universal ad-hoc package passed archive, identity, signature, version,
  manifest, architecture, and GUI clipboard checks.
- [x] The app installs under the drop-in name `WezTerm.app`.
- [x] The downstream bundle ID remains
  `com.github.ldelossa.wezterm-osc52`.
- [x] The Help menu source includes **About the OSC52 Fork**.
- [x] The generated Homebrew cask has immutable version and SHA-256 fields.
- [x] `actionlint`, ShellCheck, Python compilation, Ruby syntax, and plist
  validation pass.

## Signing state

A usable signing identity and private key are already present in the macOS
login Keychain:

```text
Developer ID Application: Louis DeLosSantos (X447KQR49A)
```

Certificate validity:

```text
notBefore: April 20, 2026
notAfter:  April 21, 2031
```

Use this **Developer ID Application** identity for direct/Homebrew
installation. Do not use an Apple Distribution or Mac App Distribution
certificate; those are for App Store distribution.

No certificate, private key, Apple ID password, app-specific password, or
notarization credential may be committed to this repository.

## Immediate next step: create the local notary profile

The Keychain profile `wezterm-osc52` does not exist yet.

1. Create an app-specific password at:
   `https://account.apple.com/account/manage`
2. In a private local terminal, run:

   ```bash
   xcrun notarytool store-credentials wezterm-osc52
   ```

3. Enter the Apple ID, app-specific password, and team ID when prompted:

   ```text
   Team ID: X447KQR49A
   ```

4. Validate without exposing the credential:

   ```bash
   xcrun notarytool history --keychain-profile wezterm-osc52
   ```

The profile belongs in macOS Keychain, not in the repository.

## Resume commands after restarting

```bash
cd /Users/louis/git/ts/sstool/wezterm-osc52/source

git status --short --branch
git log --oneline --decorate -5
env -u GITHUB_TOKEN gh pr checks 2 --repo ldelossa/wezterm-osc52
xcrun notarytool history --keychain-profile wezterm-osc52
security find-identity -v -p codesigning
```

The local release dependencies were installed through Homebrew:

```text
rustup 1.29.0_2
actionlint 1.7.12
shellcheck 0.11.0
```

Homebrew's `rustup` is keg-only. `ci/build-macos-universal.sh` detects it and
uses its toolchain proxies explicitly; no shell PATH change is required.

## Final local test before merging PR #2

Do not reuse a pre-merge or interrupted archive. Generate a fresh candidate
from the current PR head:

```bash
cd /Users/louis/git/ts/sstool/wezterm-osc52/source
VERSION="$(ci/tag-name.sh)-osc52.1"

cargo test -p wezterm-term osc52
cargo test -p codec
cargo test -p wezterm-mux-server-impl clipboard_query
cargo check -p mux -p wezterm-client -p wezterm-mux-server-impl -p wezterm-gui

VERSION="$VERSION" ci/build-macos-universal.sh
rm -rf dist
VERSION="$VERSION" \
  SIGN_IDENTITY='Developer ID Application: Louis DeLosSantos (X447KQR49A)' \
  NOTARY_PROFILE=wezterm-osc52 \
  ci/package-macos.sh
```

The expected trusted-package evidence is:

- [ ] `notarytool` reports `Accepted`.
- [ ] `stapler staple` succeeds.
- [ ] `stapler validate` succeeds.
- [ ] `codesign --verify --deep --strict` succeeds.
- [ ] `spctl --assess --type execute` succeeds.
- [ ] every packaged binary reports `x86_64 arm64`.
- [ ] `wezterm --version` contains the exact candidate version.
- [ ] bundle display name is `WezTerm`.
- [ ] bundle identifier is `com.github.ldelossa.wezterm-osc52`.
- [ ] the embedded manifest contains the expected upstream and downstream SHAs.

Extract the archive and rerun the real GUI test:

```bash
TMP=$(mktemp -d)
ditto -x -k "dist/WezTerm-macos-$VERSION.zip" "$TMP"
ci/test-osc52-query-macos.sh "$TMP/WezTerm.app"
```

Also open the packaged application and visually confirm:

- [ ] the application and menu-bar name are `WezTerm`;
- [ ] **Help → About the OSC52 Fork** exists and opens the downstream repo;
- [ ] normal dotfile key bindings still behave as expected.

A prior attempt at this final pass was interrupted when Developer ID signing
began. `dist/` was cleared and no partial candidate should be treated as a
release.

## Merge and repository protection

After the trusted local test and PR checks pass:

- [ ] Review the final PR #2 diff.
- [ ] Merge PR #2 into `main`.
- [ ] Delete the remote feature branch.
- [ ] Pull the resulting merge commit locally.
- [ ] Protect `main` and require at least the downstream `format` and
  `macos-contract` checks.
- [ ] Require pull requests for source changes.
- [ ] Create/protect the GitHub `release` environment.
- [ ] Restrict release deployments to protected `main`.
- [ ] Require human approval for the release environment if supported by the
  repository plan.

Generate the real release version only after the merge commit exists. This
ensures the version and embedded downstream SHA identify releasable `main`, not
a temporary PR commit.

## Provision GitHub release secrets

The first local notarization must pass before these are provisioned.

- [ ] Export the Developer ID Application certificate **with its private key**
  as a password-protected `.p12` outside the repository.
- [ ] Base64-encode it directly into the protected environment secret
  `MACOS_CERTIFICATE_P12`.
- [ ] Store the export password as `MACOS_CERTIFICATE_PASSWORD`.
- [ ] Store the Apple ID as `MACOS_APPLE_ID`.
- [ ] Store the app-specific password as `MACOS_APP_PASSWORD`.
- [ ] Store `X447KQR49A` as `MACOS_TEAM_ID`.
- [ ] Delete any temporary `.p12` and base64 files after secret upload.
- [ ] Confirm pull-request workflows cannot access release secrets.

Do not paste any secret into Pi/chat, issues, pull requests, workflow logs, or
repository files.

## First immutable GitHub release

- [ ] Manually dispatch `.github/workflows/release-macos.yml` from `main` with
  an immutable version matching:

  ```text
  YYYYMMDD-HHMMSS-<8-hex-downstream-sha>-osc52.1
  ```

- [ ] Confirm the workflow builds both architectures from scratch.
- [ ] Confirm signing, notarization, stapling, package verification, and cask
  rendering pass in GitHub Actions.
- [ ] Download the workflow artifact and independently verify its SHA-256.
- [ ] Inspect the draft GitHub Release and release notes.
- [ ] Confirm upstream and downstream SHAs match the embedded manifest.
- [ ] Publish the draft manually only after all checks pass.
- [ ] Confirm the public ZIP and checksum download successfully.

The prior release remains the known-good version after any candidate failure.
Never replace a published release asset in place.

## Homebrew tap and cutover

- [ ] Create public repository `ldelossa/homebrew-wezterm-osc52`.
- [ ] Add `Casks/wezterm-osc52.rb` from the verified release output.
- [ ] Run Homebrew style and audit checks from the tap.
- [ ] Verify the cask URL and SHA-256 against the public release asset.
- [ ] Test cask install and uninstall before replacing the host terminal.
- [ ] Quit running official WezTerm processes.
- [ ] Uninstall `wezterm@nightly`.
- [ ] Install `ldelossa/wezterm-osc52/wezterm-osc52`.
- [ ] Confirm `/Applications/WezTerm.app` has the downstream bundle ID and a
  valid stapled Developer ID signature.
- [ ] Confirm `wezterm --version` contains `-osc52.1`.
- [ ] Confirm existing `skhd` and `yabai` rules work unchanged.
- [ ] Repeat local and SSH/Neovim clipboard read/write tests.
- [ ] Test rollback before considering the cutover complete.

## Dotfile state and eventual cleanup

Local dotfiles currently have uncommitted changes in:

```text
config/wezterm/wezterm.lua
config/nvim/lua/options.lua
config/nvim/lua/keymaps.lua
```

An unrelated pre-existing local change also exists in:

```text
config/pi/settings.json
```

The Neovim test changes were copied to `ssh linux`, but the host timed out when
this handoff was written. Reconnect and verify its status after restart. Do not
overwrite unrelated remote changes.

The temporary test contract is:

- `WEZTERM_OSC52_READ=1` conditionally enables the downstream WezTerm option;
- the same variable selects native Neovim OSC 52 paste;
- without it, the existing OSC1337 user-variable fallback remains active.

After the cask is installed and has passed a soak period:

- [ ] make `enable_osc52_clipboard_reading = true` the intended permanent
  WezTerm setting;
- [ ] make the native Neovim OSC 52 paste provider the normal SSH path;
- [ ] remove the `WEZTERM_OSC52_READ` test gates;
- [ ] remove the Neovim OSC1337 `SetUserVar` paste mappings;
- [ ] remove the WezTerm `user-var-changed` paste handler;
- [ ] validate and commit only the intended dotfile files;
- [ ] synchronize and validate the Linux-host dotfiles;
- [ ] keep a documented rollback commit/path.

Existing launcher integrations already target the drop-in name and should not
need OSC52-specific names:

```text
skhd:  open -na WezTerm.app ...
yabai: application match ^WezTerm$
```

## Automation after the first release

Implement only after the manual release and Homebrew cutover are trusted:

- [ ] Add daily and manual upstream observers.
- [ ] Compare `wezterm/wezterm:main` with `.upstream-sha`.
- [ ] Skip unchanged upstream commits without building.
- [ ] Deterministically merge one exact upstream SHA into a candidate branch.
- [ ] Use one channel-wide concurrency group.
- [ ] Publish only immutable versions and exact checksums.
- [ ] Update the tap only after the public release is independently verified.
- [ ] Preserve the last known-good cask after every failure.
- [ ] Implement source, upstream, Apple trust, GitHub publication, and tap
  failure classes.
- [ ] Maintain one Nightly Channel Status issue.
- [ ] Allow at most one active source-repair incident/PR.
- [ ] Queue the latest upstream SHA while blocked.
- [ ] Add Copilot repair escalation only after deterministic failure evidence
  and deduplication exist.
- [ ] Keep Copilot unable to merge, sign, access release secrets, publish, or
  update the tap.
- [ ] Require human review for every AI-authored repair.

Planning references are located in the parent project:

```text
/Users/louis/git/ts/sstool/.plans/wezterm-osc52-distribution/context.md
/Users/louis/git/ts/sstool/.plans/wezterm-osc52-distribution/plan.md
/Users/louis/git/ts/sstool/.plans/wezterm-osc52-distribution/state-machine.md
```

## Stop conditions

Pause rather than publish if any of these occur:

- notarization is not `Accepted`;
- stapling or Gatekeeper assessment fails;
- a binary is not universal;
- the release version, bundle ID, or embedded SHAs disagree;
- the real OSC 52 GUI or SSH/Neovim test regresses;
- PR checks are failing or incomplete;
- a release secret appears in logs or files;
- the public asset checksum differs from the cask;
- the prior cask would be overwritten before the candidate is verified.
