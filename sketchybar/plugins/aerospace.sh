#!/bin/bash
source "$CONFIG_DIR/colors.sh"

# Aerospace workspace indicator plugin
# Highlights the active workspace and shows green border for workspaces with apps

# Get current aerospace workspace
CURRENT_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null || echo "1")

# Extract space number from item name (e.g., "space.1" -> "1")
SPACE_NUM="${NAME##*.}"

# Check if workspace has any windows
WINDOW_COUNT=$(aerospace list-windows --workspace "$SPACE_NUM" 2>/dev/null | wc -l)
HAS_APPS=$((WINDOW_COUNT > 0))

if [ "$SPACE_NUM" = "$CURRENT_WORKSPACE" ]; then
    # Active workspace - vibrant highlight
    sketchybar --set "$NAME" \
        icon.color="$KANAGAWA_BG_DARK" \
        background.color="$KANAGAWA_ORANGE" \
        background.border_color="$KANAGAWA_GREEN" \
        background.border_width=1
elif [ $HAS_APPS -eq 1 ]; then
    # Inactive workspace with apps - green border
    sketchybar --set "$NAME" \
        icon.color="$KANAGAWA_FG_DIM" \
        background.color="$KANAGAWA_BG" \
        background.border_color="$KANAGAWA_GREEN" \
        background.border_width=1
else
    # Inactive workspace without apps - no border
    sketchybar --set "$NAME" \
        icon.color="$KANAGAWA_FG_DIM" \
        background.color="$KANAGAWA_BG" \
        background.border_width=0
fi
