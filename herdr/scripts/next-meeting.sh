#!/bin/bash

# Herdr tab bar: next-meeting widget.
#
# Reads today's events from Google Calendar via `uvx gcalcli` (OAuth, no macOS
# Calendar/TCC dependency). Run `uvx gcalcli init` once to authenticate.
#
# Herdr shows the last line of stdout and hides the entry on empty output, so
# this prints nothing unless meeting tracking is enabled via `donburi meeting on`.
# If uvx/gcalcli is unavailable or the call fails (e.g. not yet authenticated),
# the widget shows "cal?" instead of silently looking idle.

CALENDAR_ICON="󰃭"
NO_MEETINGS_LABEL="Peace"
ERROR_LABEL="cal?"
BEEP_STATE_FILE="${TMPDIR:-/tmp}/herdr_next_meeting_beep"
CACHE_FILE="${TMPDIR:-/tmp}/herdr_next_meeting_cache"

# Lazy loading: no calendar work unless meeting tracking is enabled.
TRACKING_FLAG="${XDG_CONFIG_HOME:-$HOME/.config}/donburi/meeting-tracking"
[ -f "$TRACKING_FLAG" ] || exit 0

show_error() {
	echo "$CALENDAR_ICON $ERROR_LABEL"
	exit 0
}

# Resolve uvx by absolute path — ~/.local/bin may be missing from PATH.
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

# Prefer a live event (latest-started among live), otherwise the earliest
# upcoming event today.
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

if [ "$MODE" = "none" ]; then
	echo "$CALENDAR_ICON $NO_MEETINGS_LABEL"
	exit 0
fi

# Count meetings sharing the selected start (the "xN" stacked-meeting badge).
SAME_START_COUNT=0
while IFS=$'\t' read -r S_DATE S_TIME _R; do
	[ -z "$S_TIME" ] && continue
	ST=$(date -j -f '%Y-%m-%d %H:%M' "$S_DATE $S_TIME" +%s 2>/dev/null) || continue
	[ "$ST" = "$SELECTED_START" ] && SAME_START_COUNT=$((SAME_START_COUNT + 1))
done <<EOF
$TSV
EOF

NEXT_TIME=$(date -r "$SELECTED_START" '+%H:%M')
if [ "$MODE" = "live" ]; then
	ELAPSED_MINUTES=$(((NOW_EPOCH - SELECTED_START) / 60))
	LABEL="$NEXT_TIME +${ELAPSED_MINUTES}m"
else
	SECONDS_LEFT=$((SELECTED_START - NOW_EPOCH))
	MINUTES_LEFT=$(((SECONDS_LEFT + 59) / 60))
	LABEL="$NEXT_TIME ${MINUTES_LEFT}m"

	# Beep once when the next meeting is about a minute away.
	if [ "$SECONDS_LEFT" -le 60 ] && [ "$SECONDS_LEFT" -gt 0 ]; then
		LAST_BEEPED_EPOCH=""
		[ -f "$BEEP_STATE_FILE" ] && LAST_BEEPED_EPOCH=$(cat "$BEEP_STATE_FILE")
		if [ "$LAST_BEEPED_EPOCH" != "$SELECTED_START" ]; then
			osascript -e 'beep 1' >/dev/null 2>&1 &
			printf '%s' "$SELECTED_START" >"$BEEP_STATE_FILE"
		fi
	fi
fi

[ "$SAME_START_COUNT" -gt 1 ] && LABEL="$LABEL x$SAME_START_COUNT"

echo "$CALENDAR_ICON $LABEL"
