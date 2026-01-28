#!/bin/bash
# Setup workspace 1 layout:
# ┌─────────┬────────────┬───────────┐
# │         │ Terminal 2  │           │
# │ Browser ├────────────┤ Terminal 1 │
# │  (1/3)  │ Terminal 3  │           │
# │         │            │           │
# └─────────┴────────────┴───────────┘

aerospace workspace 1
sleep 0.3

# Flatten to start clean — all windows become horizontal siblings
aerospace flatten-workspace-tree
sleep 0.2
aerospace layout tiles horizontal
sleep 0.2

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

# Step 1: Move browser to far left
aerospace focus --window-id "$BROWSER_ID"
sleep 0.1
aerospace move left
sleep 0.1
aerospace move left
sleep 0.1
aerospace move left
sleep 0.2

# Step 2: Move Term1 to far right
aerospace focus --window-id "$TERM1"
sleep 0.1
aerospace move right
sleep 0.1
aerospace move right
sleep 0.1
aerospace move right
sleep 0.2

# Now order should be: Browser, Term2, Term3, Term1
# Step 3: Focus Term2, then move it down — this creates a vertical split with Term3
aerospace focus --window-id "$TERM2"
sleep 0.1
aerospace move down
sleep 0.3

# Step 4: Resize browser to ~1/3 width
aerospace focus --window-id "$BROWSER_ID"
sleep 0.1
aerospace resize width -400
sleep 0.1
