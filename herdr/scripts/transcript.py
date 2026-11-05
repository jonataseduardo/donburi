#!/usr/bin/env python3
"""Render Claude Code conversations as Markdown for reading in Neovim; stdlib only.

`--agent TARGET` follows a herdr agent (name or pane ID) through its Claude
sessions: the output holds the agent's last few sessions, oldest first, and
picks up new ones after /clear or a restart. `--session ID|PATH` renders one
transcript. With --follow it re-renders whenever the transcript grows.

Turns become `## HH:MM · you` / `## HH:MM · claude` headings (sessions are `#`),
tool calls one line each, and Monitor feed events short `### feed` blocks.
Thinking and tool output are left out.
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


TOOL_ARGS = ("command", "file_path", "path", "pattern", "url", "query", "skill", "description", "prompt")
TAG = re.compile(r"<(summary|event|status)>(.*?)</\1>", re.S)
FENCE = re.compile(r"^\s*(```|~~~)")


def claude_dir():
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")


def state_dir():
    base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
    return Path(base) / "herdr/coordinator"


def find_transcript(session):
    """Accept a transcript path or a session ID; return the JSONL path or None."""
    path = Path(session).expanduser()
    if path.suffix == ".jsonl" and path.exists():
        return path
    return next(claude_dir().joinpath("projects").glob(f"*/{session}.jsonl"), None)


def agent_session(target):
    """The Claude session ID herdr reports for an agent, or None."""
    herdr = os.environ.get("HERDR_BIN_PATH", "herdr")
    try:
        out = subprocess.run([herdr, "agent", "get", target], capture_output=True, text=True, timeout=5)
        session = json.loads(out.stdout)["result"]["agent"].get("agent_session") or {}
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        return None
    return session.get("value") if session.get("kind") == "id" else None


def local_time(entry, fmt, fallback):
    """Format an entry's UTC ISO timestamp in local time."""
    try:
        stamp = datetime.strptime(entry["timestamp"][:19], "%Y-%m-%dT%H:%M:%S")
        return stamp.replace(tzinfo=timezone.utc).astimezone().strftime(fmt)
    except (KeyError, TypeError, ValueError):
        return fallback


def clock(entry):
    return local_time(entry, "%H:%M", "--:--")


def day(entry):
    return local_time(entry, "%Y-%m-%d %H:%M", "unknown date")


def body(text):
    """Demote headings in message text below the transcript's own # and ## levels."""
    lines, fenced = [], False
    for line in text.strip().splitlines():
        if FENCE.match(line):
            fenced = not fenced
        elif not fenced and line.startswith("#"):
            line = "##" + line
        lines.append(line)
    return "\n".join(lines)


def tool_line(block):
    args = block.get("input") or {}
    detail = next((str(args[k]) for k in TOOL_ARGS if args.get(k)), "")
    detail = " ".join(detail.split())
    if len(detail) > 120:
        detail = detail[:117] + "..."
    return f"- ▸ {block.get('name', 'tool')}" + (f" `{detail}`" if detail else "")


def notification(text):
    parts = {key: value.strip() for key, value in TAG.findall(text)}
    summary = parts.get("summary", "")
    if summary.startswith("Monitor event") and "event" in parts:
        return "feed", parts["event"]
    status = parts.get("status", "")
    status = f" ({status})" if status and status not in summary else ""
    return "task", (summary or "background task finished") + status


def text_of(content):
    if isinstance(content, str):
        return content
    pieces = []
    for block in content or []:
        if block.get("type") == "text":
            pieces.append(block.get("text", ""))
        elif block.get("type") == "image":
            pieces.append("[image]")
    return "\n".join(pieces)


