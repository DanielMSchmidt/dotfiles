#!/bin/zsh
# vicinae script command — see play-pause.sh for why this is AppleScript.
#
# @vicinae.schemaVersion 1
# @vicinae.title Spotify: Previous Track
# @vicinae.mode silent
# @vicinae.packageName Spotify
# @vicinae.icon ⏪
# @vicinae.keywords ["previous"]

exec osascript -e 'tell application "Spotify" to previous track'
