#!/bin/zsh
# vicinae script command — restart vicinae itself.
#
# Rarely needed. vicinae watches ~/.config/vicinae/settings.json and reloads it
# in place, and it rescans the script directories on change (plus every 15
# minutes); "Reload Script Directories" (core:reload-scripts) forces just that
# rescan. This is the escape hatch for the cases neither covers.
#
# The whole restart happens in a detached helper, and this script must exit
# *before* vicinae is signalled. That ordering is the entire point:
#
#   vicinae runs a silent-mode script as a QProcess it is still waiting on, and
#   wires QProcess::errorOccurred to toastService()->failure() (see
#   script-actions.cpp, executeOneLine). Killing vicinae from the foreground of
#   this script means Qt tears that QProcess down mid-flight, sees the child die
#   by signal, and reports "Failed to execute script" — even though the restart
#   worked. So: exit cleanly first, let vicinae reap us and show the HUD, and
#   only then let the helper pull the rug.
#
# The helper is orphaned to launchd when this script exits, and `nohup` plus the
# redirects keep it off vicinae's stdout — an inherited pipe would hold the
# QProcess output channel open. It waits for the old process to actually
# disappear (up to ~10s) before `open`, otherwise LaunchServices just focuses
# the dying instance instead of starting a new one. `pgrep/pkill -x` match the
# executable name exactly, so the helper — running as `zsh` — never matches
# itself.
#
# The name is capital-V `Vicinae`: that is CFBundleExecutable in the macOS app
# bundle. The Linux binary is lowercase `vicinae`, which is what the upstream
# source tree shows — `pkill -x vicinae` here matches nothing at all.
#
# SIGTERM rather than `quit app "Vicinae"` because AppleScript would need an
# Automation grant; vicinae keeps no dirty in-memory state that a graceful quit
# would flush (config writes are explicit, clipboard history is committed per
# insert). `vicinae server --replace` is also avoided: it execs the server
# binary directly instead of going through LaunchServices.
#
# @vicinae.schemaVersion 1
# @vicinae.title Vicinae: Restart
# @vicinae.mode silent
# @vicinae.packageName Vicinae
# @vicinae.icon 🔁
# @vicinae.keywords ["restart vicinae"]

nohup zsh -c '
    sleep 1
    pkill -x Vicinae
    for _ in {1..50}; do pgrep -x Vicinae >/dev/null || break; sleep 0.2; done
    open -a Vicinae
' >/dev/null 2>&1 &

# First stdout line becomes the HUD text in silent mode.
echo "Restarting Vicinae…"
