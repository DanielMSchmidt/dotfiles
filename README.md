# My dotfiles

> managed by [chezmoi](https://www.chezmoi.io/)

## Setup

**Install Xcode Command Line Tools**
```bash
xcode-select --install
```

**Install Homebrew**
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> /Users/daniel.banck/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Setup 1Password**
```
brew install --cask 1password
```
Manually add your accounts now.

**Install chezmoi and apply configuration**
```bash
brew install chezmoi
chezmoi init danielmschmidt
chezmoi apply
```

**Final touches**
```bash
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish
```


## TODOs

- setup mise
- setup signing key
