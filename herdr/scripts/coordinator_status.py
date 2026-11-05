#!/usr/bin/env python3
"""Claude Code status line for the herdr coordinator; uses only Python's stdlib.

Set as `statusLine` in herdr/coordinator-settings.json. Prints an orange
"◉ COORDINATOR" block (the same banner as the Neovim history pane above it),
the model, and how many agents herdr has, highlighting blocked and working ones
in herdr's own state colors.
"""

import json
import os
import sys

import agent_watch

RESET = "\033[0m"


def color(hex_color, background=False):
    red, green, blue = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[{48 if background else 38};2;{red};{green};{blue}m"


TITLE = "\033[1m" + color("#16161D") + color(agent_watch.COORDINATOR_MARK[1], background=True)
MUTED = color("#727169")    # fujiGray
BLOCKED = "\033[1m" + color("#FF5D62")  # herdr's blocked red
WORKING = color("#E6C384")  # herdr's working yellow


def status_line(model, counts):
    parts = [f"{TITLE} {agent_watch.COORDINATOR_MARK[0]} COORDINATOR {RESET}"]
    if model:
        parts.append(f"{MUTED}{model}{RESET}")
    if counts is None:
        parts.append(f"{BLOCKED}herdr unavailable{RESET}")
    else:
        total = counts.get("agents", 0)
        detail = [f"{total} agent{'' if total == 1 else 's'}"]
        if counts.get("blocked"):
            detail.append(f"{BLOCKED}{counts['blocked']} blocked{RESET}")
        if counts.get("working"):
            detail.append(f"{WORKING}{counts['working']} working{RESET}")
        parts.append(" · ".join(detail))
    return " ".join(parts)


def main():
    try:
        model = (json.load(sys.stdin).get("model") or {}).get("display_name") or ""
    except (ValueError, AttributeError):
        model = ""
    exclude = {os.environ["HERDR_PANE_ID"]} if os.environ.get("HERDR_PANE_ID") else set()
    try:
        counts = agent_watch.counts(agent_watch.call("agent.list")["agents"], exclude)
    except (OSError, ValueError, RuntimeError, KeyError):
        counts = None
    print(status_line(model, counts))


if __name__ == "__main__":
    main()
