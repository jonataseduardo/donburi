#!/bin/bash

# Aerospace workspace indicator plugin
# Highlights the active workspace

# Get current aerospace workspace
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null || echo "1")

# Extract space number from item name (e.g., "space.1" -> "1")
SPACE_NUM="${NAME##*.}"

if [ "$SPACE_NUM" = "$CURRENT_WORKSPACE" ]; then
    # Active workspace
    sketchybar --set "$NAME" \
        icon.color="$KANAGAWA_BG_DARK" \
        background.color="$KANAGAWA_GREEN"
else
    # Inactive workspace
    sketchybar --set "$NAME" \
        icon.color="$KANAGAWA_FG" \
        background.color="$KANAGAWA_BG"
fi
