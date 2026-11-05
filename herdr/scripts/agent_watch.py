#!/usr/bin/env python3
"""Rolling agent feed for the herdr coordinator; uses only Python's stdlib.

Polls herdr's socket API and prints one line when an agent gets blocked on the
user, finishes a turn, appears, or exits. The coordinator runs it under Claude
Code's Monitor tool, so every line wakes the coordinator to report it. State is
saved between runs, so re-arming an expired monitor neither repeats nor misses
events. The calling pane (the coordinator itself) is never reported.
"""

import argparse
import json
import os
from pathlib import Path
import signal
import socket
import sys
import tempfile
import time


READY = {"idle", "done"}
BUSY = {"working", "blocked"}
# A saved state older than this is ignored, so an old run cannot flood the feed.
STALE_SECONDS = 600
# Each agent gets one marker as the pane metadata token `mark`: a shape that
# herdr shows on the agent's pane border and the coordinator writes in its
# replies, colored from the Kanagawa palette wherever color is possible (herdr
# sidebar rules in config.toml, highlights in transcript.lua). Shapes stay
# distinct because borders and Claude's own pane are not colored. herdr's state
# colors (yellow, red, teal, green) come last so a marker does not read as a
# state, and orange (herdr's accent) is the coordinator's own ◉. Keep
# config.toml and transcript.lua in step (test_agent_watch checks).
MARKS = [
    ("●", "#7FB4CA", "blue circle"),       # springBlue
    ("◆", "#957FB8", "violet diamond"),    # oniViolet
    ("■", "#7E9CD8", "indigo square"),     # crystalBlue
    ("▲", "#D27E99", "pink triangle"),     # sakuraPink
    ("★", "#DCD7BA", "white star"),        # fujiWhite
    ("▼", "#C0A36E", "gold triangle"),     # boatYellow2
    ("✚", "#A3D4D5", "cyan cross"),        # lightBlue
    ("✦", "#E46876", "rose spark"),        # waveRed
]
GLYPHS = [glyph for glyph, _, _ in MARKS]
COORDINATOR_MARK = ("◉", "#FF9E64", "coordinator")  # surimiOrange, herdr's accent
MARK_SOURCE = "donburi-marks"


def coordinator_name():
    return os.environ.get("HERDR_COORDINATOR_NAME") or "coordinator"


def state_path():
    base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
    return Path(base) / "herdr/coordinator/agents.json"


def call(method, params=None):
    """Send one request; herdr closes the connection after its reply."""
    path = os.environ.get("HERDR_SOCKET_PATH") or str(Path.home() / ".config/herdr/herdr.sock")
    request = json.dumps({"id": method, "method": method, "params": params or {}})
    with socket.socket(socket.AF_UNIX) as conn:
        conn.settimeout(5)
        conn.connect(path)
        conn.sendall(request.encode() + b"\n")
        data = b""
        while not data.endswith(b"\n"):
            chunk = conn.recv(1 << 20)
            if not chunk:
                break
            data += chunk
    reply = json.loads(data)
    if "error" in reply:
        raise RuntimeError(reply["error"].get("message", reply["error"]))
    return reply["result"]


def info(agent):
    return {
        "pane_id": agent["pane_id"],
        "workspace_id": agent.get("workspace_id"),
        "name": agent.get("name"),
        "agent": agent.get("agent"),
        "title": agent.get("terminal_title_stripped") or agent.get("title") or "",
        "mark": (agent.get("tokens") or {}).get("mark") or "",
    }


def assign_marks(agents, exclude=()):
    """Map each live agent's terminal to a marker: the coordinator always gets
    ◉; others keep the one herdr already has, and new agents get the least-used
    one. Returns {terminal_id: glyph}."""
    coordinator = coordinator_name()
    marks = {a["terminal_id"]: COORDINATOR_MARK[0] for a in agents
             if a.get("terminal_id") and a.get("name") == coordinator}
    live = [a for a in agents if a.get("terminal_id") and a["pane_id"] not in exclude
            and a["terminal_id"] not in marks]
    for agent in live:
        mark = (agent.get("tokens") or {}).get("mark")
        if mark in GLYPHS:
            marks[agent["terminal_id"]] = mark
    for agent in live:
        if agent["terminal_id"] not in marks:
            used = list(marks.values())
            marks[agent["terminal_id"]] = min(GLYPHS, key=lambda g: (used.count(g), GLYPHS.index(g)))
    return marks


def paint(agents, marks, failed):
    """Report each agent's marker to herdr when it is missing or stale; tag the agent dicts."""
    for agent in agents:
        mark = marks.get(agent.get("terminal_id"))
        if not mark:
            continue
        label = f"{mark} {agent.get('name') or agent.get('agent') or 'agent'}"
        tokens = agent["tokens"] if isinstance(agent.get("tokens"), dict) else {}
        if (tokens.get("mark") != mark or agent.get("display_agent") != label) and agent["terminal_id"] not in failed:
            try:
                call("pane.report_metadata", {"pane_id": agent["pane_id"], "source": MARK_SOURCE,
                                              "tokens": {"mark": mark}, "display_agent": label})
            except (OSError, ValueError, RuntimeError):
                failed.add(agent["terminal_id"])
        agent["tokens"] = {**tokens, "mark": mark}


