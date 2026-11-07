#!/bin/bash
# Ctrl+a: toggle the agent coordinator's tab.
#
# The coordinator is a long-lived Claude Code session (Opus 5.5, low effort),
# running as the herdr agent "coordinator". It follows a rolling feed of every
# agent (scripts/agent_watch.py), points you at the ones that need you, and
# relays your messages to them. It lives in a "coordinator" tab of the workspace for
# its repo (HERDR_COORDINATOR_CWD, e.g. ds-hq), next to that repo's other
# agents, so the repo has one workspace. The tab is modal, like vim:
#
#   history (top)    Neovim in normal mode: read the conversation with vim motions
#   prompt (bottom)  Claude Code, insert mode: type to the coordinator
#
# i in the history pane jumps to the prompt, Ctrl+k goes back up. Ctrl+a from
# anywhere switches to the coordinator's tab; from it, back to the tab you came
# from. The first press creates the tab (and the workspace if needed), starts
# Claude with herdr/coordinator.md appended to its system prompt and
# herdr/coordinator-settings.json pre-approving its read and relay commands,
# and asks it to start the feed. The workspace is kept first in the sidebar and
# the tab first in the workspace, so the coordinator is the top agent.
#
# The history pane has a darker background and an orange "◉ COORDINATOR"
# banner, and Claude's status line repeats it (scripts/coordinator_status.py).
#
# Settings, read from ~/.config/donburi/local.env (one per Mac, not in the
# repo; plain `NAME=value` lines in sh syntax), else from the environment:
#   HERDR_COORDINATOR_NAME       agent and tab name         (default: coordinator)
#   HERDR_COORDINATOR_CWD        coordinator working dir    (default: $HOME)
#   HERDR_COORDINATOR_WORKSPACE  workspace label            (default: basename of the dir)
#   HERDR_COORDINATOR_MODEL      coordinator's Claude model (default: claude-opus-5-5)
#   HERDR_COORDINATOR_EFFORT     its effort level: low, medium, high, xhigh, max (default: low)

set -uo pipefail

# Per-machine settings win over the environment.
local_env="${XDG_CONFIG_HOME:-$HOME/.config}/donburi/local.env"
if [[ -f "$local_env" ]]; then
	set -a
	# shellcheck source=/dev/null
	. "$local_env"
	set +a
fi

herdr="${HERDR_BIN_PATH:-herdr}"
name="${HERDR_COORDINATOR_NAME:-coordinator}"
cwd="${HERDR_COORDINATOR_CWD:-$HOME}"
workspace_label="${HERDR_COORDINATOR_WORKSPACE:-$(basename "$cwd")}"
model="${HERDR_COORDINATOR_MODEL:-claude-opus-5-5}"
effort="${HERDR_COORDINATOR_EFFORT:-low}"
config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
brief="$config_dir/coordinator.md"
settings="$config_dir/coordinator-settings.json"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/coordinator"

# Key commands run in the background, so failures are shown as a herdr toast.
notify() { "$herdr" notification show "coordinator" --body "$*" --sound request >/dev/null 2>&1; }
fail() {
	notify "$*"
	echo "coordinator: $*" >&2
	exit 1
}

# herdr's CLI has no move commands, so these call the socket API directly.
api() {
	python3 -c 'import json, sys; sys.path.insert(0, sys.argv[1]); import agent_watch
agent_watch.call(sys.argv[2], json.loads(sys.argv[3]))' "$config_dir/scripts" "$1" "$2" >/dev/null 2>&1
}

command -v jq >/dev/null || fail "jq is required (brew install jq)"
mkdir -p "$state_dir"

workspaces=$("$herdr" workspace list) || fail "herdr is not reachable"
focused_ws=$(jq -r '[.result.workspaces[] | select(.focused)][0].workspace_id // empty' <<<"$workspaces")
focused_tab=$("$herdr" tab list --workspace "$focused_ws" 2>/dev/null |
	jq -r '[.result.tabs[] | select(.focused)][0].tab_id // empty')
ws=$(jq -r --arg l "$workspace_label" '[.result.workspaces[] | select(.label == $l)][0].workspace_id // empty' <<<"$workspaces")
tab=""
[[ -n "$ws" ]] && tab=$("$herdr" tab list --workspace "$ws" |
	jq -r --arg l "$name" '[.result.tabs[] | select(.label == $l)][0].tab_id // empty')

# From the coordinator: back to the tab you came from (or any other workspace).
if [[ -n "$tab" && "$focused_tab" == "$tab" ]]; then
	back=$(cat "$state_dir/previous-tab" 2>/dev/null)
	if [[ -n "$back" ]] && "$herdr" tab focus "$back" >/dev/null 2>&1; then
		exit 0
	fi
	other=$(jq -r --arg w "$ws" '[.result.workspaces[] | select(.workspace_id != $w)][0].workspace_id // empty' <<<"$workspaces")
	[[ -n "$other" ]] && "$herdr" workspace focus "$other" >/dev/null
	exit 0
