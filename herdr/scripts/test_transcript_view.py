"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'.

Drives herdr/transcript.lua in a headless Neovim (skipped when nvim is missing).
"""

from datetime import date, timedelta
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

LUA = Path(__file__).resolve().parent.parent / "transcript.lua"
NVIM = shutil.which("nvim") or ""

HISTORY = """# 2026-11-05 07:18 · Start
## 07:18 · you

how is w5:p2 doing? not w5:p23

## 07:18 · claude

- ▸ Bash `herdr agent read w5:p2 --source recent-unwrapped`

▲ w5:p2 (donburi) is idle.

### 07:19 · feed

```text
07:19:01 finished ▲ w5:p2 claude in donburi: Commit
07:19:02 blocked  ◆ api-impl (wJ:p2) codex in curator: Approve edit
```

### 07:20 · task

```text
07:20:00 Background command "tests" completed
```

## 07:21 · claude

```sh
12:00:00 not a feed line, inside a reply's code block
```

### 07:22 · feed

```text
07:22:05 finished ◆ api-impl (wJ:p2) codex in curator: Approve edit
```

## 07:23 · you

ask api-impl to rebase in donburi
"""

# Line numbers (1-based) of the feed events in HISTORY.
EVENTS = [15, 16, 34]


class TranscriptViewTests(unittest.TestCase):
    def setUp(self):
        if not NVIM:
            self.skipTest("nvim is required")
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.view = Path(directory.name) / "view.md"
        self.view.write_text(HISTORY)
        self.assertEqual([i + 1 for i, line in enumerate(HISTORY.splitlines())
                          if line[:2].isdigit() and line[8:9] == " " and "not a feed" not in line
                          and "Background" not in line], EVENTS)

    def run_view(self, lua, herdr="true"):
        """Load the view, run `lua` (which sets `result`), return result as JSON."""
        script = f"local result\n{lua}\nio.stdout:write(vim.json.encode(result))"
        env = {**os.environ, "HERDR_TRANSCRIPT_AGENT": "w9:p9", "HERDR_BIN_PATH": herdr}
        out = subprocess.run(
            [NVIM, "--headless", "-n", "-R", "-u", "NONE", "-c", f"luafile {LUA}",
             "-c", f"lua {script}", "-c", "qa!", str(self.view)],
            env=env, capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout.strip().splitlines()[-1])

    def test_event_navigation_visits_only_feed_events(self):
        lines = self.run_view("""
result = {}
vim.cmd("normal! gg")
for _ = 1, 4 do vim.cmd("normal ]e"); table.insert(result, vim.fn.line(".")) end
for _ = 1, 4 do vim.cmd("normal [e"); table.insert(result, vim.fn.line(".")) end
""")
        self.assertEqual(lines, EVENTS + [EVENTS[-1]] + [EVENTS[1], EVENTS[0], EVENTS[0], EVENTS[0]])

    def test_event_navigation_takes_a_count(self):
        self.assertEqual(self.run_view('vim.cmd("normal! gg"); vim.cmd("normal 2]e"); result = vim.fn.line(".")'),
                         EVENTS[1])

    def test_agent_command_lists_lines_naming_a_pane(self):
        result = self.run_view("""
vim.cmd("HerdrAgent w5:p2")
local list = vim.fn.getloclist(vim.fn.win_getid(vim.fn.winnr("#")), { title = 1, items = 1 })
result = { title = list.title, lines = vim.tbl_map(function(i) return i.lnum end, list.items) }
""")
        self.assertEqual(result, {"title": "herdr: w5:p2", "lines": [4, 8, 10, 15]})

    def test_agent_command_finds_named_agents_and_defaults_to_the_line(self):
        result = self.run_view(f"""
