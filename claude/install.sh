#!/usr/bin/env bash
# Merge donburi's global Claude Code settings (claude/settings.json) into
# ~/.claude/settings.json. Only the keys in claude/settings.json are set; every
# other key there (plugins, permissions, hooks...) is kept. The file is never
# overwritten wholesale, and a backup is kept next to it.
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

if [[ "${1:-}" == "--dry-run" ]]; then
	echo "$merged"
	exit 0
fi
if [[ "$merged" == "$(jq . <<<"$current")" ]]; then
	echo "Claude Code settings already up to date: $target"
	exit 0
fi
mkdir -p "$dir"
[[ -f "$target" ]] && cp "$target" "$target.donburi-backup"
tmp=$(mktemp "$dir/settings.json.XXXXXX")
printf '%s\n' "$merged" >"$tmp"
mv "$tmp" "$target"
echo "Merged donburi's Claude Code settings into $target"