fi
[[ -n "$focused_tab" ]] && echo "$focused_tab" >"$state_dir/previous-tab"

# First press: the coordinator tab, with the history pane on top (70%) and the
# prompt pane below; the repo's workspace too if it does not exist yet.
if [[ -z "$tab" ]]; then
	if [[ -z "$ws" ]]; then
		created=$("$herdr" workspace create --cwd "$cwd" --label "$workspace_label" --no-focus) ||
			fail "could not create the '$workspace_label' workspace"
		ws=$(jq -r '.result.workspace.workspace_id' <<<"$created")
		history=$(jq -r '.result.root_pane.pane_id' <<<"$created")
		tab=$(jq -r '.result.root_pane.tab_id' <<<"$created")
		"$herdr" tab rename "$tab" "$name" >/dev/null
	else
		created=$("$herdr" tab create --workspace "$ws" --cwd "$cwd" --label "$name" --no-focus) ||
			fail "could not create the '$name' tab in '$workspace_label'"
		tab=$(jq -r '.result.tab.tab_id' <<<"$created")
		history=$(jq -r '.result.root_pane.pane_id' <<<"$created")
	fi
	"$herdr" pane rename "$history" history >/dev/null
	prompt=$("$herdr" pane split "$history" --direction down --ratio 0.7 --cwd "$cwd" --no-focus |
		jq -r '.result.pane.pane_id // empty')
	[[ -n "$prompt" ]] || fail "could not split the '$name' tab"
	"$herdr" pane rename "$prompt" prompt >/dev/null
fi

# Keep the workspace first in the sidebar and the tab first in the workspace.
first_ws=$(jq -r '.result.workspaces[0].workspace_id // empty' <<<"$workspaces")
[[ -n "$first_ws" && "$first_ws" != "$ws" ]] &&
	api workspace.move "{\"workspace_id\": \"$ws\", \"insert_index\": 0}"
first_tab=$("$herdr" tab list --workspace "$ws" | jq -r '.result.tabs[0].tab_id // empty')
[[ -n "$first_tab" && "$first_tab" != "$tab" ]] &&
	api tab.move "{\"tab_id\": \"$tab\", \"insert_index\": 0}"

"$herdr" tab focus "$tab" >/dev/null

panes=$("$herdr" pane list --workspace "$ws")
labelled() {
	jq -r --arg t "$tab" --arg l "$1" \
		'[.result.panes[] | select(.tab_id == $t and .label == $l)][0].pane_id // empty' <<<"$panes"
}
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

[[ -n "$prompt" ]] || fail "the '$name' tab has no prompt pane; close the tab and press Ctrl+a again"

# herdr restores agents after a restart with a bare `claude --resume`, which
# drops the name, model, effort, brief and settings. Give the name back so
# Ctrl+a and the feed recognise it, and ask for a restart to restore the rest.
restored=$("$herdr" agent list | jq -r --arg p "$prompt" '[.result.agents[] | select(.pane_id == $p)][0].pane_id // empty')
if [[ -n "$restored" ]]; then
	"$herdr" agent rename "$restored" "$name" >/dev/null 2>&1
	notify "herdr restored the coordinator without its model, effort, brief and settings: type /exit in its prompt, then press Ctrl+a twice"
	exit 0
fi

# Start Claude in the prompt pane, unless a previous press is still starting it.
starting="$state_dir/starting"
if [[ -f "$starting" ]] && (($(date +%s) - $(stat -f %m "$starting") < 120)); then
	exit 0
fi
touch "$starting"
trap 'rm -f "$starting"' EXIT
[[ -n "$history" ]] && "$herdr" pane focus --direction down --pane "$history" >/dev/null 2>&1

args=(--name "$name" --model "$model" --effort "$effort")
[[ -f "$brief" ]] && args+=(--append-system-prompt-file "$brief")
[[ -f "$settings" ]] && args+=(--settings "$settings")

if ! out=$("$herdr" agent start "$name" --kind claude --pane "$prompt" --timeout 60000 -- "${args[@]}" 2>&1); then
	# agent_not_ready = Claude waits on a first-run prompt (e.g. folder trust) that
	# you answer in the focused prompt pane. Anything else is a real failure.
	[[ "$out" == *agent_not_ready* ]] || fail "failed to start Claude: $out"
	"$herdr" agent wait "$name" --until idle --timeout 600000 >/dev/null 2>&1 || exit 0
fi
"$herdr" agent prompt "$name" "Start your session: follow the start-of-session steps in your brief." >/dev/null
