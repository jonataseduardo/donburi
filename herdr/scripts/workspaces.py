"""Search-first Herdr workspace popup; uses Python's stdlib, fzf and optional zoxide."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


FOLDER_CACHE_SECONDS = 300


def storage_path(kind):
    if kind == "cache":
        base = os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))
        filename = "folders.json"
    else:
        base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))
        filename = "usage.json"
    return Path(base) / "herdr/workspace-picker" / filename


def read_json(path):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def write_json(path, value):
    temporary = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as file:
            temporary = Path(file.name)
            json.dump(value, file)
        temporary.replace(path)
    except OSError:
        # An unwritable cache/history must not prevent switching workspaces.
        pass
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass


def usage_key(entry):
    # Share folder history with its workspace; keep it across server restarts.
    return str(entry["path"]) if entry.get("path") else "workspace:" + entry.get("label", entry.get("id", ""))


def usage_stats(history, entry):
    value = history.get(usage_key(entry), {})
    if not isinstance(value, dict):
        return 0, 0
    count, last = value.get("count", 0), value.get("last", 0)
    if not isinstance(count, int) or not isinstance(last, (int, float)):
        return 0, 0
    return count, last


def record_usage(entry):
    path = storage_path("state")
    history = read_json(path)
    count, _ = usage_stats(history, entry)
    history[usage_key(entry)] = {"count": count + 1, "last": time.time()}
    write_json(path, history)


def rank_entries(entries):
    history = read_json(storage_path("state"))
    for entry in entries:
        entry["uses"], entry["last_used"] = usage_stats(history, entry)
    # Stable sort preserves discovery/zoxide ordering for entries with no history.
    return sorted(entries, key=lambda e: (e["kind"] != "Workspace", -e["uses"], -e["last_used"]))


def directory(value):
    return Path(os.path.expandvars(str(value))).expanduser().resolve()


def display(value):
    # Keep filenames from injecting terminal controls or fzf row delimiters.
    return "".join(c if c.isprintable() else "?" for c in str(value))


def api(*args):
    result = subprocess.run(
        [os.environ.get("HERDR_BIN_PATH", "herdr"), *args],
        capture_output=True, text=True, timeout=15,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Herdr command failed")
    return json.loads(result.stdout)["result"]


def workspace_entries():
    workspaces = api("workspace", "list")["workspaces"]
    panes = api("pane", "list")["panes"]
    entries = []
    for workspace in workspaces:
        matching = [p for p in panes if p["workspace_id"] == workspace["workspace_id"]]
        matching.sort(key=lambda p: not p.get("focused", False))
        paths = []
        for pane in matching:
            cwd = pane.get("foreground_cwd") or pane.get("cwd")
            if cwd and directory(cwd) not in paths:
                paths.append(directory(cwd))
        path = paths[0] if paths else None
        entries.append({"kind": "Workspace", "label": workspace["label"],
                        "path": path, "paths": paths, "id": workspace["workspace_id"]})
    return entries


def folder_entry(path):
    return {"kind": "Folder", "label": path.name or str(path), "path": path}


def project_folders(root, depth=0):
    # Include common layouts such as ~/ia/project without scanning caches,
    # dependencies or arbitrarily deep directory trees on every popup launch.
    excluded = {"Library", "node_modules", "vendor", "target", "__pycache__"}
    if depth >= 3:
        return
    try:
        with os.scandir(root) as children:
            folders = sorted((child for child in children
                              if not child.name.startswith(".") and child.name not in excluded
                              and child.is_dir()), key=lambda e: e.name.casefold())
    except OSError:
        return
    for child in folders:
        path = Path(child.path)
        yield path
        if not child.is_symlink():
            yield from project_folders(path, depth + 1)


def cached_folders(refresh=False):
    roots = [str(directory(root)) for root in
             os.environ.get("HERDR_PROJECT_ROOTS", str(Path.home())).split(os.pathsep) if root]
    path = storage_path("cache")
    cache = read_json(path)
    generated = cache.get("generated", 0)
    folders = cache.get("folders")
    if (not refresh and cache.get("roots") == roots
            and isinstance(generated, (int, float)) and 0 <= time.time() - generated < FOLDER_CACHE_SECONDS
            and isinstance(folders, list) and all(isinstance(folder, str) for folder in folders)):
        return [Path(folder) for folder in folders]
    folders = []
    for root in map(Path, roots):
        if root.is_dir():
            folders.append(root)
            folders.extend(directory(folder) for folder in project_folders(root))
    folders = list(dict.fromkeys(folders))
    write_json(path, {"roots": roots, "generated": time.time(), "folders": list(map(str, folders))})
    return folders


def search_entries(current, refresh=False):
    entries = workspace_entries()
    seen = {p for entry in entries for p in entry["paths"]}

    def add(path, cached=False):
        path = Path(path) if cached else directory(path)
        if path not in seen and (cached or path.is_dir()):
            entries.append(folder_entry(path))
            seen.add(path)

    add(current)
    if shutil.which("zoxide"):
        recent = subprocess.run(["zoxide", "query", "--list"], capture_output=True,
                                text=True, timeout=5)
        for path in recent.stdout.splitlines()[:100]:
            add(path)
    for path in cached_folders(refresh):
        add(path, cached=True)
    add(Path.home())
    return rank_entries(entries)


def choose(entries):
    rows = [f"{i}\t{display(e['kind']):10}  {display(e['label'])}  {display(e.get('path') or '')}"
            + (f"  [{e['uses']} uses]" if e.get("uses") else "")
            for i, e in enumerate(entries)]
    env = dict(os.environ, FZF_DEFAULT_OPTS="", FZF_DEFAULT_OPTS_FILE="")
    result = subprocess.run(
        ["fzf", "--read0", "--print0", "--layout=reverse", "--no-sort", "--expect=ctrl-r",
         "--delimiter=\t", "--with-nth=2..", "--border",
         "--prompt", "Find workspace / folder > ",
         "--header", "Open workspaces first · Most used first in each group\nEnter switch/open · Ctrl+r refresh folders · Esc cancel",
         "--bind=enter:accept-non-empty,esc:abort",
         "--color=bg:#1F1F28,fg:#DCD7BA,hl:#FF9E64,pointer:#FF9E64"],
        input="\0".join(rows) + "\0", capture_output=True, text=True, env=env,
    )
    if result.returncode in (0, 1) and result.stdout.split("\0", 1)[0] == "ctrl-r":
        return {"kind": "Refresh"}
    if result.returncode in (1, 130):
        return None
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "fzf failed")
    return entries[int(result.stdout.split("\0", 1)[1].split("\t", 1)[0])]


def open_folder(path):
    if not path.is_dir():
        raise ValueError(f"Directory does not exist: {path}")
    # Refresh before mutation: the user may have opened another workspace meanwhile.
    for entry in workspace_entries():
        if path in entry["paths"]:
            api("workspace", "focus", entry["id"])
            return
    api("workspace", "create", "--label", path.name or str(path), "--cwd", str(path), "--focus")


def main():
    if not shutil.which("fzf"):
        raise RuntimeError("fzf is required: brew install fzf")
    current = directory(os.environ.get("HERDR_ACTIVE_PANE_CWD", os.getcwd()))
    refresh = False
    while True:
        try:
            entry = choose(search_entries(current, refresh=refresh))
            refresh = False
            if entry is None:
                return
            if entry["kind"] == "Refresh":
                refresh = True
                continue
            if entry["kind"] == "Workspace":
                api("workspace", "focus", entry["id"])
            else:
                open_folder(entry["path"])
            record_usage(entry)
            return
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
            print(f"\n{display(error)}", flush=True)
            input("Press Enter to return to search…")


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        pass
    except Exception as error:
        print(display(error), file=sys.stderr)
        sys.exit(1)
