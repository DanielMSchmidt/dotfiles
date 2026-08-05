#!/bin/zsh
# vicinae script command — restart vicinae itself, e.g. to pick up a
# `chezmoi apply` that rewrote ~/.config/vicinae/settings.json.
#
# Restarting vicinae from inside vicinae: the relaunch has to outlive the
# process that spawned it. `nohup ... &` detaches the helper, so when pkill
# takes the app down the helper is orphaned to launchd and keeps running. It
# then waits for the old process to actually disappear (up to ~10s) before
# `open`, otherwise LaunchServices just focuses the dying instance instead of
# starting a new one. `pgrep/pkill -x` match the executable name exactly, so
# the helper — running as `zsh` — never matches itself.
#
# The name is capital-V `Vicinae`: that is CFBundleExecutable in the macOS app
# bundle. The Linux binary is lowercase `vicinae`, which is what the upstream
# source tree shows — `pkill -x vicinae` here matches nothing at all.
#
# `vicinae server --replace` would also work, but it execs the server binary
# directly instead of going through LaunchServices, which is how the app bundle
# gets its Accessibility identity (needed for the global hotkey's event tap).
#
# Most settings do not need this: vicinae watches settings.json and reloads it,
# and rescans the script directories on change. This is the escape hatch.
#
# @vicinae.schemaVersion 1
# @vicinae.title Vicinae: Restart
# @vicinae.mode silent
# @vicinae.packageName Vicinae
# @vicinae.icon 🔁
# @vicinae.keywords ["restart vicinae"]

nohup zsh -c 'for _ in {1..50}; do pgrep -x Vicinae >/dev/null || break; sleep 0.2; done; open -a Vicinae' \
    >/dev/null 2>&1 &
exec pkill -x Vicinae
