# CLAUDE.md

This is a **chezmoi**-managed dotfiles repository. It is the *source* directory
(`chezmoi source-path` → this repo). Files here are transformed and written into
`$HOME` by `chezmoi apply`. Do **not** edit the deployed copies in `$HOME`
directly — edit the source here and apply.

## Golden rules

- **Agents must never run `chezmoi` themselves** (no `apply`, `diff`, `init`,
  `execute-template`, `re-add`, etc.). Edit the source files, then **ask the user
  to run the chezmoi command** and report back. Rationale: `chezmoi` triggers an
  interactive pre-hook (1Password sign-in prompt), so it must stay under the
  user's control. Validate template/JSON changes with other tools instead (e.g.
  a strict JSON parser, or rendering the branch manually).
- Edit source files in this repo, then run `chezmoi apply` to deploy. Never edit
  the applied copy under `$HOME` (it will be overwritten on the next apply).
- Preview before applying: `chezmoi diff` (all) or `chezmoi diff ~/.config/fish`.
- `chezmoi apply -v` shows what changed. `chezmoi apply --dry-run -v` shows what *would*.
- **Secrets are never committed in plaintext.** They come from 1Password at apply
  time via template functions (`onepasswordRead`, `onepassword`). `op` must be
  signed in for templated files and package installs to render.
- git `autoCommit` and `autoPush` are **off** (`.chezmoi.toml.tmpl`). This repo is
  public, so nothing here publishes itself: every commit and push is manual and
  gets a chance to be read first. Expect the working tree to carry real changes.
- **Trunk-based development only.** Commit to `main`; there are no feature
  branches and no PR review step. If something does end up on a branch, merge it
  back to `main` promptly rather than letting it live there — so do not create a
  branch out of habit just because a change is large.

## chezmoi naming conventions (how source names map to `$HOME`)

The filename encodes the target path and attributes. Common prefixes/suffixes:

- `dot_foo` → `~/.foo` (e.g. `dot_gitconfig` → `~/.gitconfig`)
- `private_foo` → applied with `0600` perms (e.g. `private_dot_ssh/` → `~/.ssh/`)
- `foo.tmpl` → rendered as a Go template (chezmoi funcs + 1Password) before writing
- `symlink_foo` → `~/foo` is created as a *symlink* whose target is the file's
  contents (whitespace-trimmed), rather than a copy of them. Combines with
  `.tmpl`, which is how the target path gets written as
  `{{ .chezmoi.sourceDir }}/…`. See `.symlinked/` and "Launcher (vicinae)".
- `run_once_*.sh` → script run once ever, `run_onchange_*.sh` → run when its
  *contents* change, `run_after_*` / `run_before_*` → ordering relative to file apply
- Leading-dot files (`.chezmoi*`, `.install-prerequisites.sh`, `.startup.sh`,
  `.set-keyboard.sh`, `.update-zed-config.sh`) are chezmoi control files or
  standalone helper scripts — they are **not** applied to `$HOME`.

`.chezmoiignore` lists paths that are intentionally *not* deployed (README, this
CLAUDE.md, `claude-configs/`, and OS/profile-conditional paths). When you add a
top-level doc/helper that should not land in `$HOME`, add it here.

**Its patterns match the TARGET path, never the source filename**, and getting
that wrong fails silently in both directions. A pattern written in source form
(`dot_config/...`, `dot_pi/...`) matches nothing and the file ships anyway; a
pattern that happens to match a real target suppresses it with no warning. Both
had already happened here: `.claude/**` was meant for the source-dir `.claude/`
but instead stopped `dot_claude/` from ever being applied, and
`dot_pi/agent/packages/terraform-workflow` never excluded the work-only pi
package from private machines. Source entries whose names begin with a dot need
no entry at all — chezmoi skips them automatically.

`.chezmoiremove` is the counterpart: target paths chezmoi should *delete* on
apply. Use it when a file stops being managed but should not linger in `$HOME`.

## Templating

`.tmpl` files use Go templates. Preview a rendered template without applying:

```bash
chezmoi execute-template < dot_gitconfig.tmpl
chezmoi cat ~/.gitconfig          # render + show the final target content
```

