#!/bin/bash
# Herdr Ctrl+hjkl navigation — same behavior as the old tmux.conf binding:
#
#   is_vim = vim/nvim/view/fzf in the foreground  -> forward the key (smart-splits/fzf handle it)
#   otherwise                                      -> select-pane in that direction, where:
#     - a zoomed pane is unzoomed first (tmux select-pane unzooms)
#     - at the edge focus wraps to the far side (tmux select-pane wraps)
#     - a lone pane swallows the key (tmux: nothing happens)
#
# Usage: navigate.sh <left|down|up|right>   (bound in herdr/config.toml)

dir="$1"
herdr="${HERDR_BIN_PATH:-herdr}"
pane="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"

case "$dir" in
left) key="ctrl+h" opposite="right" ;;
down) key="ctrl+j" opposite="up" ;;
up) key="ctrl+k" opposite="down" ;;
right) key="ctrl+l" opposite="left" ;;
*)
	echo "usage: navigate.sh <left|down|up|right>" >&2
	exit 2
	;;
esac

# Same matcher as tmux.conf's is_vim: (g)view, vi, vim, nvim, vimx, ...diff, fzf
is_vim_re='^g?(view|l?n?vim?x?|fzf)(diff)?$'

if [ -n "$pane" ] && "$herdr" pane process-info --pane "$pane" 2>/dev/null |
	jq -e --arg re "$is_vim_re" \
		'.result.process_info.foreground_processes[]?.name | ascii_downcase | select(test($re))' >/dev/null 2>&1; then
	exec "$herdr" pane send-keys "$pane" "$key"
fi

pane_args=(--current)
[ -n "$pane" ] && pane_args=(--pane "$pane")

# tmux select-pane unzooms the window before moving
if [ "$("$herdr" pane layout "${pane_args[@]}" 2>/dev/null | jq -r '.result.layout.zoomed // false')" = "true" ]; then
	"$herdr" pane zoom "${pane_args[@]}" --off >/dev/null 2>&1
fi

# Move focus one step; sets $moved and follows the newly focused pane
focus() {
	local out
	out=$("$herdr" pane focus --direction "$1" "${pane_args[@]}" 2>/dev/null |
		jq -r '"\(.result.focus.changed // false) \(.result.focus.focused_pane_id // "")"')
	moved="${out%% *}"
	[ -n "${out#* }" ] && pane_args=(--pane "${out#* }")
}

focus "$dir"
[ "$moved" = "true" ] && exit 0

# At the edge: wrap around to the farthest pane on the opposite side (tmux default).
# A lone pane has no neighbor either way, so the key is swallowed like in tmux.
for _ in $(seq 1 20); do
	focus "$opposite"
	[ "$moved" = "true" ] || break
done
exit 0