def render_session(entries):
    """Markdown for one session's JSONL entries; returns (title, markdown)."""
    out, speaker, title, first = [], None, None, None

    def turn(who, entry):
        nonlocal speaker
        out.append(f"\n## {clock(entry)} · {who}\n")
        speaker = who

    for entry in entries:
        kind = entry.get("type")
        if kind == "ai-title":
            title = entry.get("aiTitle") or title
        elif kind == "user":
            content = entry.get("message", {}).get("content")
            origin = (entry.get("origin") or {}).get("kind")
            if origin == "human":
                text = body(text_of(content))
                first = first or text
                turn("you", entry)
                out.append(text)
            elif origin == "task-notification" and isinstance(content, str):
                label, text = notification(content)
                out.append(f"\n### {clock(entry)} · {label}\n\n```text\n{text}\n```")
                speaker = label
            elif origin == "peer" and isinstance(content, str):
                out.append(f"\n### {clock(entry)} · agent message\n\n{body(content.splitlines()[0])}")
                speaker = "peer"
        elif kind == "attachment":
            attachment = entry.get("attachment") or {}
            prompt = attachment.get("prompt")
            if attachment.get("type") != "queued_command" or not isinstance(prompt, str):
                continue
            if (attachment.get("origin") or {}).get("kind") == "task-notification" or "<task-notification>" in prompt:
                label, text = notification(prompt)
                out.append(f"\n### {clock(entry)} · {label}\n\n```text\n{text}\n```")
                speaker = label
            else:
                turn("you (while it worked)", entry)
                out.append(body(prompt))
        elif kind == "assistant":
            for block in entry.get("message", {}).get("content") or []:
                if block.get("type") not in ("text", "tool_use"):
                    continue
                if speaker != "claude":
                    turn("claude", entry)
                if block["type"] == "text" and block.get("text", "").strip():
                    out.append(body(block["text"]))
                elif block["type"] == "tool_use":
                    out.append(tool_line(block))
    if not title and first:
        title = " ".join(first.split())[:60]
    started = day(next((e for e in entries if e.get("timestamp")), {}))
    # Blank lines between chunks, except within a run of tool lines.
    text = ""
    for chunk in out:
        tight = chunk.startswith("- ▸") and text.endswith("`") and text.rsplit("\n", 1)[-1].startswith("- ▸")
        text += ("\n" if tight else "\n\n") + chunk.strip("\n")
    return f"# {started} · {title or 'new session'}" + text + "\n"


def read_entries(path):
    entries = []
    try:
        with path.open(errors="replace") as file:
            for line in file:
                try:
                    entries.append(json.loads(line))
                except ValueError:
                    continue  # a line still being written
    except OSError:
        pass
    return entries


def render(paths):
    return "\n\n".join(render_session(read_entries(path)) for path in paths) or "_No conversation yet._\n"


def write(out, text):
    if out == "-":
        sys.stdout.write(text)
        return
    path = Path(out)
    if path.exists() and path.read_text(errors="replace") == text:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
        file.write(text)
    Path(file.name).replace(path)


def remember(history_file, session, keep):
    """Append a newly seen session ID to the agent's history; return the list."""
    try:
        sessions = json.loads(history_file.read_text())
        sessions = sessions if isinstance(sessions, list) else []
    except (OSError, ValueError):
        sessions = []
    if session and session not in sessions:
        sessions = (sessions + [session])[-max(keep, 1) * 4:]
        history_file.parent.mkdir(parents=True, exist_ok=True)
        history_file.write_text(json.dumps(sessions))
    return sessions


def main(argv=None):
    parser = argparse.ArgumentParser(description="Render Claude Code conversations as Markdown.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--agent", help="herdr agent name or pane ID to follow")
    source.add_argument("--session", help="Claude session ID or transcript path")
    parser.add_argument("--out", default="-", help="output file (default: stdout)")
    parser.add_argument("--follow", action="store_true", help="keep re-rendering as the conversation grows")
    parser.add_argument("--keep", type=int, default=5, help="sessions of an agent's history to show (default 5)")
    args = parser.parse_args(argv)

    history_file = state_dir() / f"{re.sub(r'[^A-Za-z0-9_-]', '_', args.agent or 'session')}-sessions.json"
    last_check, signature, paths = 0.0, None, []
    while True:
        now = time.time()
        if args.session:
            found = find_transcript(args.session)
            paths = [found] if found else []
        elif now - last_check >= 2 or not paths:
            last_check = now
            sessions = remember(history_file, agent_session(args.agent), args.keep)
            paths = [p for p in (find_transcript(s) for s in sessions) if p][-args.keep:]
        current = [(str(p), p.stat().st_size if p.exists() else 0) for p in paths]
        if current != signature:
            signature = current
            write(args.out, render(paths))
        if not args.follow:
            return 0
        time.sleep(0.5)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
