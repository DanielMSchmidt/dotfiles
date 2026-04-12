#!/usr/bin/env bash
# Remove installed packages that are not declared in packages.yaml.
#
# Usage: ./cleanup-packages.sh [--work | --private | --auto] [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_package-helpers.sh"

dry_run=0
profile_arg="--auto"
for arg in "$@"; do
    case "$arg" in
        --dry-run)  dry_run=1 ;;
        --work|--private|--auto) profile_arg="$arg" ;;
        *) echo "Usage: $0 [--work | --private | --auto] [--dry-run]" >&2; exit 1 ;;
    esac
done

PROFILE="$(detect_profile "$profile_arg")" || { echo "Usage: $0 [--work | --private | --auto] [--dry-run]" >&2; exit 1; }

echo "Detecting undeclared packages (profile: $PROFILE)..."
build_expected_sets
find_offending

total=$((${#offending_brews[@]} + ${#offending_casks[@]} + ${#offending_taps[@]} + ${#offending_mas_names[@]} + ${#offending_fisher[@]}))

if [[ $total -eq 0 ]]; then
    echo "Nothing to remove — all installed packages are declared."
    exit 0
fi

# --- Preview ---
echo ""
echo "The following $total package(s) will be removed:"
echo "================================================"

if [[ ${#offending_brews[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew formulae (${#offending_brews[@]}):"
    for pkg in "${offending_brews[@]}"; do echo "  - $pkg"; done
fi

if [[ ${#offending_casks[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew casks (${#offending_casks[@]}):"
    for pkg in "${offending_casks[@]}"; do echo "  - $pkg"; done
fi

if [[ ${#offending_taps[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew taps (${#offending_taps[@]}):"
    for tap in "${offending_taps[@]}"; do echo "  - $tap"; done
fi

if [[ ${#offending_mas_names[@]} -gt 0 ]]; then
    echo ""
    echo "Mac App Store apps (${#offending_mas_names[@]}):"
    for i in "${!offending_mas_names[@]}"; do
        echo "  - ${offending_mas_names[$i]} (id: ${offending_mas_ids[$i]})"
    done
fi

if [[ ${#offending_fisher[@]} -gt 0 ]]; then
    echo ""
    echo "Fisher plugins (${#offending_fisher[@]}):"
    for plugin in "${offending_fisher[@]}"; do echo "  - $plugin"; done
fi

echo ""
echo "================================================"

if [[ $dry_run -eq 1 ]]; then
    echo "(dry run — no changes made)"
    exit 0
fi

read -rp "Proceed with removal? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
errors=0

# --- Remove formulae first (before untapping) ---
if [[ ${#offending_brews[@]} -gt 0 ]]; then
    echo "Removing formulae..."
    for pkg in "${offending_brews[@]}"; do
        echo "  brew uninstall $pkg"
        if ! brew uninstall "$pkg" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# --- Remove casks ---
if [[ ${#offending_casks[@]} -gt 0 ]]; then
    echo "Removing casks..."
    for pkg in "${offending_casks[@]}"; do
        echo "  brew uninstall --cask $pkg"
        if ! brew uninstall --cask "$pkg" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# --- Untap (after formulae/casks are gone) ---
if [[ ${#offending_taps[@]} -gt 0 ]]; then
    echo "Removing taps..."
    for tap in "${offending_taps[@]}"; do
        echo "  brew untap $tap"
        if ! brew untap "$tap" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# --- MAS ---
if [[ ${#offending_mas_names[@]} -gt 0 ]]; then
    echo "Removing App Store apps..."
    for i in "${!offending_mas_names[@]}"; do
        echo "  mas uninstall ${offending_mas_ids[$i]}  # ${offending_mas_names[$i]}"
        if ! mas uninstall "${offending_mas_ids[$i]}" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# --- Fisher ---
if [[ ${#offending_fisher[@]} -gt 0 ]]; then
    echo "Removing Fisher plugins..."
    for plugin in "${offending_fisher[@]}"; do
        echo "  fisher remove $plugin"
        if ! fish -c "fisher remove '$plugin'" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# --- Cleanup orphaned dependencies ---
if command -v brew &>/dev/null && [[ ${#offending_brews[@]} -gt 0 || ${#offending_casks[@]} -gt 0 ]]; then
    echo ""
    echo "Cleaning up orphaned dependencies..."
    brew autoremove 2>&1 | sed 's/^/  /'
fi

echo ""
echo "================================================"
if [[ $errors -gt 0 ]]; then
    echo "Done with $errors error(s)."
    exit 1
else
    echo "Done. All undeclared packages removed."
fi
