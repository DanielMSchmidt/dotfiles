#!/bin/zsh
# vicinae script command — Spotify transport control via AppleScript.
#
# AppleScript rather than the Web API on purpose: no client id, no OAuth token
# to refresh, and it drives whatever is already playing locally. The Raycast
# spotify-player extension is listed as "partial" in vicinae's compat tracker
# and needs a Premium account for playback, so this stays a script command.
#
# @vicinae.schemaVersion 1
# @vicinae.title Spotify: Play / Pause
# @vicinae.mode silent
# @vicinae.packageName Spotify
# @vicinae.icon 🎵
# @vicinae.keywords ["play", "pause"]

exec osascript -e 'tell application "Spotify" to playpause'
