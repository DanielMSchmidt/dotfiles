#!/bin/zsh
# vicinae script command — recall a Philips Hue scene.
#
# zsh (not sh) on purpose: vicinae is started by LaunchServices with a minimal
# PATH, and ~/.zshenv sources ~/.config/shell/env.sh, which is what puts
# Homebrew's curl/jq — needed by the hue CLI — on PATH.
#
# @vicinae.schemaVersion 1
# @vicinae.title Hue Bedroom (Schlafzimmer): Off
# @vicinae.mode silent
# @vicinae.packageName Hue
# @vicinae.icon 🌑
# @vicinae.keywords ["bedroom off", "hue"]
# @vicinae.description Recall the "Off" scene for Bedroom (Schlafzimmer).

exec "$HOME/.local/bin/hue" bedroom off
