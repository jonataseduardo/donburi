#!/bin/bash
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/app_icons.sh"

# Aerospace workspace indicator plugin
# Shows workspace number + Nerd Font icons for each open app
# Hides empty workspaces unless they are currently focused

CURRENT_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null || echo "1")
SPACE_NUM="${NAME##*.}"

# Get list of app names in this workspace (column 2, trimmed)
APPS=$(aerospace list-windows --workspace "$SPACE_NUM" 2>/dev/null \
    | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}')

# Build the label string: one icon per app
ICONS=""
while IFS= read -r app; do
    [ -z "$app" ] && continue
    icon=$(get_app_icon "$app")
    ICONS="${ICONS}${icon} "
done <<< "$APPS"

# Strip trailing space
ICONS="${ICONS% }"

HAS_APPS=false
[ -n "$ICONS" ] && HAS_APPS=true

if [ "$SPACE_NUM" = "$CURRENT_WORKSPACE" ]; then
    # Active workspace - always visible, vibrant orange highlight
    sketchybar --set "$NAME" \
        drawing=on \
        icon.color="$KANAGAWA_BG_DARK" \
        label="$ICONS" \
        label.color="$KANAGAWA_BG_DARK" \
        label.drawing=on \
        background.color="$KANAGAWA_ORANGE" \
        background.border_color="$KANAGAWA_ORANGE" \
        background.border_width=1
elif $HAS_APPS; then
    # Inactive workspace with apps - subtle dim border
    sketchybar --set "$NAME" \
        drawing=on \
        icon.color="$KANAGAWA_FG_DIM" \
        label="$ICONS" \
        label.color="$KANAGAWA_FG_DIM" \
        label.drawing=on \
        background.color="$KANAGAWA_BG" \
        background.border_color="$KANAGAWA_FG_DIM" \
        background.border_width=1
else
    # Empty inactive workspace - hide it
    sketchybar --set "$NAME" drawing=off
fi
