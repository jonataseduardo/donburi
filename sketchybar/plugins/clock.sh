#!/bin/bash

# Clock plugin
# Shows current date and time

sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')"
