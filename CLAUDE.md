# CLAUDE.md

This is a **chezmoi**-managed dotfiles repository. It is the *source* directory
(`chezmoi source-path` → this repo). Files here are transformed and written into
`$HOME` by `chezmoi apply`. Do **not** edit the deployed copies in `$HOME`
directly — edit the source here and apply.

## Golden rules

- **Agents must never run `chezmoi` themselves** (no `apply`, `diff`, `init`,
  `execute-template`, `re-add`, etc.). Edit the source files, then **ask the user
  to run the chezmoi command** and report back. Rationale: `chezmoi` triggers an
  interactive pre-hook (1Password sign-in prompt) and `autoCommit`/`autoPush`, so
  it must stay under the user's control. Validate template/JSON changes with other
  tools instead (e.g. a strict JSON parser, or rendering the branch manually).
- Edit source files in this repo, then run `chezmoi apply` to deploy. Never edit
  the applied copy under `$HOME` (it will be overwritten on the next apply).
- Preview before applying: `chezmoi diff` (all) or `chezmoi diff ~/.config/fish`.
- `chezmoi apply -v` shows what changed. `chezmoi apply --dry-run -v` shows what *would*.
- **Secrets are never committed in plaintext.** They come from 1Password at apply
  time via template functions (`onepasswordRead`, `onepassword`). `op` must be
  signed in for templated files and package installs to render.
- git `autoCommit` and `autoPush` are **on** (`.chezmoi.toml.tmpl`): chezmoi's own
  source-writing commands commit and push automatically. Manual edits still need a
  normal `git commit`, but assume the working tree is expected to stay clean.

## chezmoi naming conventions (how source names map to `$HOME`)

The filename encodes the target path and attributes. Common prefixes/suffixes:

- `dot_foo` → `~/.foo` (e.g. `dot_gitconfig` → `~/.gitconfig`)
- `private_foo` → applied with `0600` perms (e.g. `private_dot_ssh/` → `~/.ssh/`)
- `foo.tmpl` → rendered as a Go template (chezmoi funcs + 1Password) before writing
- `run_once_*.sh` → script run once ever, `run_onchange_*.sh` → run when its
  *contents* change, `run_after_*` / `run_before_*` → ordering relative to file apply
- Leading-dot files (`.chezmoi*`, `.install-prerequisites.sh`, `.startup.sh`,
  `.set-keyboard.sh`, `.update-zed-config.sh`) are chezmoi control files or
  standalone helper scripts — they are **not** applied to `$HOME`.

`.chezmoiignore` lists source files that are intentionally *not* deployed (README,
this CLAUDE.md, `claude-configs/`, `.claude/`, and OS/profile-conditional paths).
When you add a top-level doc/helper that should not land in `$HOME`, add it here.

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

## Package management (macOS / Homebrew / mas / Fisher)

Packages are **declared** in `.chezmoidata/packages.yaml`, not installed ad hoc.
`run_onchange_install-packages.sh.tmpl` builds a Brewfile from that data, trusts
non-official taps, runs `brew bundle`, and **removes anything installed but not
declared**. Same reconciliation applies to `mas` apps and Fisher plugins.

Helper scripts (all take `--work | --private | --auto`, default `--auto`):
- `./audit-packages.sh` — report installed-but-undeclared packages (read-only).
- `./cleanup-packages.sh [--dry-run]` — remove undeclared packages.
- `./reconcile-packages.sh` — interactively add-to-yaml or remove, per package.
- `_package-helpers.sh` — shared library; sourced, not run directly.

To add a package: edit `packages.yaml` (correct section), then `chezmoi apply`
(re-runs the install script because the data hash changes). See the
`manage-packages` skill.

## Other managed surfaces

- **fish** (`dot_config/fish/`): `config.fish.tmpl`, `conf.d/*` (per-tool env,
  some `.tmpl` for secrets), `functions/*`. Fish is the default shell.
- **mise** (`dot_config/mise/config.toml.tmpl`): runtime versions (node, go, rust,
  ruby/python on work). Installed via `mise install -y` inside the package script.
- **Zed** (`dot_config/zed/`): editor config. `./update-zed-config.sh` pulls the
  *live* `~/.config/zed` settings back into the repo (reverse of apply) — use it
  after changing settings in the Zed UI, then commit.
- **git** (`dot_gitconfig.tmpl`): aliases, delta pager, GPG signing (macOS),
  `insteadOf` git@ rewrite. Signing key comes from 1Password.
- **pi agent** (`dot_pi/agent/`): Earendil pi coding-agent config + a work-only
  `terraform-workflow` extension package (guards generated-file edits and
  acceptance tests). `AGENTS.md` holds pi's dev preferences.
- **claude-configs/terraform/**: reference CLAUDE.md + agent config for the
  HashiCorp Terraform repo. Not deployed by chezmoi (it's ignored); it's a
  drop-in for that project.

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
