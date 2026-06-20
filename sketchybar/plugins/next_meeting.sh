#!/bin/bash

# Next-meeting widget.
#
# Reads today's events from Google Calendar via `uvx gcalcli` (OAuth, no macOS
# Calendar/TCC dependency — important because sketchybar runs under launchd and
# cannot read Calendar.app). Run `uvx gcalcli init` once to authenticate.
#
# If uvx/gcalcli is unavailable or the call fails (e.g. not yet authenticated),
# the widget shows a red "cal?" error state instead of silently looking idle.

source "$CONFIG_DIR/colors.sh"

CALENDAR_ICON="󰃭"
NO_MEETINGS_LABEL="Peace"
ERROR_LABEL="cal?"
BEEP_STATE_FILE="${TMPDIR:-/tmp}/sketchybar_next_meeting_beep"
CACHE_FILE="${TMPDIR:-/tmp}/sketchybar_next_meeting_cache"

# Lazy loading: the widget is hidden and does no calendar work unless meeting
# tracking is enabled via `donburi meeting on`. Toggle creates/removes this flag.
TRACKING_FLAG="${XDG_CONFIG_HOME:-$HOME/.config}/donburi/meeting-tracking"
if [ ! -f "$TRACKING_FLAG" ]; then
	sketchybar --set "$NAME" drawing=off
	exit 0
fi
sketchybar --set "$NAME" drawing=on

show_error() {
	sketchybar --set "$NAME" \
		icon="$CALENDAR_ICON" \
		icon.color="$KANAGAWA_RED" \
		label="$ERROR_LABEL" \
		label.color="$KANAGAWA_RED" \
		background.border_color="$KANAGAWA_RED"
	exit 0
}

# Resolve uvx by absolute path — launchd's PATH does not include ~/.local/bin.
UVX="$(command -v uvx || true)"
if [ -z "$UVX" ] && [ -x "$HOME/.local/bin/uvx" ]; then
	UVX="$HOME/.local/bin/uvx"
fi
[ -z "$UVX" ] && show_error

# Fetch today's events as TSV. Default gcalcli TSV columns are:
#   start_date \t start_time \t end_date \t end_time \t url \t title
# All-day events have an empty start_time and are skipped below.
TODAY=$(date '+%Y-%m-%d')
TSV=$("$UVX" gcalcli --nocolor agenda --tsv "$TODAY 00:00" "$TODAY 23:59" 2>/dev/null)
GCAL_RC=$?

if [ "$GCAL_RC" -ne 0 ]; then
	# Transient failure (network/token refresh): fall back to last good output
	# to avoid flicker; only error out if there is no usable cache.
	if [ -s "$CACHE_FILE" ]; then
		TSV=$(cat "$CACHE_FILE")
	else
		show_error
	fi
else
	printf '%s' "$TSV" >"$CACHE_FILE"
fi

# Parse the TSV and compute the selected meeting, matching the previous
# AppleScript precedence: prefer a live event (latest-started among live),
# otherwise the earliest upcoming event today.
NOW_EPOCH=$(date +%s)
MODE="none"
SELECTED_START=""

while IFS=$'\t' read -r S_DATE S_TIME E_DATE E_TIME _REST; do
	[ -z "$S_TIME" ] && continue # all-day event
	START=$(date -j -f '%Y-%m-%d %H:%M' "$S_DATE $S_TIME" +%s 2>/dev/null) || continue
	END=$(date -j -f '%Y-%m-%d %H:%M' "$E_DATE $E_TIME" +%s 2>/dev/null)
	[ -z "$END" ] && END=$START
	[ "$END" -lt "$START" ] && END=$((END + 86400)) # crosses midnight

	if [ "$START" -le "$NOW_EPOCH" ] && [ "$END" -gt "$NOW_EPOCH" ]; then
		if [ "$MODE" != "live" ] || [ "$START" -gt "$SELECTED_START" ]; then
			MODE="live"
			SELECTED_START="$START"
		fi
	elif [ "$START" -gt "$NOW_EPOCH" ]; then
		if [ "$MODE" = "none" ]; then
			MODE="upcoming"
			SELECTED_START="$START"
		elif [ "$MODE" = "upcoming" ] && [ "$START" -lt "$SELECTED_START" ]; then
			SELECTED_START="$START"
		fi
	fi
done <<EOF
$TSV
EOF

# Count meetings sharing the selected start (the "xN" stacked-meeting badge).
SAME_START_COUNT=0
if [ "$MODE" != "none" ]; then
	while IFS=$'\t' read -r S_DATE S_TIME _R; do
		[ -z "$S_TIME" ] && continue
		ST=$(date -j -f '%Y-%m-%d %H:%M' "$S_DATE $S_TIME" +%s 2>/dev/null) || continue
		[ "$ST" = "$SELECTED_START" ] && SAME_START_COUNT=$((SAME_START_COUNT + 1))
	done <<EOF
$TSV
EOF
fi

# Derive the legacy four-tuple consumed by the display logic below.
if [ "$MODE" = "live" ]; then
	SECONDS_UNTIL_START=0
	SECONDS_SINCE_START=$((NOW_EPOCH - SELECTED_START))
elif [ "$MODE" = "upcoming" ]; then
	SECONDS_UNTIL_START=$((SELECTED_START - NOW_EPOCH))
	SECONDS_SINCE_START=0
else
	SECONDS_UNTIL_START=0
	SECONDS_SINCE_START=0
fi

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
