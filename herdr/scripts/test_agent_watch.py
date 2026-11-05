"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

from pathlib import Path
import tempfile
import unicodedata
import unittest

import agent_watch


def agent(pane, status, kind="claude", title="task", name=None, workspace="w1"):
    return {"pane_id": pane, "agent_status": status, "agent": kind, "name": name,
            "terminal_title_stripped": title, "workspace_id": workspace}


def kinds(events):
    return [(kind, item["pane_id"]) for kind, item in events]


class StepTests(unittest.TestCase):
    def run_steps(self, *snapshots, settle=3, exclude=()):
        """Feed (time, agents) snapshots through step; return the events of each."""
        tracks, out = {}, []
        for index, (now, agents) in enumerate(snapshots):
            tracks, events = agent_watch.step(tracks, agents, now, settle, exclude, announce_new=index > 0)
            out.append(kinds(events))
        return out

    def test_finished_waits_for_settle_and_reports_once(self):
        out = self.run_steps(
            (0, [agent("w1:p1", "working")]),
            (10, [agent("w1:p1", "done")]),
            (12, [agent("w1:p1", "done")]),
            (13, [agent("w1:p1", "done")]),
            (20, [agent("w1:p1", "idle")]),
        )
        self.assertEqual(out, [[], [], [], [("finished", "w1:p1")], []])

    def test_flicker_between_tool_calls_is_not_finished(self):
        out = self.run_steps(
            (0, [agent("w1:p1", "working")]),
            (1, [agent("w1:p1", "idle")]),
            (2, [agent("w1:p1", "working")]),
            (9, [agent("w1:p1", "working")]),
        )
        self.assertEqual(out, [[], [], [], []])

    def test_blocked_reported_immediately_once_per_episode(self):
        out = self.run_steps(
            (0, [agent("w1:p1", "working")]),
            (1, [agent("w1:p1", "blocked")]),
            (2, [agent("w1:p1", "blocked")]),
            (3, [agent("w1:p1", "working")]),
            (4, [agent("w1:p1", "blocked")]),
        )
        self.assertEqual(out, [[], [("blocked", "w1:p1")], [], [], [("blocked", "w1:p1")]])

    def test_already_blocked_agents_reported_on_first_poll(self):
        self.assertEqual(self.run_steps((0, [agent("w1:p1", "blocked"), agent("w2:p1", "done")])),
                         [[("blocked", "w1:p1")]])

    def test_ready_agent_that_never_worked_is_not_finished(self):
        out = self.run_steps((0, [agent("w1:p1", "idle")]), (10, [agent("w1:p1", "idle")]))
        self.assertEqual(out, [[], []])

    def test_started_and_gone_after_first_poll(self):
        out = self.run_steps(
            (0, [agent("w1:p1", "idle")]),
            (1, [agent("w1:p1", "idle"), agent("w2:p1", "working")]),
            (2, [agent("w2:p1", "working")]),
        )
        self.assertEqual(out, [[], [("started", "w2:p1")], [("gone", "w1:p1")]])

    def test_new_agent_kind_in_same_pane_is_gone_then_started(self):
        out = self.run_steps((0, [agent("w1:p1", "idle")]), (1, [agent("w1:p1", "idle", kind="codex")]))
        self.assertEqual(out, [[], [("gone", "w1:p1"), ("started", "w1:p1")]])

    def test_excluded_pane_is_ignored(self):
        out = self.run_steps(
            (0, [agent("w1:p1", "working")]),
            (1, [agent("w1:p1", "blocked")]),
            (9, [agent("w1:p1", "done")]),
            exclude={"w1:p1"},
        )
        self.assertEqual(out, [[], [], []])


class FormatTests(unittest.TestCase):
    def test_describe_uses_name_label_and_title(self):
        item = agent_watch.info(agent("wJ:p2", "blocked", name="api-impl", title="Fix OCR", workspace="wJ"))
        self.assertEqual(agent_watch.describe("blocked", item, {"wJ": "charge-code"}, "13:05:12"),
                         "13:05:12 blocked  api-impl (wJ:p2) claude in charge-code: Fix OCR")

    def test_describe_unnamed_without_title_or_label(self):
        item = agent_watch.info(agent("wJ:p2", "done", title="", workspace="wJ"))
        self.assertEqual(agent_watch.describe("finished", item, {}, "13:05:12"),
                         "13:05:12 finished wJ:p2 claude in wJ")

    def test_summary_counts_statuses(self):
        tracks, _ = agent_watch.step({}, [agent("a", "working"), agent("b", "done"), agent("c", "done")],
                                     0, 3, announce_new=False)
        self.assertEqual(agent_watch.summary(tracks), "watching 3 agents: 1 working, 2 done")


