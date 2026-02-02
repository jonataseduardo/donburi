#!/bin/bash
source "$CONFIG_DIR/colors.sh"

# Check if Spotify is running
if ! pgrep -x "Spotify" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

PLAYER_STATE=$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null)

if [ "$PLAYER_STATE" = "playing" ]; then
    TRACK=$(osascript -e 'tell application "Spotify" to name of current track as string' 2>/dev/null)
    ARTIST=$(osascript -e 'tell application "Spotify" to artist of current track as string' 2>/dev/null)

    # Truncate if too long
    DISPLAY="$ARTIST - $TRACK"
    if [ ${#DISPLAY} -gt 50 ]; then
        DISPLAY="${DISPLAY:0:47}..."
    fi

    sketchybar --set "$NAME" \
        drawing=on \
        icon="󰓇" \
        icon.color="0xaa76946A" \
        label="$DISPLAY"
elif [ "$PLAYER_STATE" = "paused" ]; then
    sketchybar --set "$NAME" \
        drawing=on \
        icon="󰓇" \
        icon.color="0x99727169" \
        label="Paused"
else
    sketchybar --set "$NAME" drawing=off
fi
