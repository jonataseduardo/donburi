#!/bin/bash
# Ctrl+a: toggle the agent coordinator's workspace.
#
# The coordinator is a long-lived Claude Code session on a fast model, running
# as the herdr agent "coordinator" in its own workspace. It follows a rolling
# feed of every agent (scripts/agent_watch.py), points you at the ones that
# need you, and relays your messages to them. The workspace is modal, like vim:
#
#   history (top)    Neovim in normal mode: read the conversation with vim motions
#   prompt (bottom)  Claude Code, insert mode: type to the coordinator
#
# i in the history pane jumps to the prompt, Ctrl+k goes back up. Ctrl+a from
# any workspace switches to the coordinator; from the coordinator, back to where
# you were. The first press creates the workspace, starts Claude with
# herdr/coordinator.md appended to its system prompt and
# herdr/coordinator-settings.json pre-approving its read and relay commands,
# and asks it to start the feed.
#
# So you always know you are in it, the workspace is labelled "◉ <name>" and
# kept first in the sidebar, in the accent color; the history pane has a darker
# background and an orange "◉ COORDINATOR" banner, and Claude's status line
# repeats it (scripts/coordinator_status.py).
#
# Overrides (prefix the command in herdr/config.toml):
#   HERDR_COORDINATOR_NAME   agent name; workspace "◉ <name>" (default: coordinator)
#   HERDR_COORDINATOR_CWD    coordinator working dir    (default: $HOME)
#   HERDR_COORDINATOR_MODEL  coordinator's Claude model (default: haiku)

set -uo pipefail

herdr="${HERDR_BIN_PATH:-herdr}"
name="${HERDR_COORDINATOR_NAME:-coordinator}"
cwd="${HERDR_COORDINATOR_CWD:-$HOME}"
model="${HERDR_COORDINATOR_MODEL:-haiku}"
config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brief="$config_dir/coordinator.md"
settings="$config_dir/coordinator-settings.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/coordinator"

# Key commands run in the background, so failures are shown as a herdr toast.
fail() {
	"$herdr" notification show "coordinator" --body "$*" --sound request >/dev/null 2>&1
	echo "coordinator: $*" >&2
	exit 1
}

command -v jq >/dev/null || fail "jq is required (brew install jq)"
mkdir -p "$state_dir"

workspaces=$("$herdr" workspace list) || fail "herdr is not reachable"
focused=$(jq -r '[.result.workspaces[] | select(.focused)][0].workspace_id // empty' <<<"$workspaces")
# The workspace is labelled "◉ <name>" (the coordinator's marker, drawn in the
# accent color by the [ui.sidebar.spaces] rule in config.toml). Find it through
# the running agent first, then by label, also accepting the older plain label.
label="◉ $name"
ws=$("$herdr" agent get "$name" 2>/dev/null | jq -r '.result.agent.workspace_id // empty')
[[ -n "$ws" ]] || ws=$(jq -r --arg l "$label" --arg n "$name" \
	'[.result.workspaces[] | select(.label == $l or .label == $n)][0].workspace_id // empty' <<<"$workspaces")

# From the coordinator: back to the workspace you came from (or any other one).
if [[ -n "$ws" && "$focused" == "$ws" ]]; then
	back=$(cat "$state_dir/previous-workspace" 2>/dev/null)
	jq -e --arg w "$back" 'any(.result.workspaces[]; .workspace_id == $w)' <<<"$workspaces" >/dev/null ||
		back=$(jq -r --arg w "$ws" '[.result.workspaces[] | select(.workspace_id != $w)][0].workspace_id // empty' <<<"$workspaces")
	[[ -n "$back" ]] && "$herdr" workspace focus "$back" >/dev/null
	exit 0
fi
[[ -n "$focused" ]] && echo "$focused" >"$state_dir/previous-workspace"

# First press: history pane on top (70%), prompt pane below.
if [[ -z "$ws" ]]; then
	created=$("$herdr" workspace create --cwd "$cwd" --label "$label" --no-focus) ||
		fail "could not create the '$name' workspace"
	ws=$(jq -r '.result.workspace.workspace_id' <<<"$created")
	history=$(jq -r '.result.root_pane.pane_id' <<<"$created")
	"$herdr" pane rename "$history" history >/dev/null
	prompt=$("$herdr" pane split "$history" --direction down --ratio 0.7 --cwd "$cwd" --no-focus |
		jq -r '.result.pane.pane_id // empty')
	[[ -n "$prompt" ]] || fail "could not split the '$name' workspace"
	"$herdr" pane rename "$prompt" prompt >/dev/null
fi

# Keep the label and keep the workspace first in the sidebar. herdr's CLI has
# no move command, so this calls the socket API's workspace.move directly.
current=$(jq -r --arg w "$ws" '[.result.workspaces[] | select(.workspace_id == $w)][0].label // empty' <<<"$workspaces")
[[ -n "$current" && "$current" != "$label" ]] && "$herdr" workspace rename "$ws" "$label" >/dev/null
first=$(jq -r '.result.workspaces[0].workspace_id // empty' <<<"$workspaces")
if [[ -n "$first" && "$first" != "$ws" ]]; then
	python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import agent_watch
agent_watch.call("workspace.move", {"workspace_id": sys.argv[2], "insert_index": 0})' \
		"$config_dir/scripts" "$ws" >/dev/null 2>&1
fi

"$herdr" workspace focus "$ws" >/dev/null

panes=$("$herdr" pane list --workspace "$ws")
labelled() { jq -r --arg l "$1" '[.result.panes[] | select(.label == $l)][0].pane_id // empty' <<<"$panes"; }
history=$(labelled history)
prompt=$(labelled prompt)

# Restart the history view if its pane is back at a shell prompt (e.g. after :q).
if [[ -n "$history" ]]; then
	shell=$("$herdr" pane process-info --pane "$history" |
		jq -r '.result.process_info.foreground_processes[0].name // empty')
	[[ "$shell" =~ ^(zsh|fish|sh)$ ]] &&
		"$herdr" pane run "$history" "HERDR_COORDINATOR_NAME=$name $config_dir/scripts/transcript-view.sh $name" >/dev/null
fi

"$herdr" agent get "$name" >/dev/null 2>&1 && exit 0

# Start Claude in the prompt pane, unless a previous press is still starting it.
starting="$state_dir/starting"
if [[ -f "$starting" ]] && (($(date +%s) - $(stat -f %m "$starting") < 120)); then
	exit 0
fi
[[ -n "$prompt" ]] || fail "the '$name' workspace has no prompt pane; close it and press Ctrl+a again"
touch "$starting"
trap 'rm -f "$starting"' EXIT
[[ -n "$history" ]] && "$herdr" pane focus --direction down --pane "$history" >/dev/null 2>&1

args=(--name "$name" --model "$model")
[[ -f "$brief" ]] && args+=(--append-system-prompt-file "$brief")
[[ -f "$settings" ]] && args+=(--settings "$settings")

if ! out=$("$herdr" agent start "$name" --kind claude --pane "$prompt" --timeout 60000 -- "${args[@]}" 2>&1); then
	# agent_not_ready = Claude waits on a first-run prompt (e.g. folder trust) that
	# you answer in the focused prompt pane. Anything else is a real failure.
	[[ "$out" == *agent_not_ready* ]] || fail "failed to start Claude: $out"
	"$herdr" agent wait "$name" --until idle --timeout 600000 >/dev/null 2>&1 || exit 0
fi
"$herdr" agent prompt "$name" "Start your session: follow the start-of-session steps in your brief." >/dev/null
