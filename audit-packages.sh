#!/usr/bin/env bash
# Audit installed packages against the expected list in packages.yaml.
# Warns about packages that are installed but not declared.
#
# Usage: ./audit-packages.sh [--work | --private | --auto]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_package-helpers.sh"

PROFILE="$(detect_profile "${1:---auto}")" || { echo "Usage: $0 [--work | --private | --auto]" >&2; exit 1; }

echo "Auditing packages (profile: $PROFILE)"
echo "================================================"

build_expected_sets
find_offending

warnings=0

echo ""
echo "Homebrew formulae (leaves only)"
echo "---"
if [[ ${#offending_brews[@]} -gt 0 ]]; then
    for pkg in "${offending_brews[@]}"; do
        echo "  ⚠ $pkg"
    done
    warnings=$((warnings + ${#offending_brews[@]}))
else
    echo "  ✓ all clean"
fi

echo ""
echo "Homebrew casks"
echo "---"
if [[ ${#offending_casks[@]} -gt 0 ]]; then
    for pkg in "${offending_casks[@]}"; do
        echo "  ⚠ $pkg"
    done
    warnings=$((warnings + ${#offending_casks[@]}))
else
    echo "  ✓ all clean"
fi

echo ""
echo "Homebrew taps"
echo "---"
if [[ ${#offending_taps[@]} -gt 0 ]]; then
    for tap in "${offending_taps[@]}"; do
        echo "  ⚠ $tap"
    done
    warnings=$((warnings + ${#offending_taps[@]}))
else
    echo "  ✓ all clean"
fi

echo ""
echo "Mac App Store"
echo "---"
if [[ ${#offending_mas_names[@]} -gt 0 ]]; then
    for name in "${offending_mas_names[@]}"; do
        echo "  ⚠ $name"
    done
    warnings=$((warnings + ${#offending_mas_names[@]}))
else
    echo "  ✓ all clean"
fi

echo ""
echo "Fisher plugins"
echo "---"
if [[ ${#offending_fisher[@]} -gt 0 ]]; then
    for plugin in "${offending_fisher[@]}"; do
        echo "  ⚠ $plugin"
    done
    warnings=$((warnings + ${#offending_fisher[@]}))
else
    echo "  ✓ all clean"
fi

echo ""
echo "================================================"
if [[ $warnings -gt 0 ]]; then
    echo "$warnings package(s) installed but not declared in packages.yaml"
    exit 1
else
    echo "All installed packages are accounted for."
    exit 0
fi
