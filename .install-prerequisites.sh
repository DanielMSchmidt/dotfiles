#!/bin/bash
set -ex

if type op >/dev/null 2>&1; then
    echo "1Password CLI is already installed"
else
    case "$(uname -s)" in
    Darwin)
        brew install --cask 1password
        brew install 1password-cli
        ;;
    *)
        echo "unsupported OS"
        exit 1
        ;;
    esac
fi

read -p "Please open 1Password, log into all accounts and set under Settings>CLI activate Integrate with 1Password CLI. Press any key to continue." -n 1 -r
echo
