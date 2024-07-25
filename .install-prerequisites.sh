#!/bin/sh
set -e

# exit immediately if password-manager-binary is already in $PATH
type op >/dev/null 2>&1 && exit 0
if type op >/dev/null 2>&1; then
    echo "1Password CLI is already installed, assuming you are logged in already."
else
    case "$(uname -s)" in
    Darwin)
        brew install --cask 1password
        brew install 1password-cli

        # TODO: Possibly check for accounts before signing in
        op account add "EI6GPO6VNJAVLGDDID3B75JI6E"
        read -p "Is this a work computer? (y/Y)" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            op account add "2HZZS3CSKVA7REGL25XWFDGOPE"
        fi
        ;;
    *)
        echo "unsupported OS"
        exit 1
        ;;
    esac

fi
