#!/bin/zsh
# vicinae script command — sleep the display only, leaving the machine awake.
#
# The only power action still needing a script: sleep, lock, reboot, power off
# and log out are all built into vicinae's "power" extension (aliased in
# settings.json), but nothing there sleeps just the display.
#
# @vicinae.schemaVersion 1
# @vicinae.title System: Sleep Display
# @vicinae.mode silent
# @vicinae.packageName System
# @vicinae.icon 💤
# @vicinae.keywords ["sleep display"]

exec pmset displaysleepnow