class MarkTests(unittest.TestCase):
    def live(self, pane, terminal, mark=None):
        return {"pane_id": pane, "terminal_id": terminal, "tokens": {"mark": mark} if mark else {}}

    def test_keeps_existing_marks_and_gives_new_agents_the_least_used(self):
        agents = [self.live("w1:p1", "t1", "●"), self.live("w2:p1", "t2"), self.live("w3:p1", "t3")]
        self.assertEqual(agent_watch.assign_marks(agents), {"t1": "●", "t2": "◆", "t3": "■"})

    def test_reuses_marks_evenly_once_all_are_taken(self):
        agents = [self.live(f"w{i}:p1", f"t{i}") for i in range(len(agent_watch.GLYPHS) + 2)]
        marks = list(agent_watch.assign_marks(agents).values())
        self.assertEqual(marks[:len(agent_watch.GLYPHS)], agent_watch.GLYPHS)
        self.assertEqual(marks[-2:], agent_watch.GLYPHS[:2])

    def test_excluded_and_unknown_terminals_get_no_mark(self):
        agents = [self.live("w1:p1", "t1"), {"pane_id": "w2:p1", "tokens": {}}]
        self.assertEqual(agent_watch.assign_marks(agents, exclude={"w1:p1"}), {})

    def test_foreign_token_value_is_replaced(self):
        self.assertEqual(agent_watch.assign_marks([self.live("w1:p1", "t1", "🔵")]), {"t1": "●"})

    def test_feed_line_shows_the_mark(self):
        item = agent_watch.info(dict(agent("wJ:p2", "done", workspace="wJ"), tokens={"mark": "◆"}))
        self.assertEqual(agent_watch.describe("finished", item, {"wJ": "curator"}, "13:05:12"),
                         "13:05:12 finished ◆ wJ:p2 claude in curator: task")

    def test_marks_are_distinct_single_width_glyphs(self):
        self.assertEqual(len(set(agent_watch.GLYPHS)), len(agent_watch.GLYPHS))
        for glyph in agent_watch.GLYPHS:
            self.assertEqual(len(glyph), 1, glyph)
            self.assertNotIn(unicodedata.east_asian_width(glyph), ("W", "F"), glyph)

    def test_sidebar_and_neovim_use_the_same_colors(self):
        herdr = Path(__file__).resolve().parent.parent
        config, lua = (herdr / "config.toml").read_text(), (herdr / "transcript.lua").read_text()
        for glyph, color, _ in [agent_watch.COORDINATOR_MARK, *agent_watch.MARKS]:
            self.assertIn(f'{{ starts_with = "{glyph}", fg = "{color}"', config)
            self.assertIn(f'{{ "{glyph}", "{color}" }}', lua)
        self.assertIn(f'starts_with = "{agent_watch.COORDINATOR_MARK[0]}", fg = "{agent_watch.COORDINATOR_MARK[1]}"',
                      config)

    def test_coordinator_always_gets_its_own_mark(self):
        coordinator = dict(self.live("w9:p1", "t9", "●"), name="coordinator")
        agents = [coordinator, self.live("w1:p1", "t1")]
        marks = agent_watch.assign_marks(agents, exclude={"w9:p1"})
        self.assertEqual(marks, {"t9": "◉", "t1": "●"})
        self.assertNotIn(agent_watch.COORDINATOR_MARK[0], agent_watch.GLYPHS)

    def test_a_worker_never_keeps_the_coordinator_mark(self):
        self.assertEqual(agent_watch.assign_marks([self.live("w1:p1", "t1", "◉")]), {"t1": "●"})

    def test_counts_leave_out_the_coordinator_and_excluded_panes(self):
        agents = [agent("w1:p1", "blocked"), agent("w2:p1", "working"), agent("w3:p1", "working"),
                  agent("w4:p1", "idle", name="coordinator"), agent("w5:p1", "done")]
        self.assertEqual(agent_watch.counts(agents, exclude={"w5:p1"}),
                         {"agents": 3, "blocked": 1, "working": 2})


class StateTests(unittest.TestCase):
    def test_state_round_trip_and_staleness(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nested/agents.json"
            tracks, _ = agent_watch.step({}, [agent("w1:p1", "working")], 100, 3, announce_new=False)
            agent_watch.save_state(path, tracks, 100)
            self.assertEqual(agent_watch.load_state(path, 100 + 60), tracks)
            self.assertIsNone(agent_watch.load_state(path, 100 + agent_watch.STALE_SECONDS + 1))

    def test_missing_or_corrupt_state_is_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "agents.json"
            self.assertIsNone(agent_watch.load_state(path, 0))
            path.write_text("{not json")
            self.assertIsNone(agent_watch.load_state(path, 0))

    def test_restart_reports_what_finished_while_stopped(self):
        tracks, _ = agent_watch.step({}, [agent("w1:p1", "working")], 0, 3, announce_new=False)
        tracks, events = agent_watch.step(tracks, [agent("w1:p1", "done")], 60, 3)
        tracks, events = agent_watch.step(tracks, [agent("w1:p1", "done")], 64, 3)
        self.assertEqual(kinds(events), [("finished", "w1:p1")])


if __name__ == "__main__":
    unittest.main()
