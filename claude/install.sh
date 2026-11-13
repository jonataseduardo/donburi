#!/usr/bin/env bash
# Install donburi's global Claude Code layer:
# - settings: merge claude/settings.json into ~/.claude/settings.json. Only the keys in claude/settings.json are set; every
# other key there (plugins, permissions, hooks...) is kept. The file is never
# overwritten wholesale, and a backup is kept next to it.
# - keybindings: link ~/.claude/keybindings.json to claude/keybindings.json when
#   there is none; otherwise merge donburi's bindings into it, keeping every
#   binding already there (the user's key wins).
#
# Usage: claude/install.sh [--dry-run]
#   CLAUDE_CONFIG_DIR  Claude Code's config dir (default: ~/.claude)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
layer="$here/settings.json"
dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
target="$dir/settings.json"

command -v jq >/dev/null || { echo "claude/install.sh: jq is required (brew install jq)" >&2; exit 1; }
jq empty "$layer"

current='{}'
if [[ -s "$target" ]]; then
	jq empty "$target" 2>/dev/null || { echo "claude/install.sh: $target is not valid JSON; not touching it" >&2; exit 1; }
	current=$(cat "$target")
fi

# Top-level keys from the layer replace the user's (`*` would merge objects deeply,
# keeping stale statusLine fields).
merged=$(jq -n --argjson user "$current" --slurpfile layer "$layer" '$user + $layer[0]')

keys_layer="$here/keybindings.json"
keys_target="$dir/keybindings.json"
jq empty "$keys_layer"

# Add each layer block's bindings to the user's block for that context; keys the
# user already binds (to an action or null) are left alone.
merge_keys() {
	jq -n --argjson user "$1" --slurpfile layer "$keys_layer" '
		reduce $layer[0].bindings[] as $block ($user;
			if any(.bindings[]?; .context == $block.context) then
				.bindings |= map(if .context == $block.context
					then .bindings = ($block.bindings + .bindings) else . end)
			else .bindings += [$block] end)'
}

if [[ "${1:-}" == "--dry-run" ]]; then
	echo "$merged"
	if [[ -L "$keys_target" || ! -e "$keys_target" ]]; then
		echo "would link $keys_target -> $keys_layer"
	else
		merge_keys "$(cat "$keys_target")"
	fi
	exit 0
fi

mkdir -p "$dir"
if [[ "$merged" == "$(jq . <<<"$current")" ]]; then
	echo "Claude Code settings already up to date: $target"
else
	[[ -f "$target" ]] && cp "$target" "$target.donburi-backup"
	tmp=$(mktemp "$dir/settings.json.XXXXXX")
	printf '%s\n' "$merged" >"$tmp"
	mv "$tmp" "$target"
	echo "Merged donburi's Claude Code settings into $target"
fi

if [[ -L "$keys_target" && "$(readlink "$keys_target")" == "$keys_layer" ]]; then
	echo "Claude Code keybindings already linked: $keys_target"
elif [[ ! -e "$keys_target" && ! -L "$keys_target" ]]; then
	ln -s "$keys_layer" "$keys_target"
	echo "Linked $keys_target -> $keys_layer"
else
	jq empty "$keys_target" 2>/dev/null || { echo "claude/install.sh: $keys_target is not valid JSON; not touching it" >&2; exit 1; }
	user_keys=$(jq '.bindings //= []' "$keys_target")
	keys=$(merge_keys "$user_keys")
	if [[ "$keys" == "$(jq . <<<"$user_keys")" ]]; then
		echo "Claude Code keybindings already up to date: $keys_target"
	else
		cp "$keys_target" "$keys_target.donburi-backup"
		tmp=$(mktemp "$dir/keybindings.json.XXXXXX")
		printf '%s\n' "$keys" >"$tmp"
		mv "$tmp" "$keys_target"
		echo "Merged donburi's Claude Code keybindings into $keys_target"
	fi
fi
