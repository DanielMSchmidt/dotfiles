# vicinae config — symlinked, not copied

`~/.config/vicinae` and `~/.local/share/vicinae/snippets` are **symlinks into
this directory**, so the launcher's own writes land in the repo instead of
drifting from it.

| target | symlink source entry | real files |
| --- | --- | --- |
| `~/.config/vicinae` | `dot_config/symlink_vicinae.tmpl` | `config/` |
| `~/.local/share/vicinae/snippets` | `dot_local/share/vicinae/symlink_snippets.tmpl` | `snippets/` |

Why: vicinae writes both files itself — `settings.json` on every change made in
the settings GUI, `snippets.json` from the Create/Edit Snippet forms (and once
on load, to fill in defaults like `apps` and `word`). As copies they needed
reconciling by hand after every such change, in a repo whose whole point is
that the source is authoritative. Linked, an in-app change *is* a repo change.

The whole of `.symlinked/` is invisible to chezmoi: it skips every source entry
whose name begins with a dot, which is what keeps these files from also being
applied as regular copies. That matters — a source entry under
`dot_config/vicinae/` and the `dot_config/symlink_vicinae` entry would both
claim the target `~/.config/vicinae`, and chezmoi rejects the collision.

Consequences worth knowing:

- **The live config is the working tree.** Editing a file here changes vicinae's
  behaviour with no `chezmoi apply` — settings.json is watched, snippets.json
  needs a restart. Conversely a `git checkout`/`stash` of these files changes
  the running launcher.
- **Expect churn in `git status`.** Every settings-GUI change now shows up as an
  unstaged diff, including vicinae's own reformatting. That is the trade for
  never reconciling; read the diff before committing, as with everything else in
  this public repo.
- **`settings.json` is plain JSON on purpose.** vicinae reads JSONC, but it
  writes plain JSON — the first GUI change strips every comment. The rationale
  that used to live in those comments is below instead, where nothing overwrites
  it. Don't put it back in the file.
- Only the two written-by-vicinae surfaces are linked. The script commands under
  `dot_local/share/vicinae/scripts/` stay ordinary managed files: vicinae never
  writes them, and chezmoi's `executable_` prefix keeps the mode bits correct
  without relying on git.
- Directories are linked, not individual files, so it does not matter whether
  vicinae rewrites in place or writes-and-renames. A file symlink would be
  replaced by a regular file on the first atomic save, silently unlinking the
  config; a directory symlink cannot be.
- Nothing here is linked on Linux — `.chezmoiignore` drops both targets there.

## settings.json, annotated

- `global_shortcuts.toggle: cmd+space` — carried over from the previous
  launcher. macOS gives ⌘Space to Spotlight by default, so it only reaches
  vicinae because Spotlight's shortcut is disabled in System Settings ›
  Keyboard › Keyboard Shortcuts. In vicinae's syntax `cmd`/`control` both mean ⌘
  on macOS while `super`/`meta` mean ⌃, so this must be `cmd`.
- `favorites: clipboard:history` — clipboard history is built in; there is no
  separate history daemon to configure. Its global shortcut is an *entrypoint*
  shortcut, under `providers`, not a `global_shortcuts` key.
- `search_files_in_root: false` + `fallbacks: files:search` — fall back to file
  search when nothing matches, instead of searching files on every root query
  (which costs CPU).
- `pop_to_root_on_close: true` — start each launch from a blank root search
  rather than wherever the last session left off.
- `escape_key_behavior: close_window` — Escape closes the launcher outright. The
  default (`navigate_back`) only pops one view, so escaping out of a nested
  command took several presses.
- `theme` — the two slots are the *macOS appearance*, not the themes' own
  lightness, so the launcher follows the system between them. `dracula` is the
  closest built-in to what the terminal and the editor run: ghostty's cyberpunk
  and Zed's SynthWave 84 Dark are both purple-black with neon pink/cyan accents,
  and dracula's `#FF79C6` / `#8BE9FD` land almost on top of them.
  `catppuccin-latte` was chosen to keep that accent family rather than to match
  any other app — nothing else here has a light mode. Its magenta and cyan carry
  the same chroma as dracula's (60/31 vs 61/29 in Lab), so the accents hold
  their intensity across the switch instead of washing out.
- `launcher_window.material: none` — opaque, no blur/liquid-glass. `auto` gets
  the platform default.
- `providers.power` — the power actions are built in and better than shelling
  out: `lock` calls `SACLockScreenImmediate()` (a real lock, not "start the
  screensaver and hope Lock Screen › Require password is Immediately"), and the
  rest send the same loginwindow Apple Events as `tell application "System
  Events" to shut down` — sudo-free, apps still get to save. The aliases are the
  short names carried over from the previous launcher. `confirm` defaults to
  true on all of them; sleeping and locking are cheap to undo, so they skip the
  dialog.

Custom commands are **not** in this file. They are Raycast-format script
commands under `~/.local/share/vicinae/scripts`, which vicinae scans
recursively; see `dot_local/share/vicinae/scripts/README.md`.

## snippets.json

Schema notes (reverse-engineered — there is no documentation and no file-based
import) live in the repo's `CLAUDE.md`. The short version: `id` is required and
carries the `snp-` prefix, `data` is a tagged union (`text` or `file`, never
`content`), `keyword` nests under `expansion`, and a literal backslash has to be
doubled because vicinae consumes `\` as an escape when expanding.
