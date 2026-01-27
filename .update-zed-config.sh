#!/bin/bash

set -e

echo "Updating saved Zed configuration from active config..."

# Define paths
ACTIVE_ZED_CONFIG="$HOME/.config/zed"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEZMOI_ZED_CONFIG="$SCRIPT_DIR/dot_config/zed"

# Check if active Zed config exists
if [ ! -d "$ACTIVE_ZED_CONFIG" ]; then
    echo "Error: Active Zed config directory not found at $ACTIVE_ZED_CONFIG"
    exit 1
fi

# Check if chezmoi source path exists
if [ ! -d "$CHEZMOI_ZED_CONFIG" ]; then
    echo "Error: Chezmoi Zed config directory not found at $CHEZMOI_ZED_CONFIG"
    exit 1
fi

# Copy main configuration files
echo "Copying settings.json..."
if [ -f "$ACTIVE_ZED_CONFIG/settings.json" ]; then
    cp "$ACTIVE_ZED_CONFIG/settings.json" "$CHEZMOI_ZED_CONFIG/settings.json"
    echo "  ✓ settings.json updated"
else
    echo "  ⚠ settings.json not found in active config"
fi

echo "Copying keymap.json..."
if [ -f "$ACTIVE_ZED_CONFIG/keymap.json" ]; then
    cp "$ACTIVE_ZED_CONFIG/keymap.json" "$CHEZMOI_ZED_CONFIG/keymap.json"
    echo "  ✓ keymap.json updated"
else
    echo "  ⚠ keymap.json not found in active config"
fi

echo "Copying tasks.json..."
if [ -f "$ACTIVE_ZED_CONFIG/tasks.json" ]; then
    cp "$ACTIVE_ZED_CONFIG/tasks.json" "$CHEZMOI_ZED_CONFIG/tasks.json"
    echo "  ✓ tasks.json updated"
else
    echo "  ⚠ tasks.json not found in active config"
fi

# Copy custom themes if any exist
if [ -d "$ACTIVE_ZED_CONFIG/themes" ] && [ "$(ls -A $ACTIVE_ZED_CONFIG/themes)" ]; then
    echo "Copying custom themes..."
    cp -r "$ACTIVE_ZED_CONFIG/themes/"* "$CHEZMOI_ZED_CONFIG/themes/" 2>/dev/null || true
    echo "  ✓ Themes updated"
fi


echo ""
echo "✅ Zed configuration updated successfully!"
echo ""
echo "Next steps:"
echo "  1. Review the changes: cd $SCRIPT_DIR && git diff"
echo "  2. Commit the changes: cd $SCRIPT_DIR && git add dot_config/zed && git commit -m 'Update Zed configuration'"
echo "  3. Push to remote: cd $SCRIPT_DIR && git push"