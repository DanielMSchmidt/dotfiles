#!/bin/bash

set -ex

# This script installs everything from scratch. It is meant to be used through a curl to bash command.

# Install XCode Command Line Tools if necessary
xcode-select --install || echo "XCode already installed"

# Install Homebrew if necessary
if which -s brew; then
    echo 'Homebrew is already installed'
else
    sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (
        echo
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    ) >>$HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

brew install chezmoi
chezmoi init danielmschmidt
chezmoi apply
