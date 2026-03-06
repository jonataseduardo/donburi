#!/bin/bash

source "$CONFIG_DIR/colors.sh"

CALENDAR_ICON="󰃭"
NO_MEETINGS_LABEL="Peace"
BEEP_STATE_FILE="${TMPDIR:-/tmp}/sketchybar_next_meeting_beep"

MEETING_STATE=$(
	osascript <<'APPLESCRIPT'
tell application "Calendar"
    set nowDate to current date
    set endOfDay to (current date)
    set hours of endOfDay to 23
    set minutes of endOfDay to 59
    set seconds of endOfDay to 59

    set selectedEvent to missing value
    set selectedMode to ""

    repeat with cal in every calendar
        set candidateEvents to (every event of cal whose allday event is false and start date <= endOfDay and end date > nowDate)
        repeat with ev in candidateEvents
            if (start date of ev) <= nowDate then
                if selectedMode is not "live" then
                    set selectedEvent to ev
                    set selectedMode to "live"
                else if (start date of ev) > (start date of selectedEvent) then
                    set selectedEvent to ev
                end if
            else if selectedMode is "" then
                set selectedEvent to ev
                set selectedMode to "upcoming"
            else if selectedMode is "upcoming" and (start date of ev) < (start date of selectedEvent) then
                set selectedEvent to ev
            end if
        end repeat
    end repeat

    if selectedEvent is missing value then
        return "none|0|0|0"
    end if

    set targetStart to (start date of selectedEvent)
    set sameStartCount to 0

    repeat with cal in every calendar
        set sameStartEvents to (every event of cal whose allday event is false and start date = targetStart)
        set sameStartCount to sameStartCount + (count of sameStartEvents)
    end repeat

    if selectedMode is "live" then
        set secondsSinceStart to (nowDate - targetStart) as integer
        return "live|0|" & (secondsSinceStart as text) & "|" & (sameStartCount as text)
    end if

    set secondsUntilStart to (targetStart - nowDate) as integer
    return "upcoming|" & (secondsUntilStart as text) & "|0|" & (sameStartCount as text)
end tell
APPLESCRIPT
)

IFS='|' read -r MODE SECONDS_UNTIL_START SECONDS_SINCE_START SAME_START_COUNT <<<"$MEETING_STATE"

if [ -z "$MODE" ] || [ "$MODE" = "none" ]; then
	sketchybar --set "$NAME" \
		icon="$CALENDAR_ICON" \
		icon.color="$KANAGAWA_FG_DIM" \
		label="$NO_MEETINGS_LABEL" \
		label.color="$KANAGAWA_FG_DIM" \
		background.border_color="$KANAGAWA_FG_DIM"
	exit 0
fi

NOW_EPOCH=$(date +%s)
if [ "$MODE" = "live" ]; then
	if [ -z "$SECONDS_SINCE_START" ] || [ "$SECONDS_SINCE_START" -lt 0 ]; then
		SECONDS_SINCE_START=0
	fi

	NEXT_START_EPOCH=$((NOW_EPOCH - SECONDS_SINCE_START))
	ELAPSED_MINUTES=$((SECONDS_SINCE_START / 60))
	NEXT_TIME=$(date -r "$NEXT_START_EPOCH" '+%H:%M')
	LABEL="$NEXT_TIME +${ELAPSED_MINUTES}m"

	if [ "$SAME_START_COUNT" -gt 1 ]; then
		LABEL="$LABEL x$SAME_START_COUNT"
	fi

	LABEL_COLOR="$KANAGAWA_ORANGE"
	BORDER_COLOR="$KANAGAWA_ORANGE"

	if [ "$SECONDS_SINCE_START" -lt 180 ]; then
		ICON_COLOR="$KANAGAWA_RED"
	else
		ICON_COLOR="$KANAGAWA_ORANGE"
	fi
else
	SECONDS_LEFT=$SECONDS_UNTIL_START
	if [ -z "$SECONDS_LEFT" ] || [ "$SECONDS_LEFT" -lt 0 ]; then
		SECONDS_LEFT=0
	fi

	NEXT_START_EPOCH=$((NOW_EPOCH + SECONDS_LEFT))
	MINUTES_LEFT=$(((SECONDS_LEFT + 59) / 60))
	NEXT_TIME=$(date -r "$NEXT_START_EPOCH" '+%H:%M')
	LABEL="$NEXT_TIME ${MINUTES_LEFT}m"

	if [ "$SECONDS_LEFT" -le 60 ] && [ "$SECONDS_LEFT" -gt 0 ]; then
		LAST_BEEPED_EPOCH=""
		if [ -f "$BEEP_STATE_FILE" ]; then
			LAST_BEEPED_EPOCH=$(cat "$BEEP_STATE_FILE")
		fi

		if [ "$LAST_BEEPED_EPOCH" != "$NEXT_START_EPOCH" ]; then
			osascript -e 'beep 1' >/dev/null 2>&1 &
			printf '%s' "$NEXT_START_EPOCH" >"$BEEP_STATE_FILE"
		fi
	fi

	if [ "$SAME_START_COUNT" -gt 1 ]; then
		LABEL="$LABEL x$SAME_START_COUNT"
	fi

	if [ "$MINUTES_LEFT" -le 1 ]; then
		ICON_COLOR="$KANAGAWA_ORANGE"
		LABEL_COLOR="$KANAGAWA_ORANGE"
		BORDER_COLOR="$KANAGAWA_ORANGE"
	elif [ "$MINUTES_LEFT" -le 5 ]; then
		ICON_COLOR="$KANAGAWA_YELLOW"
		LABEL_COLOR="$KANAGAWA_YELLOW"
		BORDER_COLOR="$KANAGAWA_YELLOW"
	else
		ICON_COLOR="$KANAGAWA_FG_DIM"
		LABEL_COLOR="$KANAGAWA_FG_DIM"
		BORDER_COLOR="$KANAGAWA_FG_DIM"
	fi
fi

sketchybar --set "$NAME" \
	icon="$CALENDAR_ICON" \
	icon.color="$ICON_COLOR" \
	label="$LABEL" \
	label.color="$LABEL_COLOR" \
	background.border_color="$BORDER_COLOR"
