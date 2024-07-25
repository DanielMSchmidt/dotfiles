#!/bin/sh
set -e

if type op >/dev/null 2>&1; then
    echo "1Password CLI is already installed, assuming you are logged in already."
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

# Check if the account is signed in
PERSONAL_ACCOUNT="EI6GPO6VNJAVLGDDID3B75JI6E"
WORK_ACCOUNT="2HZZS3CSKVA7REGL25XWFDGOPE"

if op vault list --account $PERSONAL_ACCOUNT >/dev/null 2>&1; then
    echo "Already logged into personal account"
else
    op account add --account $PERSONAL_ACCOUNT
fi

read -p "Is this a work computer? (y/Y)" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if op vault list --account $WORK_ACCOUNT >/dev/null 2>&1; then
        echo "Already logged into work account"
    else
        op account add --account $WORK_ACCOUNT
    fi
fi