Key data/functions used in this repo:
- `.isWorkComputer` — the work/private profile switch, prompted once at
  `chezmoi init` and stored in `~/.config/chezmoi/chezmoi.toml`.
- `.chezmoi.os` — `"darwin"` vs `"linux"` guards (this repo is macOS-primary).
- `onepasswordRead "op://vault/item/field" "account"` — inline secret.
- `output`/`include ... | sha256sum` — used in `run_onchange_*` headers so the
  script re-runs when tracked state (brew leaves, mise config, etc.) changes.

## Profiles: work vs private

`.isWorkComputer` selects which package set and config blocks apply. Package lists
in `.chezmoidata/packages.yaml` are split into `universal`, `work`, and `private`.
Work-only extras include HashiCorp taps/tools, the pi terraform-workflow package,
and Artifactory/Quay Docker logins. Keep new work-specific items behind
`{{ if .isWorkComputer }}` guards and in the `work` package section.

The profile sections are **added to** `universal`, never used instead of it, so
an entry that appears in both is redundant — put anything both machines need in
`universal` alone. Every tap referenced by a fully-qualified brew or cask needs
declaring in the same section or above it; a missing tap still works, because
brew auto-taps fully-qualified names, which is exactly why the omission goes
unnoticed until something else breaks.

## Package management (macOS / Homebrew / mas / Fisher)

Packages are **declared** in `.chezmoidata/packages.yaml`, not installed ad hoc.
`run_onchange_install-packages.sh.tmpl` builds a Brewfile from that data, trusts
non-official taps, runs `brew bundle`, and **removes anything installed but not
declared**. Same reconciliation applies to `mas` apps and Fisher plugins.

Helper scripts (all take `--work | --private | --auto`, default `--auto`):
- `./audit-packages.sh` — report installed-but-undeclared packages (read-only).
- `./cleanup-packages.sh [--dry-run]` — remove undeclared packages.
- `./reconcile-packages.sh` — interactively add-to-yaml or remove, per package.
  Note that what you declare and what `brew leaves` / `brew list --cask` report
  are often different strings for the same package — aliases (`gpg` → `gnupg`,
  `kubectl` → `kubernetes-cli`) and upstream renames (`flux` → `flux-app`).
  `_package-helpers.sh` resolves both via `brew info`, and deliberately keeps
  tap-qualified names out of that batched call: one formula from an untrusted
  tap aborts the whole call, which used to empty the alias map and report every
  aliased package as undeclared.
- `_package-helpers.sh` — shared library; sourced, not run directly.

To add a package: edit `packages.yaml` (correct section), then `chezmoi apply`
(re-runs the install script because the data hash changes). See the
`manage-packages` skill.

## Shell environment (fish + bash + zsh)

Fish is the primary interactive shell, but every exported variable and PATH
entry is shared with bash and zsh so a script — or an agent opening a shell —
resolves the same binaries. **`.chezmoidata/shell.yaml` is the single source of
truth.** Two files are generated from it and must never be edited directly:

| generated file | shell |
| --- | --- |
| `dot_config/fish/conf.d/00-env.fish.tmpl` | fish |
| `dot_config/shell/env.sh.tmpl` | bash, zsh, sh |

To add or change a variable or a PATH entry, edit `shell.yaml` and re-apply —
never add a bare `set -x` to a fish file or an `export` to a POSIX file.
`env` entries render in listed order, so a later value may reference an earlier
one; `env_defaults` entries are only applied when not already set.

Supporting files:

- `dot_config/shell/interactive.sh.tmpl` — bash/zsh-only extras that are allowed
  to be slow: `mise activate`, `op` completions, `ssh-add`. The fish counterpart
  is `config.fish.tmpl` + `conf.d/mise.fish.tmpl`.
- `dot_config/shell/private_secrets.sh.tmpl` — the one part of the environment
  *not* in `shell.yaml`, because that file is committed in plaintext. Rendered at
  0600 from 1Password; keep it in sync with `conf.d/secrets.fish.tmpl`.
- `dot_zshenv`, `dot_zprofile`, `dot_zshrc`, `dot_profile`, `dot_bash_profile`,
  `dot_bashrc` — thin entry points that source the two files above. `env.sh`
  guards against loading twice, so overlapping entry points are harmless.

