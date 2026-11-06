#!/usr/bin/env python3
"""Render Claude Code conversations as Markdown for reading in Neovim; stdlib only.

`--agent TARGET` follows a herdr agent (name or pane ID) through its Claude
sessions: the output holds the agent's last few sessions, oldest first, and
picks up new ones after /clear or a restart. `--session ID|PATH` renders one
transcript. With --follow it re-renders whenever the transcript grows.

Turns become `## HH:MM · you` / `## HH:MM · claude` headings (sessions are `#`),
tool calls one line each, and Monitor feed events short `### feed` blocks.
Thinking and tool output are left out.

`--days DIR` also writes one file per local day (DIR/YYYY-MM-DD.md, a session
that crosses midnight continues under "(continued)") plus DIR/index.md. Day
files are an archive: they are written atomically and never replaced by a
render with less in it, so they outlive the --keep window and Claude's own
transcript cleanup. DIR/sources.json lists the sessions in each day, which is
always rendered from all of them; an entry copied into a resumed session is
rendered once. `--backfill` renders every session of the agent still on disk
into DIR once and exits.
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


def session_title(entries):
    """The session's AI title, else its first prompt (shortened)."""
    title, first = None, None
    for entry in entries:
        if entry.get("type") == "ai-title":
            title = entry.get("aiTitle") or title
        elif (entry.get("type") == "user" and (entry.get("origin") or {}).get("kind") == "human"
              and first is None):
            first = body(text_of(entry.get("message", {}).get("content")))
    if not title and first:
        title = " ".join(first.split())[:60]
    return title


def render_session(entries, title=None, continued=False):
    """Markdown for one session's JSONL entries (or one day's part of them)."""
    out, speaker, own_title, first = [], None, None, None

    def turn(who, entry):
        nonlocal speaker
        out.append(f"\n## {clock(entry)} · {who}\n")
        speaker = who

    for entry in entries:
        kind = entry.get("type")
        if kind == "ai-title":
            own_title = entry.get("aiTitle") or own_title
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
    if title is None:
        title = own_title or (" ".join(first.split())[:60] if first else None)
    started = day(next((e for e in entries if e.get("timestamp")), {}))
    # Blank lines between chunks, except within a run of tool lines.
    text = ""
    for chunk in out:
        tight = chunk.startswith("- ▸") and text.endswith("`") and text.rsplit("\n", 1)[-1].startswith("- ▸")
        text += ("\n" if tight else "\n\n") + chunk.strip("\n")
    return f"# {started} · {title or 'new session'}" + (" (continued)" if continued else "") + text + "\n"


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


def render(paths, reader=read_entries):
    return "\n\n".join(render_session(reader(path)) for path in paths) or "_No conversation yet._\n"


class CachedReader:
    """read_entries that re-reads a transcript only when it changed on disk."""

    def __init__(self):
        self.cache = {}

    def __call__(self, path):
        try:
            stat = path.stat()
        except OSError:
            return []
        key = (stat.st_size, stat.st_mtime_ns)
        if self.cache.get(path, (None,))[0] != key:
            self.cache[path] = (key, read_entries(path))
        return self.cache[path][1]


def split_by_day(entries):
    """[(YYYY-MM-DD, entries)]: runs of entries on one local date, in order.
    Entries without a timestamp stay with the run they follow."""
    groups, pending = [], []
    for entry in entries:
        date = local_time(entry, "%Y-%m-%d", None) if entry.get("timestamp") else None
        if date is None:
            (groups[-1][1] if groups else pending).append(entry)
        elif groups and groups[-1][0] == date:
            groups[-1][1].append(entry)
        else:
            groups.append((date, pending + [entry]))
            pending = []
    return groups


