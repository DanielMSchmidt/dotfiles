#!/usr/bin/env bash
# Interactive package reconciliation.
# For each undeclared package, choose to add it to packages.yaml or remove it.
#
# Usage: ./reconcile-packages.sh [--work | --private | --auto]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_package-helpers.sh"

PROFILE="$(detect_profile "${1:---auto}")" || { echo "Usage: $0 [--work | --private | --auto]" >&2; exit 1; }

echo "Detecting undeclared packages (profile: $PROFILE)..."
build_expected_sets
find_offending

total=$((${#offending_brews[@]} + ${#offending_casks[@]} + ${#offending_taps[@]} + ${#offending_mas_names[@]} + ${#offending_fisher[@]}))

if [[ $total -eq 0 ]]; then
    echo "Nothing to reconcile — all installed packages are declared."
    exit 0
fi

# --- YAML editing helpers ---

# Add a simple list item (brews, casks, taps, fisher) to packages.yaml
yaml_add_item() {
    local subsection="$1" key="$2" value="$3"
    local indent="            "

    awk -v tgt="    ${subsection}:" \
        -v keyline="        ${key}:" \
        -v newitem="${indent}- \"${value}\"" \
        -v emptykey="        ${key}: []" \
    '
    BEGIN { state="searching"; d=0 }
    {
        if (d) { print; next }
        if (state == "searching") {
            if (index($0, tgt) == 1 && length($0) == length(tgt)) state = "in_sub"
            print; next
        }
        if (state == "in_sub") {
            if (index($0, emptykey) == 1 && length($0) == length(emptykey)) { print keyline; print newitem; d = 1; next }
            if (index($0, keyline) == 1) { state = "in_key"; print; next }
            if (/^    [a-z]/ && !(index($0, tgt) == 1 && length($0) == length(tgt))) { state = "searching" }
            print; next
        }
        if (state == "in_key") {
            if (/^            / || /^              /) { print; next }
            print newitem; d = 1; print; next
        }
    }
    END { if (state == "in_key" && !d) print newitem }
    ' "$PACKAGES_YAML" > "${PACKAGES_YAML}.tmp" && mv "${PACKAGES_YAML}.tmp" "$PACKAGES_YAML"
}

# Add a mas entry (name + id) to packages.yaml
yaml_add_mas() {
    local subsection="$1" name="$2" id="$3"

    awk -v tgt="    ${subsection}:" \
        -v keyline="        mas:" \
        -v item1="            - name: \"${name}\"" \
        -v item2="              id: \"${id}\"" \
        -v emptykey="        mas: []" \
    '
    BEGIN { state="searching"; d=0 }
    {
        if (d) { print; next }
        if (state == "searching") {
            if (index($0, tgt) == 1 && length($0) == length(tgt)) state = "in_sub"
            print; next
        }
        if (state == "in_sub") {
            if (index($0, emptykey) == 1 && length($0) == length(emptykey)) { print keyline; print item1; print item2; d = 1; next }
            if (index($0, keyline) == 1) { state = "in_key"; print; next }
            if (/^    [a-z]/ && !(index($0, tgt) == 1 && length($0) == length(tgt))) { state = "searching" }
            print; next
        }
        if (state == "in_key") {
            if (/^            / || /^              /) { print; next }
            print item1; print item2; d = 1; print; next
        }
    }
    END { if (state == "in_key" && !d) { print item1; print item2 } }
    ' "$PACKAGES_YAML" > "${PACKAGES_YAML}.tmp" && mv "${PACKAGES_YAML}.tmp" "$PACKAGES_YAML"
}

# --- Interactive prompt ---

# Prompt for a single package. Sets $choice to "add", "remove", or "skip".
# Returns 1 if a bulk action was chosen (sets $bulk to the action).
bulk=""

prompt_choice() {
    local label="$1"
    if [[ -n "$bulk" ]]; then
        choice="$bulk"
        return
    fi

    while true; do
        printf "  %-40s [a]dd [r]emove [s]kip | all: [A]dd [R]em [S]kip: " "$label"
        read -rn1 key
        echo ""
        case "$key" in
            a) choice="add"; return ;;
            r) choice="remove"; return ;;
            s) choice="skip"; return ;;
            A) choice="add";    bulk="add";    return ;;
            R) choice="remove"; bulk="remove"; return ;;
            S) choice="skip";   bulk="skip";   return ;;
            *) echo "    Invalid choice, try again." ;;
        esac
    done
}