Things worth knowing:

- **`~/.zshenv` is the load-bearing one.** zsh reads it for *every* invocation,
  including `zsh -c`, which is how most tooling opens a shell.
- **`bash -c` reads no startup file at all** — that is bash's design, not a gap
  in this repo. A non-interactive, non-login bash only has what it inherited.
  Use `bash -lc` (or `zsh -c`) when the environment has to be there.
- **mise must outrank Homebrew.** mise shims are prepended ahead of everything
  in `env.sh`, and `conf.d/00-env.fish` is named `00-` so it loads before
  `conf.d/mise.fish` and cannot push mise's paths back. Otherwise `node`
  silently resolves to the Homebrew build instead of the pinned version.
- **Homebrew deliberately outranks `$HOME/.local/bin`**, which is the order fish
  has always had; flipping it would change which `claude` binary wins.
- `fish_user_paths` is set *globally* by `00-env.fish`, and any pre-existing
  *universal* value is erased once. Don't use `fish_add_path`/`set -Ua` — a
  universal value persists across machines and silently outranks the declared
  list.
- Aliases, functions and the prompt stay fish-only by design. Only environment
  is shared.

Since agents must not run `chezmoi`, validate template changes by rendering them
with Go's `text/template` directly (parse + execute against `shell.yaml`), then
`sh -n` / `zsh -n` / `bash -n` the POSIX output and `fish --no-execute` the fish
output.

## Other managed surfaces

- **fish** (`dot_config/fish/`): `config.fish.tmpl`, `conf.d/*` (aliases and
  functions; env comes from `00-env.fish`), `functions/*`. Fish is the default
  shell — see "Shell environment" above.
- **mise** (`dot_config/mise/config.toml.tmpl`): runtime versions (node, go, rust,
  ruby/python on work). Installed via `mise install -y` inside the package script.
- **Zed** (`dot_config/zed/`): editor config. `./update-zed-config.sh` pulls the
  *live* `~/.config/zed` settings back into the repo (reverse of apply) — use it
  after changing settings in the Zed UI, then commit.
- **git** (`dot_gitconfig.tmpl`): aliases, delta pager, GPG signing (macOS),
  `insteadOf` git@ rewrite. Signing key comes from 1Password. `rerere` is on
  because most aliases here rebase; `core.fsmonitor` is on for the large work
  monorepos.
- **Claude Code** (`dot_claude/`): `settings.json.tmpl`, plus `CLAUDE.md` and
  `RTK.md` (the global agent instructions — `CLAUDE.md` is just an `@RTK.md`
  include). The template's only profile-dependent keys are the model and the
  work-machine Bedrock/doormat pair; everything else is shared. Note that
  Claude Code writes this file itself (`/config`, plugin installs), so treat a
  `chezmoi diff` here as real drift to fold back into the source rather than
  something to overwrite blindly.
- **Ghostty** (`dot_config/ghostty/config`): one file, deliberately. Ghostty
  reads both `~/.config/ghostty/config` and the macOS-native
  `~/Library/Application Support/com.mitchellh.ghostty/config` and *merges*
  them, so a second copy silently duplicates every list-valued key (`keybind`,
  `font-family`) and invites drift. `.chezmoiremove` deletes the old copy.
- **pi agent** (`dot_pi/agent/`): Earendil pi coding-agent config + a work-only
  `terraform-workflow` extension package (guards generated-file edits and
  acceptance tests). `AGENTS.md` holds pi's dev preferences.
