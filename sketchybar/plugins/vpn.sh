#!/bin/bash
source "$CONFIG_DIR/colors.sh"

# VPN status indicator
# Shows when a VPN connection is active

VPN_ACTIVE=$(scutil --nc list 2>/dev/null | grep -c "Connected")
UTUN_ACTIVE=$(ifconfig 2>/dev/null | grep -c "utun[1-9]")

if [ "$VPN_ACTIVE" -gt 0 ] || [ "$UTUN_ACTIVE" -gt 0 ]; then
    sketchybar --set "$NAME" \
        icon="󰒄" \
        icon.color="$KANAGAWA_GREEN" \
        label="VPN" \
        drawing=on
else
    sketchybar --set "$NAME" \
        drawing=off
fi
