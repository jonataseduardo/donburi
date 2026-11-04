#!/bin/bash
# Ctrl+g: open the agent coordinator in a centered popup.
#
# The coordinator is a long-lived Claude Code session running as the herdr agent
# "coordinator" in its own background workspace, so it keeps working and shows
# in the agent sidebar while the popup is closed. The popup only attaches to it:
# detach with ctrl+b q. The first press creates the workspace and starts Claude
# with herdr/coordinator.md appended to its system prompt.
#
# Overrides (prefix the command in herdr/config.toml):
#   HERDR_COORDINATOR_NAME  agent and workspace name   (default: coordinator)
#   HERDR_COORDINATOR_CWD   coordinator working dir    (default: $HOME)

set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
name="${HERDR_COORDINATOR_NAME:-coordinator}"
cwd="${HERDR_COORDINATOR_CWD:-$HOME}"
brief="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/coordinator.md"

# A popup closes as soon as its command exits; keep errors on screen until a key press.
fail() {
	echo "coordinator: $*" >&2
	read -rsn1 -p "press any key to close"
	exit 1
}

command -v jq >/dev/null || fail "jq is required (brew install jq)"

if ! "$herdr" agent get "$name" >/dev/null 2>&1; then
	# Reuse the coordinator workspace if it is still open (e.g. Claude was exited), else create it
	ws=$("$herdr" workspace list | jq -r --arg n "$name" \
		'[.result.workspaces[] | select(.label == $n)][0].workspace_id // empty')
	if [[ -n "$ws" ]]; then
		pane=$("$herdr" pane list --workspace "$ws" | jq -r '.result.panes[0].pane_id // empty')
	else
		pane=$("$herdr" workspace create --cwd "$cwd" --label "$name" --no-focus |
			jq -r '.result.root_pane.pane_id // empty')
	fi
	[[ -n "$pane" ]] || fail "could not find or create a pane for the '$name' workspace"

	args=(--name "$name")
	[[ -f "$brief" ]] && args+=(--append-system-prompt-file "$brief")

	if ! out=$("$herdr" agent start "$name" --kind claude --pane "$pane" --timeout 60000 -- "${args[@]}" 2>&1); then
		# agent_not_ready = Claude is up but waiting on a first-run prompt (e.g. folder
		# trust); attach so it can be answered. Anything else is a real failure.
		[[ "$out" == *agent_not_ready* ]] || fail "failed to start Claude in $pane: $out"
	fi
fi

exec "$herdr" agent attach "$name"
