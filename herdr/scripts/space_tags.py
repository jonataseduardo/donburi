#!/usr/bin/env python3
"""Tag workspaces whose folder is not in a Git repository ("no git").

herdr shows a workspace's branch from the folder of its first tab's root pane
and leaves that row empty outside a repository. This reports the workspace
metadata token `no_git` ("no git") for those workspaces and clears it once the
folder is in a repository; [ui.sidebar.spaces] in config.toml shows it beside
the branch. herdr has no event for a pane changing folder, so config.toml runs
this as a tab-bar command every few seconds: it prints nothing and only writes
tokens that changed.
"""

from pathlib import Path
import sys

from agent_watch import call

TOKEN = "no_git"
LABEL = "no git"
SOURCE = "donburi-spaces"
# herdr's public id digits (encode_public_number in herdr's workspace.rs).
ALPHABET = "123456789ABCDEFGHJKMNPQRSTVWXYZ0"


def pane_number(pane_id):
    """herdr's pane number ("w3:pA" -> 10), so a tab's first pane sorts first."""
    value = 0
    for digit in pane_id.rpartition(":p")[2]:
        if digit not in ALPHABET:
            return sys.maxsize
        value = value * len(ALPHABET) + ALPHABET.index(digit) + 1
    return value


def in_git_repo(folder):
    path = Path(folder)
    return any((parent / ".git").exists() for parent in (path, *path.parents))


def workspace_folders(tabs, panes):
    """Each workspace's folder: the cwd of its first tab's first pane, as herdr uses."""
    first_tab = {}
    for tab in tabs:
        first_tab.setdefault(tab["workspace_id"], tab["tab_id"])
    folders = {}
    for pane in sorted(panes, key=lambda pane: pane_number(pane["pane_id"])):
        workspace = pane.get("workspace_id")
        if pane.get("cwd") and pane.get("tab_id") == first_tab.get(workspace):
            folders.setdefault(workspace, pane["cwd"])
    return folders


def changes(workspaces, folders):
    """(workspace_id, value) for every tag to set, or to clear with None."""
    for workspace in workspaces:
        folder = folders.get(workspace["workspace_id"])
        if folder is None:
            continue
        wanted = None if in_git_repo(folder) else LABEL
        if workspace.get("tokens", {}).get(TOKEN) != wanted:
            yield workspace["workspace_id"], wanted


def main():
    try:
        workspaces = call("workspace.list")["workspaces"]
        folders = workspace_folders(call("tab.list")["tabs"], call("pane.list")["panes"])
        for workspace_id, value in changes(workspaces, folders):
            call("workspace.report_metadata", {
                "workspace_id": workspace_id, "source": SOURCE, "tokens": {TOKEN: value},
            })
    except (OSError, ValueError, RuntimeError, KeyError):
        pass  # herdr is restarting or busy; the next tick tries again
    return 0


if __name__ == "__main__":
    sys.exit(main())
