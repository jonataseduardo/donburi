#!/bin/bash

# Battery plugin
# Shows battery level with Nerd Font battery icons

source "$CONFIG_DIR/colors.sh"

BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -o '[0-9]*%' | head -1 | tr -d '%')
CHARGING=$(echo "$BATTERY_INFO" | grep -c "AC Power")

if [ -z "$PERCENTAGE" ]; then
    # No battery (desktop Mac)
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Set icon based on charging status and level
if [ "$CHARGING" -gt 0 ]; then
    if [ "$PERCENTAGE" -ge 90 ]; then
        ICON="󰂅"
    elif [ "$PERCENTAGE" -ge 70 ]; then
        ICON="󰂋"
    elif [ "$PERCENTAGE" -ge 50 ]; then
        ICON="󰂉"
    elif [ "$PERCENTAGE" -ge 30 ]; then
        ICON="󰂇"
    else
        ICON="󰢜"
    fi
    COLOR="$KANAGAWA_YELLOW"
elif [ "$PERCENTAGE" -le 10 ]; then
    ICON="󰁺"
    COLOR="$KANAGAWA_RED"
elif [ "$PERCENTAGE" -le 20 ]; then
    ICON="󰁻"
    COLOR="$KANAGAWA_RED"
elif [ "$PERCENTAGE" -le 30 ]; then
    ICON="󰁼"
    COLOR="$KANAGAWA_ORANGE"
elif [ "$PERCENTAGE" -le 40 ]; then
    ICON="󰁽"
    COLOR="$KANAGAWA_ORANGE"
elif [ "$PERCENTAGE" -le 50 ]; then
    ICON="󰁾"
    COLOR="$KANAGAWA_YELLOW"
elif [ "$PERCENTAGE" -le 60 ]; then
    ICON="󰁿"
    COLOR="$KANAGAWA_YELLOW"
elif [ "$PERCENTAGE" -le 70 ]; then
    ICON="󰂀"
    COLOR="$KANAGAWA_GREEN"
elif [ "$PERCENTAGE" -le 80 ]; then
    ICON="󰂁"
    COLOR="$KANAGAWA_GREEN"
elif [ "$PERCENTAGE" -le 90 ]; then
    ICON="󰂂"
    COLOR="$KANAGAWA_GREEN"
else
    ICON="󰁹"
    COLOR="$KANAGAWA_GREEN"
fi

sketchybar --set "$NAME" \
    icon="$ICON" \
    icon.color="$COLOR" \
    label=" ${PERCENTAGE}%"