- **claude-configs/terraform/**: reference CLAUDE.md + agent config for the
  HashiCorp Terraform repo. Not deployed by chezmoi (it's ignored); it's a
  drop-in for that project.
- **vicinae** — the launcher (⌘Space). Plain Homebrew cask; nothing is built from
  source. See "Launcher (vicinae)" below.

## Launcher (vicinae)

[vicinae](https://github.com/vicinaehq/vicinae) is the ⌘Space launcher, installed
as the `vicinae` cask. It replaced rustcast, which had to be vendored and patched
because its released build never re-armed its CGEventTap after macOS disabled it
(every hotkey died silently until the app restarted). vicinae's
`macos-global-shortcut-backend` handles `kCGEventTapDisabledByTimeout` /
`ByUserInput` itself, so the whole vendor/patch/build apparatus is gone: no
submodule, no `patches/`, no `run_onchange_*build*` script, no ad-hoc signing,
and no `auto_update = false` to keep an upstream release from clobbering a local
build.

Three managed surfaces, two of them **symlinked rather than copied**:

| source | target | what |
| --- | --- | --- |
| `.symlinked/vicinae/config/` ← `dot_config/symlink_vicinae.tmpl` | `~/.config/vicinae` → symlink | hotkeys, theme, window |
| `.symlinked/vicinae/snippets/` ← `dot_local/share/vicinae/symlink_snippets.tmpl` | `~/.local/share/vicinae/snippets` → symlink | the text-expansion snippets |
| `dot_local/share/vicinae/scripts/` | `~/.local/share/vicinae/scripts/` | the custom commands (copied) |

vicinae writes the first two itself, so they are linked straight into the repo
and an in-app change *is* a repo change — no reconciling, but expect settings
churn in `git status`. `.symlinked/vicinae/README.md` covers the mechanism, its
consequences, and the settings.json rationale that used to live in the file's
own comments. The scripts are copies because
vicinae never writes them and `executable_` keeps their mode bits right.

**settings.json is read as JSONC but written back as plain JSON.** vicinae's
settings GUI re-serializes the whole file, which strips the comments — which is
exactly why the source file is now plain JSON with its prose kept alongside
instead. Don't reintroduce comments into it. Same hazard rustcast's
`config.toml` had, but unlike rustcast vicinae does *not* silently fall back to
defaults when a top-level key is missing — it merges a partial config over the
built-in defaults and ignores unknown keys, so this file only needs to carry
deviations.

**snippets.json is written by vicinae too**, by the Create/Edit Snippet forms.
Its schema is undocumented and there is no file-based import, so the entries
here were reverse-engineered from what vicinae itself writes:

```json
{
  "id": "snp-44632fc06e41",
  "name": "Go: Printf value with expression name",
  "data": { "text": "fmt.Printf(\"\\\\n\\\\t {clipboard} --> %#v\\\\n\")" },
  "expansion": { "keyword": "fmtv", "apps": [], "word": true },
  "createdAt": 1785969032
}
```

`id` is required and must carry the `snp-` prefix. `data` is a tagged union —
`text` or `file` — so the body is **not** a `content` key. `keyword` is nested
under `expansion`, never top-level; put it at the top level and the snippet
loads but never expands. `word` is the form's "expand as word". `{clipboard}`,
`{cursor}`, `{argument}`, `{date}`, `{uuid}` and `{shell}` work inside the text,
and typing the keyword expands it in any application, which needs Accessibility
(`MacosSnippetServer` installs an event tap) and `input_server.enabled`.

**A literal backslash has to be doubled.** vicinae consumes `\` as an escape
when expanding, so a stored `\n` arrives as a bare `n` — which quietly mangles
Go format strings. Store `\\n` to emit `\n`. Real tabs and newlines need no
escaping and pass through untouched, so multi-line snippets are unaffected.

Beware that **vicinae is silent about this file when it cannot use it**: started
against deliberately corrupt JSON it logged no error, left the file untouched,
and carried on; the same is true of a well-formed file in the wrong shape.
Unlike settings.json it is not watched, so a change needs a restart. The one
reliable signal is that vicinae *rewrites* the file once it has loaded it,
filling in defaults like `apps` and `word` — if a hand-written entry never
grows those keys, it was never read. Otherwise verify by typing the keyword.

Things worth knowing about the config:

- **Modifier names are counter-intuitive on macOS.** `cmd`/`command`/`ctrl`/
  `control` all mean ⌘; `super`/`meta`/`windows` mean ⌃; `alt`/`opt`/`option`
  mean ⌥. (Qt swaps Control and Meta on macOS and vicinae's global-shortcut
  backend maps straight through.) Use `cmd+space`, not `super+space`.
- The launcher toggle is `global_shortcuts.toggle`. Per-command global shortcuts
  are *not* there — they live at
  `providers.<provider>.entrypoints.<entrypoint>.shortcut`, which is where the
  clipboard-history binding (⌘⇧C) sits. `keybinds` is a different thing again:
  in-window navigation only, never global.
- ⌘Space is Spotlight's by default; it only reaches vicinae because Spotlight's
  shortcut is disabled in System Settings › Keyboard › Keyboard Shortcuts.
- Clipboard history, app launching, file search, window switching, calculator,
  snippets, volume and the power actions are all **built in** — no extensions or
  separate daemons. Configure them as entrypoints under `providers` (`alias` for
  a short name to type, `shortcut` for a global binding, `preferences` for the
  command's own settings) rather than reimplementing them as scripts.
- Start-at-login is a macOS login item that vicinae registers itself; there is
  no config key for it.
- rustcast's `search_url` (fall back to a Google search for an unmatched query)
  has no config equivalent. The nearest thing is a Quicklink from the built-in
  `shortcut` extension, added to `fallbacks` — but Quicklinks live in vicinae's
  local database, not in `settings.json`, so they cannot be declared here and
  have to be created in the GUI.

### Custom commands are script commands

Every custom action is a Raycast-format script command — an executable with
`@vicinae.*` metadata in comments. `dot_local/share/vicinae/scripts/README.md`
documents the format, the mode/icon/keyword fields, and why every script starts
with `#!/bin/zsh` (LaunchServices gives vicinae a minimal `PATH`; `~/.zshenv` is
what puts Homebrew's `jq`/`curl` back on it). Current set:

- `hue/` — 21 scripts, one per room × `bright|chill|off`, each a one-liner over
  `~/.local/bin/hue`. Rooms come from `dot_config/hue/scenes.conf`; adding a row
  there also needs three new scripts here.
- `spotify/` — play/pause, next, previous via AppleScript. No client id, no OAuth
  token to refresh, and it drives whatever is playing locally.
- `time/` — convert a time in another time zone (for example, `4.30 ist`) to
  the Mac's local time. Common abbreviations and IANA zone names are accepted;
  `IST` means Indian Standard Time.
- `system/` — just `sleep-display`. rustcast's Sleep / Lock / Restart / Shut Down
  shell-outs are **gone**, replaced by the built-in `power` entrypoints, which
  are strictly better on macOS: `power:lock` calls `SACLockScreenImmediate()`
  rather than `open -a ScreenSaverEngine` (which only locks if Lock Screen ›
  "Require password after screen saver begins" is Immediately), and the others
  send the same `loginwindow` Apple Events natively instead of through
  `osascript`. Nothing built in sleeps only the display, hence the one script.
- `vicinae/` — restart vicinae (rarely needed: it watches `settings.json` and
  rescans the script directories on change).

vicinae rescans on directory change and every 15 minutes, so an edit is live
without a restart. A script that fails to parse is skipped *silently* — if a new
command does not show up, check `schemaVersion`/`title` and note that
`@raycast.*` and `@vicinae.*` keys cannot be mixed in one file.

### Not extensions, and why

There is no Hue extension in vicinae's store, and Raycast's `hue` extension is
absent from vicinae's `raycast/compat.json` tracker (so: untested) while pulling
`xstate`, `bonjour-service` mDNS discovery and the Hue v2 SSE stream. It is also
the wrong shape — browse-and-select views instead of one-shot actions. Writing a
native extension would mean an `npm install && npm run build` inside
`chezmoi apply` and a rebuild on every vicinae API bump, to replace a 40-line
shell script that already works. Reassess if the store gains a Hue extension.

## Bootstrapping a new machine (reference, not a routine task)

`.startup.sh` (curl-to-bash) installs Xcode CLT + Homebrew + chezmoi, then
`chezmoi init danielmschmidt && chezmoi apply`. `.install-prerequisites.sh` runs
as a chezmoi pre-hook (installs `op`/fish/etc.). `.set-keyboard.sh` is a manual
final step.

## Verifying changes

There is no build/test suite. "Correct" means:
1. `chezmoi diff` shows the intended change and nothing else.
2. For `.tmpl` edits, `chezmoi execute-template < file` renders without error.
3. For package edits, `./audit-packages.sh` is clean after apply.
4. `chezmoi apply --dry-run -v` succeeds.
