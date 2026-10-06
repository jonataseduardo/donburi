#!/bin/bash
# Herdr tab bar: git branch of the focused pane (blank outside a repo)
cd "${HERDR_ACTIVE_PANE_CWD:-$PWD}" 2>/dev/null || exit 0
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] && echo " $branch"
exit 0
