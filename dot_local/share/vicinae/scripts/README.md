# vicinae script commands

Deployed to `~/.local/share/vicinae/scripts`, which is vicinae's default script
directory. Vicinae scans it recursively (up to 5 levels), watches it for
changes, and rescans every 15 minutes — no restart needed after an edit.

Each script is an ordinary executable with `@vicinae.*` metadata in comments.
The format is Raycast's; `@raycast.*` works identically, but **the two prefixes
cannot be mixed in one file** and `keywords`, `exec` and `terminal` only exist
under `@vicinae.`. So everything here uses `@vicinae.`.

- `schemaVersion 1` and `title` are required; a file that fails to parse is
  skipped silently (look for it with `vicinae` running in a terminal).
- `mode silent` runs the command and closes the window — the right mode for
  every one-shot action here. Other modes: `fullOutput`, `compact`, `inline`,
  `terminal`.
- `keywords` is a JSON array and carries the short aliases that used to be
  typed at the previous launcher (`office chill`, `all off`, …).
- `packageName` is the group label in the root search; it defaults to the
  parent directory name.
- `icon` takes an emoji, a path (absolute, or relative to the script), or an
  `https:` URL. Emoji here rather than the macOS `.icns` app icons the previous
  launcher used, because those paths move between macOS releases; swap in e.g.
  `/Applications/Spotify.app/Contents/Resources/AppIcon.icns` if you prefer.
- `needsConfirmation true` puts a confirmation dialog in front — used for
  Restart and Shut Down.

`.md`, `.svg` and `.txt` files are ignored by the scanner, so this README is
invisible to vicinae.

`#!/bin/zsh` in every script is deliberate. Vicinae is launched by
LaunchServices with a minimal `PATH`, and zsh reads `~/.zshenv` on *every*
invocation, which sources `~/.config/shell/env.sh` — that is what puts
Homebrew's `curl`/`jq` (needed by the `hue` CLI) on `PATH`. A `#!/bin/sh` or
`#!/usr/bin/env bash` script would inherit vicinae's stunted `PATH` instead.
See "Shell environment" in the repo `CLAUDE.md`.

The Hue scripts are one file per room × scene, generated from the rows in
`dot_config/hue/scenes.conf`. Add a room there and add the three matching
scripts here.

Before adding a script, check whether vicinae already has the command built in —
clipboard history, app/file/window search, calculator, snippets, volume, and
sleep/lock/reboot/power-off/log-out all are. Those are configured as entrypoints
in `~/.config/vicinae/settings.json`, not duplicated here. `system/` holds only
`sleep-display`, because that one has no built-in equivalent.
