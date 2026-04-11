#!/bin/bash
set -ex

case "$(uname -s)" in
Darwin)
    if type op >/dev/null 2>&1; then
        echo "1Password CLI is already installed"
    else
        brew install --cask 1password
        brew install 1password-cli git fish wget gpg fisher gh
        fisher install IlanCosman/tide@v6
    fi

    read -p "Please open 1Password, log into all accounts and set under Settings>CLI activate Integrate with 1Password CLI. Press any key to continue." -n 1 -r
    echo
    ;;
Linux)
    echo "Linux detected — skipping 1Password and Homebrew"
    if ! type fish >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y fish
    fi
    # Install fisher + tide if not present
    if [ ! -f "$HOME/.config/fish/functions/fisher.fish" ]; then
        fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
        fish -c 'fisher install IlanCosman/tide@v6'
    fi
    ;;
*)
    echo "unsupported OS"
    exit 1
    ;;
esac