vim.cmd("HerdrAgent api-impl")
local named = vim.tbl_map(function(i) return i.lnum end, vim.fn.getloclist(vim.fn.win_getid(vim.fn.winnr("#"))))
vim.cmd("lclose")
vim.api.nvim_win_set_cursor(0, {{ {EVENTS[1]}, 0 }})
vim.cmd("HerdrAgent")
result = {{ named = named, title = vim.fn.getloclist(vim.fn.win_getid(vim.fn.winnr("#")), {{ title = 1 }}).title }}
""")
        self.assertEqual(result, {"named": [16, 34, 39], "title": "herdr: wJ:p2"})

    def test_agent_command_completes_targets(self):
        targets = self.run_view('result = vim.fn.getcompletion("HerdrAgent ", "cmdline")')
        self.assertEqual(targets, ["api-impl", "w5:p2", "w5:p23", "wJ:p2"])

    def test_location_list_window_colors_markers(self):
        groups = self.run_view("""
vim.cmd("HerdrAgent w5:p2")
result = vim.tbl_map(function(m) return m.group end, vim.fn.getmatches())
""")
        self.assertIn("HerdrMark5", groups)  # ▲, the fifth entry in the marks table

    def tags(self):
        """{heading line: [[tag, highlight], ...]} from the section extmarks."""
        return {int(k): v for k, v in self.run_view("""
result = {}
local ns = vim.api.nvim_get_namespaces().herdr_sections
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
  if m[4].virt_text then
    local tags = {}
    for _, chunk in ipairs(m[4].virt_text) do
      if chunk[1]:match("^%[") then table.insert(tags, chunk) end
    end
    result[tostring(m[2] + 1)] = tags
  end
end
""").items()}

    def test_sections_are_tagged_with_the_agents_they_name(self):
        self.assertEqual(self.tags(), {
            # A pane named before its marker appears gets the marker seen later;
            # w5:p23 has no marker or name anywhere, so it stays plain.
            2: [["[▲ w5:p2 donburi]", "HerdrMark5"], ["[w5:p23]", "HerdrTag"]],
            6: [["[▲ w5:p2 donburi]", "HerdrMark5"]],
            12: [["[▲ w5:p2 donburi]", "HerdrMark5"], ["[◆ wJ:p2 api-impl]", "HerdrMark3"]],
            31: [["[◆ wJ:p2 api-impl]", "HerdrMark3"]],
            # A known agent name counts; a workspace name ("donburi") does not.
            37: [["[◆ wJ:p2 api-impl]", "HerdrMark3"]],
        })

    def test_section_lines_get_a_bar_in_the_agent_color(self):
        signs = {int(k): v for k, v in self.run_view("""
result = {}
local ns = vim.api.nvim_get_namespaces().herdr_sections
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
  if m[4].sign_text then result[tostring(m[2] + 1)] = m[4].sign_hl_group end
end
""").items()}
        self.assertEqual(signs[10], "HerdrMark5")  # the claude turn about ▲ w5:p2
        self.assertEqual(signs[15], "HerdrMark5")  # each feed event in its own agent's color
        self.assertEqual(signs[16], "HerdrMark3")
        self.assertNotIn(22, signs)                 # the task block names no agent
        self.assertNotIn(28, signs)

    def test_tag_command_lists_sections_for_an_agent(self):
        result = self.run_view("""
local out = {}
for _, arg in ipairs({ "api-impl", "w5:p2", "[▲ w5:p2 donburi]" }) do
  vim.cmd("HerdrTag " .. arg)
  local list = vim.fn.getloclist(vim.fn.win_getid(vim.fn.winnr("#")), { title = 1, items = 1 })
  out[arg] = { title = list.title, lines = vim.tbl_map(function(i) return i.lnum end, list.items),
               first = list.items[1].text }
  vim.cmd("lclose")