def render_days(paths, reader=read_entries):
    """{YYYY-MM-DD: Markdown} for the sessions in `paths`, sessions in time order.

    Each entry is rendered once. A resumed session can begin with copies of the
    previous session's entries (same uuid, new sessionId); the copies stay with
    the original, which sorts first: it starts no later and ends earlier."""
    def span(path):
        stamps = [e["timestamp"] for e in reader(path) if e.get("timestamp")]
        return (min(stamps, default=""), max(stamps, default=""), Path(path).name)

    parts, seen = {}, set()
    for path in sorted(paths, key=span):
        entries = reader(path)
        title = session_title(entries)
        fresh = [e for e in entries if not e.get("uuid") or e["uuid"] not in seen]
        seen.update(e["uuid"] for e in entries if e.get("uuid"))
        for index, (date, group) in enumerate(split_by_day(fresh)):
            markdown = render_session(group, title=title, continued=index > 0)
            if units(markdown) < 2:  # just the heading: nothing of its own that day
                continue
            start = next(e["timestamp"] for e in group if e.get("timestamp"))
            parts.setdefault(date, []).append((start, markdown))
    return {date: "\n\n".join(md for _, md in sorted(chunks)) for date, chunks in parts.items()}


UNIT = re.compile(r"^(#{1,3} \S|- ▸ |\d\d:\d\d:\d\d )")


def units(markdown):
    """Rendered items (headings, tool lines, feed events): a day file never loses any."""
    return sum(1 for line in markdown.splitlines() if UNIT.match(line))


def write_days(days_dir, days):
    """Write each day's file unless the new render has fewer items; return the days written."""
    written = []
    for date, markdown in sorted(days.items()):
        path = Path(days_dir) / f"{date}.md"
        try:
            old = path.read_text(errors="replace")
        except OSError:
            old = None
        if old == markdown or (old is not None and units(markdown) < units(old)):
            continue
        write(path, markdown)
        written.append(date)
    return written


PANE = r"(?<![\w:-])(w\w+:p\d+)(?![\w:-])"


def day_stats(markdown):
    """Sessions, turns, feed events and the agents a day names (pane ID -> name or None)."""
    sessions = turns = events = 0
    agents, in_feed, fenced = {}, False, False
    for line in markdown.splitlines():
        if line.startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            if re.match(r"^# \d{4}-\d\d-\d\d ", line):
                sessions += 1
            if re.match(r"^## \d\d:\d\d · ", line):
                turns += 1
            if re.match(r"^#{1,3} \d", line):
                in_feed = bool(re.match(r"^### \d\d:\d\d · feed$", line))
        elif in_feed and re.match(r"^\d\d:\d\d:\d\d ", line):
            events += 1
        for pane in re.findall(PANE, line):
            agents.setdefault(pane, None)
        # Same sources as the history view's tags: agent name, workspace, label.
        for name, pane in re.findall(r"([\w.-]+) \((w\w+:p\d+)\) \S+ in ", line):
            agents[pane] = name
        for pane, workspace in re.findall(PANE + r" \S+ in ([\w.-]+)", line):
            agents[pane] = agents[pane] or workspace
        for pane, label in re.findall(PANE + r" \(([\w.-]+)\)", line):
            agents[pane] = agents[pane] or label
    return sessions, turns, events, agents


def write_index(days_dir):
    """DIR/index.md: one row per day file, newest first."""
    rows = []
    for path in sorted(Path(days_dir).glob("[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md"), reverse=True):
        sessions, turns, events, agents = day_stats(path.read_text(errors="replace"))
        names = ", ".join(f"{pane} {name}" if name else pane for pane, name in sorted(agents.items()))
        rows.append(f"| [{path.stem}]({path.name}) | {sessions} | {turns} | {events} | {names} |")
    write(Path(days_dir) / "index.md", "# History by day\n\n| Day | Sessions | Turns | Feed events | Agents |\n"
          "|-----|----------|-------|-------------|--------|\n" + "".join(row + "\n" for row in rows))


