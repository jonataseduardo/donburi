#!/bin/bash
# Setup workspace 1 layout
# Adaptive layout that works better on small monitors
#
# For larger monitors (width >= 2560px):
# ┌─────────┬─────────┬─────────┐
# │ Browser │ Term 1  │ Term 3  │
# │  (1/3)  ├─────────┤  (1/3)  │
# │         │ Term 2  │         │
# └─────────┴─────────┴─────────┘
#
# For smaller monitors:
# Simple 2x2 grid or horizontal layout

aerospace workspace 1
sleep 0.3

# Get monitor dimensions
MONITOR_INFO=$(aerospace list-monitors --focused --format '%{width}')
MONITOR_WIDTH=${MONITOR_INFO:-1920}  # Default to 1920 if can't detect

# Find window IDs by app
BROWSER_ID=$(aerospace list-windows --workspace 1 --format '%{window-id} %{app-bundle-id}' | grep -i 'com.google.Chrome' | head -1 | awk '{print $1}')
TERMINALS=$(aerospace list-windows --workspace 1 --format '%{window-id} %{app-bundle-id}' | grep -i 'com.mitchellh.ghostty' | awk '{print $1}')
TERM1=$(echo "$TERMINALS" | sed -n '1p')
TERM2=$(echo "$TERMINALS" | sed -n '2p')
TERM3=$(echo "$TERMINALS" | sed -n '3p')

if [ -z "$BROWSER_ID" ] || [ -z "$TERM1" ] || [ -z "$TERM2" ] || [ -z "$TERM3" ]; then
    osascript -e 'display notification "Need 1 Chrome + 3 Ghostty windows on workspace 1" with title "Aerospace Layout"'
    exit 1
fi

# Flatten to start clean
aerospace flatten-workspace-tree
sleep 0.2

# For small monitors, use a simpler layout
if [ "$MONITOR_WIDTH" -lt 2560 ]; then
    echo "Small monitor detected (${MONITOR_WIDTH}px), using simple 2x2 grid"

    # Create a 2x2 grid layout
    # Browser | Term1
    # Term2   | Term3

    # Position browser and Term1 on top
    aerospace focus --window-id "$BROWSER_ID"
    sleep 0.1
    aerospace layout tiles horizontal

    # Position Term1 next to browser
    aerospace focus --window-id "$TERM1"
    sleep 0.1

    # Create bottom row with Term2 and Term3
    aerospace focus --window-id "$TERM2"
    sleep 0.1
    aerospace join-with left  # Join with browser

    aerospace focus --window-id "$TERM3"
    sleep 0.1
    aerospace join-with left  # Join with Term1

    # Balance the grid
    aerospace balance-sizes

else
    echo "Large monitor detected (${MONITOR_WIDTH}px), using three-column layout"

    # Original three-column layout for larger monitors
    # This would contain the complex layout logic we tried before
    # For now, just balance the windows
    aerospace balance-sizes
fi

# Focus Term1
aerospace focus --window-id "$TERM1"