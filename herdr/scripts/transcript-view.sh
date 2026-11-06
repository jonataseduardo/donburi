#!/bin/bash
# Live Neovim view of a herdr agent's Claude conversation: normal mode to read
# and navigate with vim motions, i to jump to the agent's prompt (insert mode).
# The coordinator's history pane runs it; prefix+shift+h opens it for the
# focused agent in a popup. The coordinator's history is also kept as one file
# per day (transcript.py --days), browsed with [d / ]d and :HerdrDay.
#
# Usage: transcript-view.sh [agent name or pane ID]   (default: coordinator)

set -uo pipefail

agent="${1:-${HERDR_ACTIVE_PANE_ID:-coordinator}}"
scripts="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
state="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/coordinator"
out="$state/${agent//[^A-Za-z0-9_-]/_}.md"
mkdir -p "$state"

days=()
if [[ "$agent" == "${HERDR_COORDINATOR_NAME:-coordinator}" ]]; then
	days=(--days "$state/days")
	export HERDR_TRANSCRIPT_DAYS="$state/days"
fi

# ${days[@]+...}: bash 3.2 (macOS) treats an empty array as unset under set -u.
python3 "$scripts/transcript.py" --agent "$agent" --follow --out "$out" ${days[@]+"${days[@]}"} &
renderer=$!
trap 'kill "$renderer" 2>/dev/null' EXIT

for _ in $(seq 1 30); do
	[[ -s "$out" ]] && break
	sleep 0.1
done
[[ -s "$out" ]] || echo "_Waiting for $agent's conversation..._" >"$out"

HERDR_TRANSCRIPT_AGENT="$agent" nvim -n -R -c "luafile $scripts/../transcript.lua" "$out"