def update_days(days_dir, paths, reader=read_entries):
    """Write the day files of the days the sessions in `paths` touch; return the
    days written. DIR/sources.json keeps every session that went into a day, so
    a day is always rendered from all of them, also from sessions the caller no
    longer passes (older ones out of the agent's list, backfilled ones)."""
    days_dir = Path(days_dir)
    try:
        sources = json.loads((days_dir / "sources.json").read_text())
        sources = sources if isinstance(sources, dict) else {}
    except (OSError, ValueError):
        sources = {}
    dates = {date for path in paths for date, _ in split_by_day(reader(path))}
    every = {Path(path) for path in paths}
    every |= {Path(p) for date in dates for p in sources.get(date, []) if Path(p).exists()}
    days = {date: md for date, md in render_days(every, reader).items() if date in dates}
    written = write_days(days_dir, days)
    for path in every:
        for date, _ in split_by_day(reader(path)):
            if date in dates:
                sources[date] = sorted(set(sources.get(date, [])) | {str(path)})
    if days:
        write(days_dir / "sources.json", json.dumps(sources, indent=1, sort_keys=True) + "\n")
    if written or not (days_dir / "index.md").exists():
        write_index(days_dir)
    return written


def named_sessions(name, folders):
    """Transcripts in `folders` that Claude Code names `name` (claude --name)."""
    found = []
    for folder in folders:
        for path in Path(folder).glob("*.jsonl"):
            try:
                text = path.read_text(errors="replace")
            except OSError:
                continue
            if name not in text:
                continue
            for line in text.splitlines():
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if name in (entry.get("customTitle"), entry.get("agentName")):
                    found.append(path)
                    break
    return found


def first_timestamp(path, reader=read_entries):
    return next((e["timestamp"] for e in reader(path) if e.get("timestamp")), "")


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
    parser.add_argument("--days", metavar="DIR", help="also write one file per local day, plus index.md, into DIR")
    parser.add_argument("--backfill", action="store_true",
                        help="with --agent and --days: render every session of the agent still on disk, then exit")
    args = parser.parse_args(argv)
    if args.backfill and not (args.agent and args.days):
        parser.error("--backfill needs --agent and --days")

    history_file = state_dir() / f"{re.sub(r'[^A-Za-z0-9_-]', '_', args.agent or 'session')}-sessions.json"
    reader = CachedReader()
    if args.backfill:
        return backfill(args.agent, args.days, history_file, reader)

    last_check, signature, paths, all_paths = 0.0, None, [], []
    while True:
        now = time.time()
        if args.session:
            found = find_transcript(args.session)
            paths = all_paths = [found] if found else []
        elif now - last_check >= 2 or not paths:
            last_check = now
            sessions = remember(history_file, agent_session(args.agent), args.keep)
            # Day files take every remembered session; the main output the last --keep.
            all_paths = [p for p in (find_transcript(s) for s in sessions) if p]
            paths = all_paths[-args.keep:]
        current = [(str(p), p.stat().st_size if p.exists() else 0) for p in all_paths]
        if current != signature:
            signature = current
            write(args.out, render(paths, reader))
            if args.days:
                update_days(args.days, all_paths, reader)
        if not args.follow:
            return 0
        time.sleep(0.5)


def backfill(agent, days_dir, history_file, reader):
    """Render the agent's remembered sessions, and every other transcript Claude
    named after it in the same project folders, into day files once."""
    try:
        remembered = json.loads(history_file.read_text())
    except (OSError, ValueError):
        remembered = []
    known = [p for p in (find_transcript(s) for s in remembered if isinstance(s, str)) if p]
    found = named_sessions(agent, sorted({p.parent for p in known}))
    paths = sorted(set(known) | set(found), key=lambda p: first_timestamp(p, reader))
    written = update_days(days_dir, paths, reader)
    print(f"backfill: {len(paths)} sessions, {len(written)} day files written in {days_dir}")
    for path in paths:
        print(f"  {path.stem} {first_timestamp(path, reader)[:16]}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
