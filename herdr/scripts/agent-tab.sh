#!/usr/bin/env bash
# prefix+a (popup): open an agent the standard way. Asks for a short task name,
# then creates a tab with that label in the current workspace, keeps a shell on
# the left and starts Claude in a right split. The agent is named after the
# task. The coordinator follows the same layout (herdr/coordinator.md).
set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
workspace="${HERDR_ACTIVE_WORKSPACE_ID:-}"
cwd="${HERDR_ACTIVE_PANE_CWD:-$PWD}"
[[ -n "$workspace" ]] || { echo "No active workspace."; read -r -n 1; exit 1; }

json() { python3 -c "import json,sys;d=json.load(sys.stdin)['result'];print($1)"; }

while :; do
	read -r -p "Task name for the agent tab: " label || exit 0
	label="${label#"${label%%[![:space:]]*}"}"
	label="${label%"${label##*[![:space:]]}"}"
	[[ -z "$label" ]] && exit 0 # Enter on an empty line cancels
	[[ "$label" =~ ^[0-9]+$ ]] && { echo "Use a short task name, not a number."; continue; }
	break
done

# Agent name: the label as [a-z][a-z0-9_-]{0,31}, made unique.
base=$(printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9_-' '-' | sed 's/^[^a-z]*//; s/-*$//')
base="${base:0:28}"
[[ -n "$base" ]] || base=agent
taken=$("$herdr" agent list 2>/dev/null | python3 -c "import json,sys;print('\n'.join(a.get('name','') for a in json.load(sys.stdin)['result'].get('agents',[])))" 2>/dev/null)
name=$base n=2
while grep -qx -- "$name" <<<"$taken"; do name="$base-$n"; n=$((n + 1)); done

left=$("$herdr" tab create --workspace "$workspace" --cwd "$cwd" --label "$label" --focus | json "d['root_pane']['pane_id']") \
	|| { echo "Could not create the tab."; read -r -n 1; exit 1; }
right=$("$herdr" pane split "$left" --direction right --cwd "$cwd" | json "d['pane']['pane_id']") \
	|| { echo "Could not split the tab."; read -r -n 1; exit 1; }
"$herdr" agent start "$name" --kind claude --pane "$right" >/dev/null \
	|| { echo "Could not start Claude in $right."; read -r -n 1; exit 1; }
