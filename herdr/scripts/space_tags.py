#!/usr/bin/env python3
"""Set the spaces sidebar's workspace tags: the coordinator's ◉ and "no git".

- `coordinator` ("◉"): on the workspace that holds the coordinator's tab (the
  tab labelled HERDR_COORDINATOR_NAME, scripts/coordinator.sh), so it follows
  the tab on any machine and comes back after herdr restarts.
- `no_git` ("no git"): on a workspace whose folder is not in a Git
  repository. herdr shows the branch from the folder of a workspace's first
  tab's root pane and leaves that row empty outside a repository.

[ui.sidebar.spaces] in config.toml shows both. herdr has no event for a pane
changing folder, so config.toml runs this as a tab-bar command every few
seconds: it prints nothing and only writes tokens that changed.
"""

from pathlib import Path
import sys

from agent_watch import COORDINATOR_MARK, call, coordinator_name

COORDINATOR = "coordinator"
NO_GIT = "no_git"
NO_GIT_LABEL = "no git"
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


def wanted(workspace_id, folders, coordinator_workspaces):
    """The tags a workspace should have; None clears one."""
    tags = {COORDINATOR: COORDINATOR_MARK[0] if workspace_id in coordinator_workspaces else None}
    folder = folders.get(workspace_id)
    if folder is not None:
        tags[NO_GIT] = None if in_git_repo(folder) else NO_GIT_LABEL
    return tags


def changes(workspaces, tabs, panes):
    """(workspace_id, {token: value}) for each workspace whose tags change."""
    folders = workspace_folders(tabs, panes)
    name = coordinator_name()
    coordinator_workspaces = {tab["workspace_id"] for tab in tabs if tab.get("label") == name}
    for workspace in workspaces:
        current = workspace.get("tokens", {})
        tags = wanted(workspace["workspace_id"], folders, coordinator_workspaces)
        changed = {token: value for token, value in tags.items() if current.get(token) != value}
        if changed:
            yield workspace["workspace_id"], changed


def main():
    try:
        workspaces = call("workspace.list")["workspaces"]
        tabs, panes = call("tab.list")["tabs"], call("pane.list")["panes"]
        for workspace_id, tokens in changes(workspaces, tabs, panes):
            call("workspace.report_metadata", {
                "workspace_id": workspace_id, "source": SOURCE, "tokens": tokens,
            })
    except (OSError, ValueError, RuntimeError, KeyError):
        pass  # herdr is restarting or busy; the next tick tries again
    return 0


if __name__ == "__main__":
    sys.exit(main())
