"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

import coordinator_status
import statusline


def plain(text):
    return re.sub(r"\033\[[0-9;]*m", "", text)


class StatusLineTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.root = Path(root.name)
        (self.root / "repo/.git").mkdir(parents=True)
        (self.root / "repo/.git/HEAD").write_text("ref: refs/heads/herdr\n")
        (self.root / "repo/src").mkdir()
        (self.root / "plain").mkdir()

    def data(self, folder, **extra):
        return {"workspace": {"current_dir": str(folder)}, "model": {"display_name": "Opus 5.5"},
                "context_window": {"used_percentage": 41.6}, **extra}

    def test_worker_line(self):
        agent = {"pane_id": "w5:p2", "name": "api-impl", "agent": "claude", "tokens": {"mark": "▲"}}
        line = statusline.status_line(self.data(self.root / "repo/src", vim={"mode": "NORMAL"}), agent)
        self.assertEqual(plain(line), "NORMAL  ▲ api-impl  src/herdr  Opus 5.5  42%")
        self.assertIn(statusline.color("#D27E99") + "▲", line)  # the marker in its own color

    def test_outside_herdr_and_git_without_vim(self):
        self.assertEqual(plain(statusline.status_line(self.data(self.root / "plain"))), "plain  Opus 5.5  42%")

    def test_unnamed_agent_shows_its_harness(self):
        self.assertEqual(plain(statusline.agent_part({"agent": "claude", "tokens": None})), "claude")

    def test_branch_from_a_worktree_and_detached_head(self):
        (self.root / "wt").mkdir()
        (self.root / "wt/.git").write_text("gitdir: ../repo/.git\n")
        self.assertEqual(statusline.branch(self.root / "wt"), "herdr")
        (self.root / "repo/.git/HEAD").write_text("0123abcd\n")
        self.assertEqual(statusline.branch(self.root / "repo"), "")
        self.assertEqual(statusline.branch(self.root / "plain"), "")

    def test_worker_line_is_not_the_coordinator_banner(self):
        line = statusline.status_line(self.data(self.root / "repo", vim={"mode": "INSERT"}))
        self.assertNotIn("COORDINATOR", line)
        self.assertNotIn(coordinator_status.TITLE, line)

    def test_herdr_agent_lookup(self):
        agents = {"agents": [{"pane_id": "w1:p1"}, {"pane_id": "w5:p2", "name": "x"}]}
        with patch.object(statusline.agent_watch, "call", return_value=agents):
            self.assertEqual(statusline.herdr_agent("w5:p2")["name"], "x")
        self.assertIsNone(statusline.herdr_agent(None))
        with patch.object(statusline.agent_watch, "call", side_effect=ConnectionRefusedError):
            self.assertIsNone(statusline.herdr_agent("w5:p2"))


if __name__ == "__main__":
    unittest.main()
