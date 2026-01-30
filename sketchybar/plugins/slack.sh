#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Test mode: Set SLACK_TEST_MODE=1 to simulate unread messages
# Example: SLACK_TEST_MODE=1 ./plugins/slack.sh
if [ "$SLACK_TEST_MODE" = "1" ]; then
    sketchybar --set "$NAME" \
        drawing=on \
        icon="󰒱" \
        icon.color="$KANAGAWA_RED" \
        label="WO:3 PE:1"
    exit 0
fi

# Check if Slack is running
if ! pgrep -x "Slack" > /dev/null; then
    sketchybar --set "$NAME" drawing=off
    exit 0
fi

# Function to get workspace unread counts
get_slack_unreads() {
    # Use lsappinfo to get Slack's status label (unread count)
    STATUS_LABEL=$(lsappinfo info -only StatusLabel "Slack" 2>/dev/null | grep -o '"label"="[^"]*"' | cut -d'"' -f4)

    # Return the unread count if found
    if [ -n "$STATUS_LABEL" ] && [ "$STATUS_LABEL" != "" ]; then
        echo "$STATUS_LABEL"
    else
        echo "0"
    fi
}

# Get workspace information
get_workspace_info() {
    # Get the unread count
    TOTAL_UNREADS=$(get_slack_unreads)

    if [ -n "$TOTAL_UNREADS" ] && [ "$TOTAL_UNREADS" != "0" ]; then
        # Get workspace name from window title (just for the name)
        WINDOW_TITLE=$(osascript -e '
            tell application "System Events"
                tell process "Slack"
                    try
                        get title of window 1
                    on error
                        return ""
                    end try
                end tell
            end tell
        ' 2>/dev/null)

        # Extract workspace name - looking for pattern like "- Intelligent Audit -"
        # The workspace name usually appears after DM/Channel name and before "new items" or at the end
        WORKSPACE_NAME=""

        # Try to extract from patterns like "DM) - Workspace - X new items"
        if echo "$WINDOW_TITLE" | grep -q "new item"; then
            WORKSPACE_NAME=$(echo "$WINDOW_TITLE" | sed -n 's/.*) - \(.*\) - [0-9]* new item.*/\1/p')
        fi

        # If not found, try simpler extraction (between dashes)
        if [ -z "$WORKSPACE_NAME" ]; then
            # Get the second-to-last segment between dashes (before "Slack")
            WORKSPACE_NAME=$(echo "$WINDOW_TITLE" | awk -F' - ' '{if(NF>1) print $(NF-1)}' | sed 's/[0-9]* new item.*//')
        fi

        # Clean up and use fallback if needed
        WORKSPACE_NAME=$(echo "$WORKSPACE_NAME" | xargs)
        if [ -z "$WORKSPACE_NAME" ]; then
            WORKSPACE_NAME="Slack"
        fi

        echo "${WORKSPACE_NAME}:${TOTAL_UNREADS}"
    else
        # No unread messages
        echo ""
    fi
}

# Main logic
WORKSPACE_INFO=$(get_workspace_info)

if [ -n "$WORKSPACE_INFO" ]; then
    # Parse workspace info and create display string
    DISPLAY_TEXT=""

    if [ "$WORKSPACE_INFO" = "Active" ]; then
        # Just show that Slack is active
        DISPLAY_TEXT=""
        ICON_COLOR=$KANAGAWA_FG_DIM
    else
        # Parse workspace:count format
        while IFS=':' read -r workspace count; do
            if [ -n "$workspace" ] && [ -n "$count" ]; then
                # Get first two letters of workspace name (uppercase)
                CODE=$(echo "$workspace" | cut -c1-2 | tr '[:lower:]' '[:upper:]')

                if [ -n "$DISPLAY_TEXT" ]; then
                    DISPLAY_TEXT="$DISPLAY_TEXT $CODE:$count"
                else
                    DISPLAY_TEXT="$CODE:$count"
                fi
            fi
        done <<< "$WORKSPACE_INFO"

        # Set icon color based on unread status
        if [ -n "$DISPLAY_TEXT" ]; then
            ICON_COLOR=$KANAGAWA_RED  # Red when there are unreads
        else
            ICON_COLOR=$KANAGAWA_FG_DIM   # Grey when no unreads
        fi
    fi

    # Update the widget
    sketchybar --set "$NAME" \
        drawing=on \
        icon="󰒱" \
        icon.color="$ICON_COLOR" \
        label="$DISPLAY_TEXT"
else
    # Slack is running but no activity
    sketchybar --set "$NAME" \
        drawing=on \
        icon="󰒱" \
        icon.color=$KANAGAWA_FG_DIM \
        label=""
fi

# Note: For production use, consider these enhancements:
# 1. Slack Web API integration with proper authentication
# 2. Parse Slack's IndexedDB for local unread counts
# 3. Integration with third-party tools like Badgeify
# 4. Monitor Slack's WebSocket connections for real-time updates