def step(tracks, agents, now, settle, exclude=(), announce_new=True):
    """Advance per-pane tracks with a fresh agent list; return (tracks, events).

    blocked is reported at once and only once per episode; finished is reported
    when a busy agent has stayed idle/done for `settle` seconds, which hides
    brief flickers between tool calls.
    """
    events, result = [], {}
    for agent in agents:
        pane = agent["pane_id"]
        if pane in exclude:
            continue
        status = agent.get("agent_status") or "unknown"
        old = tracks.get(pane)
        if old and old["info"]["agent"] != agent.get("agent"):
            events.append(("gone", old["info"]))
            old = None
        if old is None:
            track = {"status": status, "since": now, "busy": status in BUSY, "blocked": False}
            if announce_new:
                events.append(("started", info(agent)))
        else:
            track = dict(old)
            if status != track["status"]:
                track.update(status=status, since=now)
        track["info"] = info(agent)

        if status == "blocked" and not track["blocked"]:
            events.append(("blocked", track["info"]))
        track["blocked"] = status == "blocked"
        if status in BUSY:
            track["busy"] = True
        elif status in READY and track["busy"] and now - track["since"] >= settle:
            events.append(("finished", track["info"]))
            track["busy"] = False
        result[pane] = track

    for pane, track in tracks.items():
        if pane not in result and pane not in exclude:
            events.append(("gone", track["info"]))
    return result, events


def counts(agents, exclude=()):
    """Agents per status, leaving out the coordinator and `exclude` panes."""
    coordinator = coordinator_name()
    result = {"agents": 0}
    for agent in agents:
        if agent.get("name") == coordinator or agent["pane_id"] in exclude:
            continue
        status = agent.get("agent_status") or "unknown"
        result["agents"] += 1
        result[status] = result.get(status, 0) + 1
    return result


def summary(tracks):
    counts = {}
    for track in tracks.values():
        status = track["status"]
        counts[status] = counts.get(status, 0) + 1
    detail = ", ".join(f"{counts[s]} {s}" for s in ("blocked", "working", "done", "idle", "unknown") if s in counts)
    return f"watching {len(tracks)} agents" + (f": {detail}" if detail else "")


def describe(kind, item, labels, clock):
    target = f"{item['name']} ({item['pane_id']})" if item.get("name") else item["pane_id"]
    if item.get("mark"):
        target = f"{item['mark']} {target}"
    where = labels.get(item.get("workspace_id"), item.get("workspace_id") or "?")
    title = f": {item['title']}" if item.get("title") else ""
    return f"{clock} {kind:<8} {target} {item.get('agent') or '?'} in {where}{title}"


def workspace_labels():
    try:
        return {w["workspace_id"]: w.get("label") or w["workspace_id"]
                for w in call("workspace.list")["workspaces"]}
    except (OSError, ValueError, RuntimeError, KeyError):
        return {}


def load_state(path, now):
    try:
        saved = json.loads(path.read_text())
        if now - saved["saved_at"] < STALE_SECONDS and isinstance(saved["tracks"], dict):
            return saved["tracks"]
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def save_state(path, tracks, now):
    temporary = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
            temporary = Path(file.name)
            json.dump({"saved_at": now, "tracks": tracks}, file)
        temporary.replace(path)
    except OSError:
        if temporary:
            temporary.unlink(missing_ok=True)


def emit(line):
    print(line, flush=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Print one line per herdr agent event for the coordinator.")
    parser.add_argument("--interval", type=float, default=1.0, help="seconds between polls (default 1)")
    parser.add_argument("--settle", type=float, default=3.0,
                        help="seconds an agent must stay idle/done to count as finished (default 3)")
    parser.add_argument("--exclude", action="append", default=[], metavar="PANE",
                        help="pane id to ignore; the calling pane is always ignored")
    parser.add_argument("--once", action="store_true", help="exit after the first batch of events")
    parser.add_argument("--no-marks", action="store_true", help="do not give agents colored markers in herdr")
    parser.add_argument("--counts", action="store_true",
                        help="print agents per status as JSON once and exit (for the coordinator's banners)")
    parser.add_argument("--state", type=Path, default=None, help="state file (default under XDG_STATE_HOME)")
    args = parser.parse_args(argv)

    exclude = set(args.exclude)
    if os.environ.get("HERDR_PANE_ID"):
        exclude.add(os.environ["HERDR_PANE_ID"])
    if args.counts:
        try:
            emit(json.dumps(counts(call("agent.list")["agents"], exclude)))
            return 0
        except (OSError, ValueError, RuntimeError, KeyError) as error:
            emit(json.dumps({"error": str(error)}))
            return 1
    path = args.state or state_path()
    saved = load_state(path, time.time())
    tracks, fresh, down, failed = saved or {}, saved is None, False, set()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    while True:
        now = time.time()
        try:
            agents = call("agent.list")["agents"]
        except (OSError, ValueError, RuntimeError, KeyError) as error:
            if not down:
                emit(f"{time.strftime('%H:%M:%S')} herdr unavailable, retrying: {error}")
                down = True
            time.sleep(5)
            continue
        if down:
            emit(f"{time.strftime('%H:%M:%S')} herdr reachable again")
            down = False

        if not args.no_marks:
            paint(agents, assign_marks(agents, exclude), failed)
        updated, events = step(tracks, agents, now, args.settle, exclude, announce_new=not fresh)
        if fresh:
            emit(f"{time.strftime('%H:%M:%S')} {summary(updated)}")
            fresh = False
        if events:
            labels, clock = workspace_labels(), time.strftime("%H:%M:%S")
            for kind, item in events:
                emit(describe(kind, item, labels, clock))
        if updated != tracks or events:
            save_state(path, updated, now)
        tracks = updated
        if events and args.once:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
