#!/bin/bash

set -ex

# Setup fish shell
echo "> Install fish shell"
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

echo "> Install fish plugins & themes"
fish -c "omf install"

echo "Setting finder preferences"
# Show all files
defaults write com.apple.finder AppleShowAllFiles YES

# Open text files with Zed Preview
duti -s dev.zed.Zed-Preview public.json all
duti -s dev.zed.Zed-Preview public.plain-text all
duti -s dev.zed.Zed-Preview public.python-script all
duti -s dev.zed.Zed-Preview public.shell-script all
duti -s dev.zed.Zed-Preview public.source-code all
duti -s dev.zed.Zed-Preview public.text all
duti -s dev.zed.Zed-Preview public.unix-executable all
# this works for files without a filename extension
duti -s dev.zed.Zed-Preview public.data all

duti -s dev.zed.Zed-Preview .c all
duti -s dev.zed.Zed-Preview .cpp all
duti -s dev.zed.Zed-Preview .cs all
duti -s dev.zed.Zed-Preview .css all
duti -s dev.zed.Zed-Preview .go all
duti -s dev.zed.Zed-Preview .java all
duti -s dev.zed.Zed-Preview .js all
duti -s dev.zed.Zed-Preview .sass all
duti -s dev.zed.Zed-Preview .scss all
duti -s dev.zed.Zed-Preview .less all
duti -s dev.zed.Zed-Preview .vue all
duti -s dev.zed.Zed-Preview .cfg all
duti -s dev.zed.Zed-Preview .json all
duti -s dev.zed.Zed-Preview .jsx all
duti -s dev.zed.Zed-Preview .log all
duti -s dev.zed.Zed-Preview .lua all
duti -s dev.zed.Zed-Preview .md all
duti -s dev.zed.Zed-Preview .php all
duti -s dev.zed.Zed-Preview .pl all
duti -s dev.zed.Zed-Preview .py all
duti -s dev.zed.Zed-Preview .rb all
duti -s dev.zed.Zed-Preview .ts all
duti -s dev.zed.Zed-Preview .tsx all
duti -s dev.zed.Zed-Preview .txt all
duti -s dev.zed.Zed-Preview .conf all
duti -s dev.zed.Zed-Preview .yaml all
duti -s dev.zed.Zed-Preview .yml all
duti -s dev.zed.Zed-Preview .toml all

killall Finder

echo "Installing dev tools"
fish -c "go install github.com/mitranim/gow@latest"

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
