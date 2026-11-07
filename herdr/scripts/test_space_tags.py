"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

from pathlib import Path
import tempfile
import tomllib
import unittest
from unittest.mock import patch

import space_tags


def tab(tab_id):
    return {"tab_id": tab_id, "workspace_id": tab_id.split(":")[0]}


def pane(pane_id, tab_id, cwd):
    return {"pane_id": pane_id, "tab_id": tab_id, "workspace_id": tab_id.split(":")[0], "cwd": cwd}


class SpaceTagTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.root = Path(root.name)
        (self.root / "repo/.git").mkdir(parents=True)
        (self.root / "repo/src").mkdir()
        (self.root / "worktree").mkdir()
        (self.root / "worktree/.git").write_text("gitdir: elsewhere\n")
        (self.root / "plain").mkdir()

    def test_pane_numbers_follow_herdrs_digits(self):
        self.assertEqual(
            [space_tags.pane_number(p) for p in ("w3:p1", "w3:p9", "w3:pA", "w3:p0", "w3:p11")],
            [1, 9, 10, 32, 33],
        )
        self.assertEqual(space_tags.pane_number("w3:pI"), space_tags.sys.maxsize)

    def test_git_repository_is_found_from_any_subfolder(self):
        self.assertTrue(space_tags.in_git_repo(self.root / "repo/src"))
        self.assertTrue(space_tags.in_git_repo(self.root / "worktree"))
        self.assertFalse(space_tags.in_git_repo(self.root / "plain"))

    def test_folder_is_the_first_tabs_first_pane(self):
        tabs = [tab("w3:t3"), tab("w3:t1"), tab("w5:t1")]
        panes = [
            pane("w3:p1", "w3:t1", "/other"),
            pane("w3:pA", "w3:t3", "/later"),
            pane("w3:p7", "w3:t3", "/first"),
            pane("w5:p2", "w5:t1", ""),
            pane("w5:p3", "w5:t1", "/five"),
        ]
        self.assertEqual(space_tags.workspace_folders(tabs, panes), {"w3": "/first", "w5": "/five"})

    def test_only_changed_tags_are_reported(self):
        tabs = [tab(f"w{n}:t1") for n in range(1, 6)]
        panes = [
            pane("w1:p1", "w1:t1", str(self.root / "plain")),
            pane("w2:p1", "w2:t1", str(self.root / "plain")),
            pane("w3:p1", "w3:t1", str(self.root / "repo")),
            pane("w4:p1", "w4:t1", str(self.root / "repo/src")),
        ]
        workspaces = [
            {"workspace_id": "w1"},
            {"workspace_id": "w2", "tokens": {"no_git": "no git"}},
            {"workspace_id": "w3", "tokens": {"no_git": "no git"}},
            {"workspace_id": "w4"},
            {"workspace_id": "w5"},
        ]
        self.assertEqual(list(space_tags.changes(workspaces, tabs, panes)),
                         [("w1", {"no_git": "no git"}), ("w3", {"no_git": None})])

    def test_coordinator_tag_follows_its_tab(self):
        tabs = [tab("w3:t3"), tab("w3:t1"), tab("w5:t1")]
        tabs[0]["label"] = "coordinator"
        panes = [pane("w3:p7", "w3:t3", str(self.root / "repo")),
                 pane("w5:p1", "w5:t1", str(self.root / "repo"))]
        workspaces = [{"workspace_id": "w3"}, {"workspace_id": "w5", "tokens": {"coordinator": "◉"}}]
        with patch.object(space_tags, "coordinator_name", return_value="coordinator"):
            self.assertEqual(list(space_tags.changes(workspaces, tabs, panes)),
                             [("w3", {"coordinator": "◉"}), ("w5", {"coordinator": None})])

    def test_coordinator_tag_uses_the_configured_name(self):
        tabs = [tab("w3:t1"), tab("w5:t1")]
        tabs[0]["label"], tabs[1]["label"] = "coordinator", "hq"
        with patch.object(space_tags, "coordinator_name", return_value="hq"):
            self.assertEqual(list(space_tags.changes([{"workspace_id": "w3"}, {"workspace_id": "w5"}], tabs, [])),
                             [("w5", {"coordinator": "◉"})])

    def test_main_reports_tags_and_prints_nothing(self):
        replies = {
            "workspace.list": {"workspaces": [{"workspace_id": "w1"}, {"workspace_id": "w2"}]},
            "tab.list": {"tabs": [tab("w1:t1"), tab("w2:t1")]},
            "pane.list": {"panes": [pane("w1:p1", "w1:t1", str(self.root / "plain")),
                                    pane("w2:p1", "w2:t1", str(self.root / "repo"))]},
        }
        reports = []

        def call(method, params=None):
            if method == "workspace.report_metadata":
                reports.append(params)
                return {}
            return replies[method]

        with patch.object(space_tags, "call", side_effect=call), \
                patch("sys.stdout") as stdout:
            self.assertEqual(space_tags.main(), 0)
        stdout.write.assert_not_called()
        self.assertEqual(reports, [{"workspace_id": "w1", "source": "donburi-spaces",
                                    "tokens": {"no_git": "no git"}}])

    def test_main_is_quiet_when_herdr_is_down(self):
        with patch.object(space_tags, "call", side_effect=ConnectionRefusedError):
            self.assertEqual(space_tags.main(), 0)

    def test_config_shows_the_tags_and_runs_the_script(self):
        config = tomllib.loads((Path(__file__).parent.parent / "config.toml").read_text())
        tokens = [token for row in config["ui"]["sidebar"]["spaces"]["rows"] for token in row]
        self.assertIn("$" + space_tags.NO_GIT, tokens)
        coordinator = [t for t in tokens if isinstance(t, dict) and t.get("token") == "$" + space_tags.COORDINATOR]
        self.assertEqual(len(coordinator), 1)
        self.assertEqual(coordinator[0]["fg"].upper(), space_tags.COORDINATOR_MARK[1].upper())
        commands = [item.get("command", "") for item in config["ui"]["tab_bar_right"]]
        self.assertTrue(any("scripts/space_tags.py" in command for command in commands))

if __name__ == "__main__":
    unittest.main()