end
result = out
""")
        self.assertEqual(result["api-impl"]["lines"], [12, 31, 37])
        self.assertEqual(result["w5:p2"]["lines"], [2, 6, 12])
        self.assertEqual(result["[▲ w5:p2 donburi]"]["lines"], [2, 6, 12])
        self.assertEqual(result["w5:p2"]["first"], "[▲ w5:p2 donburi] ## 07:18 · you")
        self.assertEqual(result["api-impl"]["title"], "herdr tag: api-impl")

    def test_tag_command_completes_tags(self):
        self.assertEqual(self.run_view('result = vim.fn.getcompletion("HerdrTag ", "cmdline")'),
                         ["api-impl", "donburi", "w5:p2", "w5:p23", "wJ:p2"])

    def test_a_pane_never_written_with_a_marker_takes_its_live_one(self):
        fake = self.view.parent / "herdr"
        fake.write_text("#!/bin/sh\n[ \"$1 $2\" = \"agent list\" ] && "
                        "echo '{\"result\":{\"agents\":[{\"pane_id\":\"w5:p23\",\"tokens\":{\"mark\":\"✦\"}},"
                        "{\"pane_id\":\"w5:p2\",\"tokens\":{\"mark\":\"●\"}},{\"pane_id\":\"wX:p1\",\"tokens\":null}]}}'\n")
        fake.chmod(0o755)
        tags = self.run_view("""
local ns = vim.api.nvim_get_namespaces().herdr_sections
local function heading_tags()
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, { 1, 0 }, { 1, -1 }, { details = true })) do
    if m[4].virt_text then return m[4].virt_text end
  end
end
vim.wait(3000, function()
  local tags = heading_tags()
  return tags and vim.iter(tags):any(function(c) return c[1]:find("✦", 1, true) end)
end)
result = vim.tbl_filter(function(c) return c[1]:match("^%[") end, heading_tags())
""", herdr=str(fake))
        # The text's own ▲ wins over the live ●; w5:p23 has no marker in the text.
        self.assertEqual(tags, [["[▲ w5:p2 donburi]", "HerdrMark5"], ["[✦ w5:p23]", "HerdrMark9"]])

    def test_markdown_text_is_unchanged(self):
        self.assertEqual(self.run_view('result = vim.api.nvim_buf_get_lines(0, 0, -1, false)'),
                         HISTORY.splitlines())

    def test_turn_navigation_still_works(self):
        self.assertEqual(self.run_view('vim.cmd("normal! gg"); vim.cmd("normal ]]"); result = vim.fn.line(".")'), 2)

    def test_day_keys_need_a_days_directory(self):
        # Neovim's own [d / ]d (diagnostics) stay; no buffer-local day keys.
        self.assertEqual(self.run_view("""
local function local_map(key) return vim.fn.maparg(key, "n", false, true).buffer or 0 end
result = { local_map("[d"), local_map("]d"), vim.fn.exists(":HerdrDay") }
"""), [0, 0, 0])


TODAY = date.today()
D1, D2 = (TODAY - timedelta(days=1)).isoformat(), (TODAY - timedelta(days=2)).isoformat()

# Two archived days, as transcript.py --days writes them; today's file mirrors
# the live view.
DAY2 = f"""# {D2} 09:00 · Old work
## 09:00 · you

check w5:p2

### 09:01 · feed

```text
09:01:00 finished ▲ w5:p2 claude in donburi: Old commit
```
"""

DAY1 = f"""# {D1} 10:00 · Yesterday
## 10:00 · claude

nothing to report

### 10:01 · feed

```text
10:01:00 blocked  ◆ api-impl (wJ:p2) codex in curator: Approve
10:01:30 finished ◆ api-impl (wJ:p2) codex in curator: Rebased
```
"""

INDEX = f"""# History by day

