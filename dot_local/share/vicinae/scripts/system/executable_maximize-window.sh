#!/bin/zsh
# vicinae script command — maximize the frontmost window of whatever app was
# focused before vicinae was summoned, filling the screen without entering
# macOS native fullscreen (no new Space).
#
# In silent mode vicinae closes its own window when the script runs, handing
# focus back to the previous app — but not instantly, so the script polls until
# the frontmost process is no longer vicinae. "Fill the screen" means the
# screen's *visible frame* (screen minus menu bar and Dock), which System
# Events cannot supply, so it comes from AppKit's NSScreen via ASObjC — from
# the screen the window currently sits on, so multi-display setups maximize in
# place instead of jumping to the primary display. NSScreen uses bottom-left-
# origin coordinates while the Accessibility API uses top-left, hence the
# primaryH - (y + h) flip. Needs Accessibility (vicinae already has it for the
# snippet server); windows that can't be resized just no-op via the `try`.
#
# @vicinae.schemaVersion 1
# @vicinae.title System: Maximize Window
# @vicinae.mode silent
# @vicinae.packageName System
# @vicinae.icon 🖥️
# @vicinae.keywords ["maximize", "fullscreen", "full screen"]

exec osascript <<'APPLESCRIPT'
use framework "AppKit"
use scripting additions

on run
	tell application "System Events"
		set frontApp to missing value
		repeat 30 times
			set frontApp to first application process whose frontmost is true
			if name of frontApp is not "vicinae" then exit repeat
			delay 0.1
		end repeat
		if frontApp is missing value or name of frontApp is "vicinae" then return
		try
			set {wx, wy} to position of window 1 of frontApp
		on error
			return
		end try
	end tell
	set {vx, vy, vw, vh} to my visibleFrameContaining(wx, wy)
	tell application "System Events"
		try
			tell window 1 of frontApp
				set position to {vx, vy}
				set size to {vw, vh}
			end tell
		end try
	end tell
end run

-- Visible frame (screen minus menu bar and Dock) of the screen containing the
-- point (wx, wy), given in Accessibility top-left-origin coordinates, returned
-- as {x, y, w, h} in those same coordinates.
on visibleFrameContaining(wx, wy)
	set screensArr to current application's NSScreen's screens()
	set primaryH to item 2 of item 2 of ((screensArr's firstObject()'s frame()) as list)
	set cocoaY to primaryH - wy
	repeat with scr in (screensArr as list)
		set {{fx, fy}, {fw, fh}} to (scr's frame()) as list
		if wx >= fx and wx < fx + fw and cocoaY > fy and cocoaY <= fy + fh then
			set {{sx, sy}, {sw, sh}} to (scr's visibleFrame()) as list
			return {sx, primaryH - (sy + sh), sw, sh}
		end if
	end repeat
	set {{sx, sy}, {sw, sh}} to (screensArr's firstObject()'s visibleFrame()) as list
	return {sx, primaryH - (sy + sh), sw, sh}
end visibleFrameContaining
APPLESCRIPT
