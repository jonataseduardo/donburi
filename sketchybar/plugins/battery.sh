#!/bin/bash

# Battery plugin
# Shows battery level and charging status

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
    ICON="CHG"
    COLOR="$KANAGAWA_YELLOW"
elif [ "$PERCENTAGE" -le 20 ]; then
    ICON="BAT"
    COLOR="$KANAGAWA_RED"
elif [ "$PERCENTAGE" -le 50 ]; then
    ICON="BAT"
    COLOR="$KANAGAWA_YELLOW"
else
    ICON="BAT"
    COLOR="$KANAGAWA_GREEN"
fi

sketchybar --set "$NAME" \
    icon="$ICON" \
    icon.color="$COLOR" \
    label="${PERCENTAGE}%"
