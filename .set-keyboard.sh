echo "Set keyboard layout to US International PC"
###
# Original script by Evita Stenqvist
###
killall 'System Preferences' &>/dev/null

defaults write com.apple.HIToolbox AppleEnabledInputSources -array '<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>15000</integer><key>KeyboardLayout Name</key><string>USInternational-PC</string></dict>'
defaults write com.apple.HIToolbox AppleSelectedInputSources -array '<dict><key>InputSourceKind</key><string>Keyboard Layout</string><key>KeyboardLayout ID</key><integer>15000</integer><key>KeyboardLayout Name</key><string>USInternational-PC</string></dict>'
defaults write com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID com.apple.keylayout.USInternational-PC

killall 'System Preferences' &>/dev/null

# Set defaults for the Dock
# Will autohide and magnify!
defaults write com.apple.dock autohide 1
