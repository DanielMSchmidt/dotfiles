#!/usr/bin/env bash
# Shared helpers for audit-packages.sh and cleanup-packages.sh.
# Source this file; do not execute directly.

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_YAML="$SCRIPT_DIR/.chezmoidata/packages.yaml"

if [[ ! -f "$PACKAGES_YAML" ]]; then
    echo "Error: $PACKAGES_YAML not found" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >&2
    exit 1
fi

# --- Profile detection ---

detect_profile() {
    case "${1:---auto}" in
        --work)    echo "work" ;;
        --private) echo "private" ;;
        --auto)
            local chezmoi_config="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
            if [[ -f "$chezmoi_config" ]] && grep -q 'isWorkComputer = true' "$chezmoi_config"; then
                echo "work"
            else
                echo "private"
            fi
            ;;
        *) return 1 ;;
    esac
}

# --- YAML parser ---
# Extracts flat list of values from packages.<subsection>.<key> in packages.yaml.
extract_list() {
    local subsection="$1" key="$2"
    local in_sub=0 in_key=0

    while IFS= read -r line; do
        if [[ "$line" =~ ^"    ${subsection}:" ]]; then
            in_sub=1; in_key=0; continue
        fi
        if [[ $in_sub -eq 1 && "$line" =~ ^"    "[a-z] && ! "$line" =~ ^"    ${subsection}:" ]]; then
            in_sub=0; in_key=0; continue
        fi
        if [[ $in_sub -eq 1 ]]; then
            if [[ "$line" =~ ^"        ${key}:" ]]; then
                [[ "$line" == *"[]"* ]] && { in_key=0; continue; }
                in_key=1; continue
            fi
            if [[ "$line" =~ ^"        "[a-z] ]]; then
                in_key=0; continue
            fi
        fi
        if [[ $in_key -eq 1 ]]; then
            if [[ "$line" =~ name:[[:space:]]+\"([^\"]+)\" ]]; then
                echo "${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+id: ]]; then
                continue
            elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]+\"([^\"]+)\" ]]; then
                echo "${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+) ]]; then
                echo "${BASH_REMATCH[1]}"
            fi
        fi
    done < "$PACKAGES_YAML"
}

# Collect expected values for a key across universal + profile
collect() {
    extract_list universal "$1"
    extract_list "$PROFILE" "$1"
}

# --- Build expected sets ---
# Populates associative arrays: expected_brews, expected_casks, expected_taps, expected_mas, expected_fisher
# Also populates indexed arrays: expected_brew_raw, expected_cask_raw, expected_tap_raw

build_expected_sets() {
    # Brews
    readarray -t expected_brew_raw < <(collect brews)
    declare -gA expected_brews
    if [[ ${#expected_brew_raw[@]} -gt 0 ]]; then
        while IFS= read -r canonical; do
            [[ -n "$canonical" ]] && expected_brews["$canonical"]=1
        done < <(brew info --json=v2 "${expected_brew_raw[@]}" 2>/dev/null | jq -r '.formulae[].name' 2>/dev/null)
        for raw in "${expected_brew_raw[@]}"; do
            expected_brews["${raw##*/}"]=1
        done
    fi

    # Casks
    readarray -t expected_cask_raw < <(collect casks)
    declare -gA expected_casks
    if [[ ${#expected_cask_raw[@]} -gt 0 ]]; then
        while IFS= read -r token; do
            [[ -n "$token" ]] && expected_casks["$token"]=1
        done < <(brew info --cask --json=v2 "${expected_cask_raw[@]}" 2>/dev/null | jq -r '.casks[].token' 2>/dev/null)
        for raw in "${expected_cask_raw[@]}"; do
            expected_casks["$raw"]=1
        done
    fi

    # Taps
    readarray -t expected_tap_raw < <(collect taps)
    declare -gA expected_taps
    for tap in "${expected_tap_raw[@]}"; do
        [[ -n "$tap" ]] && expected_taps["$tap"]=1
    done
    expected_taps["homebrew/bundle"]=1
    expected_taps["homebrew/core"]=1
    expected_taps["homebrew/cask"]=1
    for raw in "${expected_brew_raw[@]}" "${expected_cask_raw[@]}"; do
        if [[ "$raw" == */*/* ]]; then
            expected_taps["${raw%/*}"]=1
        fi
    done
    for tap in "${expected_tap_raw[@]}"; do
        if [[ "$tap" == */homebrew-* ]]; then
            expected_taps["${tap/\/homebrew-//}"]=1
        fi
    done

    # MAS
    readarray -t expected_mas_names < <(collect mas)
    declare -gA expected_mas
    for name in "${expected_mas_names[@]}"; do
        [[ -n "$name" ]] && expected_mas["$name"]=1
    done

    # Fisher
    readarray -t expected_fisher_raw < <(collect fisher)
    declare -gA expected_fisher
    for plugin in "${expected_fisher_raw[@]}"; do
        [[ -n "$plugin" ]] && expected_fisher["${plugin,,}"]=1
    done
}

# --- Find offending packages ---
# Populates arrays: offending_brews, offending_casks, offending_taps, offending_mas_names,
#                    offending_mas_ids, offending_fisher

find_offending() {
    offending_brews=()
    offending_casks=()
    offending_taps=()
    offending_mas_names=()
    offending_mas_ids=()
    offending_fisher=()

    if command -v brew &>/dev/null; then
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            local short="${pkg##*/}"
            if [[ -z "${expected_brews[$short]+x}" && -z "${expected_brews[$pkg]+x}" ]]; then
                offending_brews+=("$pkg")
            fi
        done < <(brew leaves 2>/dev/null)

        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            if [[ -z "${expected_casks[$pkg]+x}" ]]; then
                offending_casks+=("$pkg")
            fi
        done < <(brew list --cask -1 2>/dev/null)

        while IFS= read -r tap; do
            [[ -z "$tap" ]] && continue
            if [[ -z "${expected_taps[$tap]+x}" ]]; then
                offending_taps+=("$tap")
            fi
        done < <(brew tap 2>/dev/null)
    fi

    if command -v mas &>/dev/null; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local id name
            id="$(echo "$line" | sed -E 's/^[[:space:]]*([0-9]+).*/\1/')"
            name="$(echo "$line" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' | sed -E 's/[[:space:]]+\([^)]*\)[[:space:]]*$//')"
            [[ -z "$name" ]] && continue
            if [[ -z "${expected_mas[$name]+x}" ]]; then
                offending_mas_names+=("$name")
                offending_mas_ids+=("$id")
            fi
        done < <(mas list 2>/dev/null)
    fi

    if command -v fish &>/dev/null; then
        while IFS= read -r plugin; do
            [[ -z "$plugin" ]] && continue
            if [[ -z "${expected_fisher[${plugin,,}]+x}" ]]; then
                offending_fisher+=("$plugin")
            fi
        done < <(fish -c 'fisher list 2>/dev/null' 2>/dev/null)
    fi
}
