#!/bin/bash
# Herdr tab bar: git branch of the focused pane (blank outside a repo or on a
# detached HEAD).
#
# Reads HEAD with shell builtins instead of running git. herdr starts each
# tab-bar command through a login shell, and on this Mac every program start
# also waits on the endpoint-security agents; under load, the chain ending in
# Apple's /usr/bin/git shim (git, plus the real git it looks up) often missed
# herdr's timeout and blanked the branch.
cd -P -- "${HERDR_ACTIVE_PANE_CWD:-$PWD}" 2>/dev/null || exit 0
dir=$PWD

# Walk up to the folder holding .git (a directory, or a file in a linked
# worktree or submodule), as git does.
until [[ -e $dir/.git ]]; do
	parent=${dir%/*}
	[[ $parent == "$dir" ]] && exit 0
	dir=$parent
done

gitdir=$dir/.git
if [[ -f $gitdir ]]; then
	read -r line <"$gitdir" || [[ -n $line ]] || exit 0
	gitdir=${line#gitdir: }
	[[ $gitdir == /* ]] || gitdir=$dir/$gitdir
fi
read -r head <"$gitdir/HEAD" 2>/dev/null || [[ -n $head ]] || exit 0

case $head in
# A reftable repository keeps this placeholder in HEAD; only git can read it.
"ref: refs/heads/.invalid") branch=$(git -C "$dir" branch --show-current 2>/dev/null) ;;
"ref: refs/heads/"*) branch=${head#ref: refs/heads/} ;;
*) exit 0 ;; # detached HEAD
esac
[[ -n $branch ]] && echo " $branch"
exit 0