# --- Collection phase ---

add_brews=()
add_casks=()
add_taps=()
add_mas_names=()
add_mas_ids=()
add_fisher=()

remove_brews=()
remove_casks=()
remove_taps=()
remove_mas_names=()
remove_mas_ids=()
remove_fisher=()

if [[ ${#offending_brews[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew formulae (${#offending_brews[@]} undeclared)"
    echo "---"
    bulk=""
    for pkg in "${offending_brews[@]}"; do
        prompt_choice "$pkg"
        case "$choice" in
            add)    add_brews+=("$pkg") ;;
            remove) remove_brews+=("$pkg") ;;
        esac
    done
fi

if [[ ${#offending_casks[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew casks (${#offending_casks[@]} undeclared)"
    echo "---"
    bulk=""
    for pkg in "${offending_casks[@]}"; do
        prompt_choice "$pkg"
        case "$choice" in
            add)    add_casks+=("$pkg") ;;
            remove) remove_casks+=("$pkg") ;;
        esac
    done
fi

if [[ ${#offending_taps[@]} -gt 0 ]]; then
    echo ""
    echo "Homebrew taps (${#offending_taps[@]} undeclared)"
    echo "---"
    bulk=""
    for tap in "${offending_taps[@]}"; do
        prompt_choice "$tap"
        case "$choice" in
            add)    add_taps+=("$tap") ;;
            remove) remove_taps+=("$tap") ;;
        esac
    done
fi

if [[ ${#offending_mas_names[@]} -gt 0 ]]; then
    echo ""
    echo "Mac App Store (${#offending_mas_names[@]} undeclared)"
    echo "---"
    bulk=""
    for i in "${!offending_mas_names[@]}"; do
        prompt_choice "${offending_mas_names[$i]}"
        case "$choice" in
            add)    add_mas_names+=("${offending_mas_names[$i]}"); add_mas_ids+=("${offending_mas_ids[$i]}") ;;
            remove) remove_mas_names+=("${offending_mas_names[$i]}"); remove_mas_ids+=("${offending_mas_ids[$i]}") ;;
        esac
    done
fi

if [[ ${#offending_fisher[@]} -gt 0 ]]; then
    echo ""
    echo "Fisher plugins (${#offending_fisher[@]} undeclared)"
    echo "---"
    bulk=""
    for plugin in "${offending_fisher[@]}"; do
        prompt_choice "$plugin"
        case "$choice" in
            add)    add_fisher+=("$plugin") ;;
            remove) remove_fisher+=("$plugin") ;;
        esac
    done
fi

# --- Auto-add taps for tap-qualified brews/casks being added ---

for pkg in "${add_brews[@]}"; do
    if [[ "$pkg" == */*/* ]]; then
        tap="${pkg%/*}"
        if [[ -z "${expected_taps[$tap]+x}" ]]; then
            already=0
            for t in "${add_taps[@]}"; do
                [[ "$t" == "$tap" ]] && already=1
            done
            if [[ $already -eq 0 ]]; then
                add_taps+=("$tap")
            fi
        fi
    fi
done

# --- Summary ---

total_add=$((${#add_brews[@]} + ${#add_casks[@]} + ${#add_taps[@]} + ${#add_mas_names[@]} + ${#add_fisher[@]}))
total_remove=$((${#remove_brews[@]} + ${#remove_casks[@]} + ${#remove_taps[@]} + ${#remove_mas_names[@]} + ${#remove_fisher[@]}))

echo ""
echo "================================================"
echo "Summary: $total_add to add, $total_remove to remove"
echo "================================================"

if [[ $total_add -gt 0 ]]; then
    echo ""
    echo "Will ADD to packages.yaml (universal):"
    for pkg in "${add_taps[@]}";      do echo "  + tap:    $pkg"; done
    for pkg in "${add_brews[@]}";     do echo "  + brew:   $pkg"; done
    for pkg in "${add_casks[@]}";     do echo "  + cask:   $pkg"; done
    for i in "${!add_mas_names[@]}";  do echo "  + mas:    ${add_mas_names[$i]} (${add_mas_ids[$i]})"; done
    for pkg in "${add_fisher[@]}";    do echo "  + fisher: $pkg"; done
fi

if [[ $total_remove -gt 0 ]]; then
    echo ""
    echo "Will REMOVE:"
    for pkg in "${remove_brews[@]}";     do echo "  - brew:   $pkg"; done
    for pkg in "${remove_casks[@]}";     do echo "  - cask:   $pkg"; done
    for pkg in "${remove_taps[@]}";      do echo "  - tap:    $pkg"; done
    for i in "${!remove_mas_names[@]}";  do echo "  - mas:    ${remove_mas_names[$i]}"; done
    for pkg in "${remove_fisher[@]}";    do echo "  - fisher: $pkg"; done
fi

if [[ $total_add -eq 0 && $total_remove -eq 0 ]]; then
    echo "Nothing to do."
    exit 0
fi

echo ""
read -rp "Proceed? [y/N] " confirm
if [[ "$confirm" != [yY] ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
errors=0

# --- Execute additions ---

if [[ $total_add -gt 0 ]]; then
    echo "Updating packages.yaml..."
    for tap in "${add_taps[@]}"; do
        echo "  + tap: $tap"
        yaml_add_item universal taps "$tap"
    done
    for pkg in "${add_brews[@]}"; do
        echo "  + brew: $pkg"
        yaml_add_item universal brews "$pkg"
    done
    for pkg in "${add_casks[@]}"; do
        echo "  + cask: $pkg"
        yaml_add_item universal casks "$pkg"
    done
    for i in "${!add_mas_names[@]}"; do
        echo "  + mas: ${add_mas_names[$i]}"
        yaml_add_mas universal "${add_mas_names[$i]}" "${add_mas_ids[$i]}"
    done
    for pkg in "${add_fisher[@]}"; do
        echo "  + fisher: $pkg"
        yaml_add_item universal fisher "$pkg"
    done
fi

# --- Execute removals (formulae/casks before taps) ---

if [[ ${#remove_brews[@]} -gt 0 ]]; then
    echo "Removing formulae..."
    for pkg in "${remove_brews[@]}"; do
        echo "  brew uninstall $pkg"
        if ! brew uninstall "$pkg" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

if [[ ${#remove_casks[@]} -gt 0 ]]; then
    echo "Removing casks..."
    for pkg in "${remove_casks[@]}"; do
        echo "  brew uninstall --cask $pkg"
        if ! brew uninstall --cask "$pkg" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

if [[ ${#remove_taps[@]} -gt 0 ]]; then
    echo "Removing taps..."
    for tap in "${remove_taps[@]}"; do
        echo "  brew untap $tap"
        if ! brew untap "$tap" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

if [[ ${#remove_mas_names[@]} -gt 0 ]]; then
    echo "Removing App Store apps..."
    for i in "${!remove_mas_names[@]}"; do
        echo "  mas uninstall ${remove_mas_ids[$i]}  # ${remove_mas_names[$i]}"
        if ! mas uninstall "${remove_mas_ids[$i]}" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

if [[ ${#remove_fisher[@]} -gt 0 ]]; then
    echo "Removing Fisher plugins..."
    for plugin in "${remove_fisher[@]}"; do
        echo "  fisher remove $plugin"
        if ! fish -c "fisher remove '$plugin'" 2>&1 | sed 's/^/    /'; then
            errors=$((errors + 1))
        fi
    done
fi

# Cleanup orphaned deps
if [[ ${#remove_brews[@]} -gt 0 || ${#remove_casks[@]} -gt 0 ]]; then
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
    echo "Done."
fi