| Day | Sessions | Turns | Feed events | Agents |
|-----|----------|-------|-------------|--------|
| [{TODAY.isoformat()}]({TODAY.isoformat()}.md) | 1 | 4 | 3 | w5:p2 donburi, wJ:p2 api-impl |
| [{D1}]({D1}.md) | 1 | 1 | 2 | wJ:p2 api-impl |
| [{D2}]({D2}.md) | 1 | 1 | 1 | w5:p2 donburi |
"""


class DayViewTests(unittest.TestCase):
    """The coordinator's history split by day (HERDR_TRANSCRIPT_DAYS)."""

    def setUp(self):
        if not NVIM:
            self.skipTest("nvim is required")
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        self.view = root / "coordinator.md"
        self.view.write_text(HISTORY)
        self.days = root / "days"
        self.days.mkdir()
        for name, text in [(D2, DAY2), (D1, DAY1), (TODAY.isoformat(), HISTORY), ("index", INDEX)]:
            (self.days / f"{name}.md").write_text(text)
        self.socket = root / "no.sock"

    def run_view(self, lua, agent="w9:p9"):
        script = f"local result\n{lua}\nio.stdout:write(vim.json.encode(result))"
        env = {**os.environ, "HERDR_TRANSCRIPT_AGENT": agent, "HERDR_BIN_PATH": "true",
               "HERDR_TRANSCRIPT_DAYS": str(self.days), "HERDR_SOCKET_PATH": str(self.socket)}
        out = subprocess.run(
            [NVIM, "--headless", "-n", "-R", "-u", "NONE", "-c", f"luafile {LUA}",
             "-c", f"lua {script}", "-c", "qa!", str(self.view)],
            env=env, capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout.strip().splitlines()[-1])

    # Where the history window is: the day shown (nil = live view) and the file.
    WHERE = """local function where()
  return { day = vim.b.herdr_day or "live", file = vim.fn.expand("%:t"), line = vim.fn.line(".") }
end"""

    def test_day_keys_step_through_the_days_and_back_to_the_live_view(self):
        steps = self.run_view(self.WHERE + """
result = { where() }
for _, key in ipairs({ "[d", "[d", "[d", "]d", "]d", "]d" }) do
  vim.cmd("normal " .. key)
  table.insert(result, where())
end
""")
        live = {"day": "live", "file": "coordinator.md", "line": len(HISTORY.splitlines())}
        self.assertEqual([(s["day"], s["file"]) for s in steps], [
            ("live", "coordinator.md"),
            (D1, f"{D1}.md"), (D2, f"{D2}.md"),
            (D2, f"{D2}.md"),               # no earlier day: stays
            (D1, f"{D1}.md"),
            ("live", "coordinator.md"),     # today's file is the live view
            ("live", "coordinator.md"),
        ])
        self.assertEqual(steps[0], live)
        self.assertEqual(steps[-1], live)   # back at the end, still following

    def test_a_day_gets_the_same_view(self):
        result = self.run_view("""
vim.cmd("normal [d")
local buf, ns = vim.api.nvim_get_current_buf(), vim.api.nvim_get_namespaces().herdr_sections
local tags = {}
for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
  if m[4].virt_text then tags[tostring(m[2] + 1)] = m[4].virt_text[1] end
end
vim.cmd("normal! gg")
vim.cmd("normal 2]e")
result = { tags = tags, event = vim.fn.line("."), readonly = vim.bo.readonly, modifiable = vim.bo.modifiable,
           filetype = vim.bo.filetype, prompt = vim.fn.maparg("i", "n") ~= "", agent = vim.fn.exists(":HerdrAgent") }
""")
        # The first turn names no agent; the feed block names api-impl.
        self.assertEqual(result["tags"], {"6": ["[◆ wJ:p2 api-impl]", "HerdrMark3"]})
        self.assertEqual(result["event"], 10)
        self.assertEqual([result[k] for k in ("readonly", "modifiable", "filetype", "prompt", "agent")],
                         [True, False, "markdown", True, 2])

    def test_day_command_opens_a_day_and_completes_from_the_index(self):
        result = self.run_view(self.WHERE + f"""
local out = {{ complete = vim.fn.getcompletion("HerdrDay ", "cmdline") }}
vim.cmd("HerdrDay {D2}"); out.d2 = where()
vim.cmd("HerdrDay 1999-01-01"); out.missing = where()
vim.cmd("HerdrDay"); out.live = where()
vim.cmd("HerdrDay {D1}"); vim.cmd("HerdrDay today"); out.today = where()
result = out
""")
        self.assertEqual(result["complete"], [TODAY.isoformat(), D1, D2])  # newest first
        self.assertEqual(result["d2"]["day"], D2)
        self.assertEqual(result["missing"]["day"], D2)  # no such day: stays
        self.assertEqual(result["live"]["file"], "coordinator.md")
        self.assertEqual(result["today"]["file"], "coordinator.md")

    def test_bang_searches_every_day_file(self):
        result = self.run_view("""
local out = {}
for _, cmd in ipairs({ "HerdrTag! api-impl", "HerdrAgent! w5:p2", "HerdrTag api-impl" }) do
  vim.cmd(cmd)
  local list = vim.fn.getloclist(vim.fn.win_getid(vim.fn.winnr("#")), { title = 1, items = 1 })
  out[cmd] = { title = list.title, items = vim.tbl_map(function(i)
    return { vim.fn.fnamemodify(vim.fn.bufname(i.bufnr), ":t"), i.lnum, i.text:match("^%[[^]]*%]") }
  end, list.items) }
  vim.cmd("lclose")
end
result = out
""")
        today = f"{TODAY.isoformat()}.md"
        tag = "[◆ wJ:p2 api-impl]"
        self.assertEqual(result["HerdrTag! api-impl"]["title"], "herdr tag (all days): api-impl")
        self.assertEqual(result["HerdrTag! api-impl"]["items"], [
            [f"{D1}.md", 6, tag],
            [today, 12, tag], [today, 31, tag], [today, 37, tag],
        ])
        self.assertEqual(result["HerdrAgent! w5:p2"]["title"], "herdr (all days): w5:p2")
        self.assertEqual(result["HerdrAgent! w5:p2"]["items"], [  # (lines carry no tag)
            [f"{D2}.md", 4], [f"{D2}.md", 9], [today, 4], [today, 8], [today, 10], [today, 15],
        ])
        # Without !, only the buffer on screen (the live view).
        self.assertEqual([i[:2] for i in result["HerdrTag api-impl"]["items"]],
                         [["coordinator.md", 12], ["coordinator.md", 31], ["coordinator.md", 37]])

    def test_a_location_list_entry_opens_its_day_in_the_view(self):
        result = self.run_view(self.WHERE + """
vim.cmd("HerdrTag! api-impl")
vim.cmd("ll 1")
local tags = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().herdr_sections, 0, -1, {})
result = { where = where(), tagged = #tags > 0, signcolumn = vim.wo.signcolumn }
""")
        self.assertEqual(result, {"where": {"day": D1, "file": f"{D1}.md", "line": 6}, "tagged": True,
                                  "signcolumn": "yes"})

    def test_only_the_live_view_reloads_and_a_day_keeps_its_cursor(self):
        result = self.run_view(self.WHERE + """
local live = vim.api.nvim_get_current_buf()
vim.cmd("normal [d")
local day = vim.api.nvim_get_current_buf()
local reloads = vim.tbl_map(function(a) return a.buffer end,
  vim.api.nvim_get_autocmds({ group = "herdr_transcript", event = "FileChangedShell" }))
vim.cmd("normal! gg")
-- The renderer appends to the live file while a day is shown.
local lines = vim.fn.readfile(vim.api.nvim_buf_get_name(live))
vim.list_extend(lines, { "", "## 07:30 · claude", "", "done" })
vim.fn.writefile(lines, vim.api.nvim_buf_get_name(live))
vim.cmd("checktime")
local day_view = where()
vim.cmd("normal ]d")
result = { reloads = reloads, live = live, day = day, day_view = day_view, back = where(),
           live_lines = vim.api.nvim_buf_line_count(live) }
""")
        self.assertEqual(result["reloads"], [result["live"]])
        self.assertEqual(result["day_view"], {"day": D1, "file": f"{D1}.md", "line": 1})
        self.assertEqual(result["live_lines"], len(HISTORY.splitlines()) + 4)
        self.assertEqual(result["back"]["line"], result["live_lines"])  # followed the new turn

    def test_coordinator_banner_names_the_day_shown(self):
        result = self.run_view("""
local bars = { vim.wo.winbar }
vim.cmd("normal [d"); table.insert(bars, vim.wo.winbar)
vim.cmd("normal ]d"); table.insert(bars, vim.wo.winbar)
result = bars
""", agent="coordinator")
        self.assertNotIn(D1, result[0])
        self.assertIn(D1, result[1])
        self.assertNotIn(D1, result[2])


if __name__ == "__main__":
    unittest.main()
