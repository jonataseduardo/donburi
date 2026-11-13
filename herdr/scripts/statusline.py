#!/usr/bin/env python3
"""Claude Code status line for every session; uses only Python's stdlib.

Set as `statusLine` in claude/settings.json, which claude/install.sh merges
into ~/.claude/settings.json. The coordinator overrides it with its own orange
"◉ COORDINATOR" banner (coordinator_status.py); this worker line stays muted:

    NORMAL  ▲ api-impl  donburi/herdr  Opus 5.5  42%

vim mode, the herdr agent's marker and name (only inside a herdr pane), the
repository folder and branch, the model, and how much of the context window
is used.
"""

import json
import os
from pathlib import Path
import sys

import agent_watch

RESET = "\033[0m"


def color(hex_color):
    red, green, blue = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[38;2;{red};{green};{blue}m"


MUTED = color("#727169")    # fujiGray
TEXT = color("#C8C093")     # oldWhite
MODES = {"NORMAL": color("#7FB4CA"), "INSERT": color("#98BB6C")}  # springBlue, springGreen
MARK_COLORS = {glyph: hex_color for glyph, hex_color, _ in agent_watch.MARKS}
MARK_COLORS[agent_watch.COORDINATOR_MARK[0]] = agent_watch.COORDINATOR_MARK[1]


def vim_mode(data):
    """The vim mode Claude Code reports, or "" when vim mode is off."""
    vim = data.get("vim")
    return (vim.get("mode") or "") if isinstance(vim, dict) else ""


def mode_part(mode):
    """The vim mode in its own color ("" when vim mode is off)."""
    return f"\033[1m{MODES.get(mode.upper(), TEXT)}{mode.upper()}{RESET}" if mode else ""


def branch(folder):
    """The Git branch of folder (worktrees included); "" outside a repository or detached."""
    path = Path(folder)
    for directory in (path, *path.parents):
        gitdir = directory / ".git"
        if gitdir.is_file():
            line = gitdir.read_text().strip()
            gitdir = Path(line.removeprefix("gitdir: "))
            if not gitdir.is_absolute():
                gitdir = directory / gitdir
        if gitdir.exists():
            try:
                head = (gitdir / "HEAD").read_text().strip()
            except OSError:
                return ""
            return head.removeprefix("ref: refs/heads/") if head.startswith("ref: refs/heads/") else ""
    return ""


def repo_part(folder):
    if not folder:
        return ""
    name = Path(folder).name or folder
    current = branch(folder)
    return f"{TEXT}{name}{MUTED}/{current}{RESET}" if current else f"{TEXT}{name}{RESET}"


def agent_part(agent):
    """The herdr agent's marker in its color, then its name (or harness)."""
    if not agent:
        return ""
    mark = (agent.get("tokens") or {}).get("mark") or ""
    name = agent.get("name") or agent.get("agent") or ""
    glyph = f"{color(MARK_COLORS[mark])}{mark}{RESET} " if mark in MARK_COLORS else ""
    return f"{glyph}{TEXT}{name}{RESET}" if (glyph or name) else ""


def herdr_agent(pane_id):
    """This pane's herdr agent, or None outside herdr or when herdr is down."""
    if not pane_id:
        return None
    try:
        agents = agent_watch.call("agent.list")["agents"]
    except (OSError, ValueError, RuntimeError, KeyError):
        return None
    return next((a for a in agents if a.get("pane_id") == pane_id), None)


def status_line(data, agent=None):
    workspace = data.get("workspace") or {}
    folder = workspace.get("current_dir") or data.get("cwd") or ""
    model = (data.get("model") or {}).get("display_name") or ""
    used = (data.get("context_window") or {}).get("used_percentage")
    parts = [mode_part(vim_mode(data)), agent_part(agent), repo_part(folder),
             f"{MUTED}{model}{RESET}" if model else "",
             f"{MUTED}{round(used)}%{RESET}" if isinstance(used, (int, float)) else ""]
    return "  ".join(part for part in parts if part)


def main():
    try:
        data = json.load(sys.stdin)
    except ValueError:
        data = {}
    if not isinstance(data, dict):
        data = {}
    print(status_line(data, herdr_agent(os.environ.get("HERDR_PANE_ID"))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
