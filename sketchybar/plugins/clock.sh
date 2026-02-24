#!/bin/bash

# Clock plugin
# Shows current date and time with a clock icon
# Icon: nf-fa-clock_o (U+F017) — set via printf hex for bash 3.2 compatibility

source "$CONFIG_DIR/colors.sh"

CLOCK_ICON=$(printf '\xEF\x80\x97')

sketchybar --set "$NAME" \
    icon="$CLOCK_ICON" \
    icon.color="$KANAGAWA_FG_DIM" \
    label="$(date '+%a %d %b %H:%M')"
