"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch

import workspaces


class WorkspaceSearchTests(unittest.TestCase):
    def setUp(self):
        storage = tempfile.TemporaryDirectory()
        self.addCleanup(storage.cleanup)
        env = patch.dict(workspaces.os.environ, {
            "XDG_CACHE_HOME": storage.name + "/cache",
            "XDG_STATE_HOME": storage.name + "/state",
        })
        env.start()
        self.addCleanup(env.stop)

    def test_picker_returns_selected_folder(self):
        entries = [workspaces.folder_entry(Path("/tmp/one")),
                   workspaces.folder_entry(Path("/tmp/folder with spaces"))]
        result = subprocess.CompletedProcess([], 0, "\0" + "1\tFolder folder with spaces\0", "")
        with patch.object(workspaces.subprocess, "run", return_value=result):
            self.assertEqual(workspaces.choose(entries), entries[1])

    def test_cancel_does_not_call_herdr(self):
        with patch.object(workspaces, "search_entries", return_value=[]), \
                patch.object(workspaces, "choose", return_value=None), \
                patch.object(workspaces.shutil, "which", return_value="fzf"), \
                patch.object(workspaces, "api") as api, \
                patch.object(workspaces, "record_usage") as record:
            workspaces.main()
            api.assert_not_called()
            record.assert_not_called()

    def test_main_selection_switches_workspace_or_opens_folder(self):
        for entry in [{"kind": "Workspace", "id": "w7"},
                      workspaces.folder_entry(Path("/tmp/project"))]:
            with self.subTest(kind=entry["kind"]), \
                    patch.object(workspaces, "search_entries", return_value=[entry]), \
                    patch.object(workspaces, "choose", return_value=entry), \
                    patch.object(workspaces.shutil, "which", return_value="fzf"), \
                    patch.object(workspaces, "api") as api, \
                    patch.object(workspaces, "open_folder") as open_folder, \
                    patch.object(workspaces, "record_usage") as record:
                workspaces.main()
                record.assert_called_once_with(entry)
                if entry["kind"] == "Workspace":
                    api.assert_called_once_with("workspace", "focus", "w7")
                    open_folder.assert_not_called()
                else:
                    open_folder.assert_called_once_with(entry["path"])
                    api.assert_not_called()

    def test_pane_paths_are_canonical_and_focused_first(self):
        responses = [
            {"workspaces": [{"workspace_id": "w7", "label": "project"}]},
            {"panes": [
                {"workspace_id": "w7", "cwd": "/tmp/other"},
                {"workspace_id": "w7", "cwd": "/tmp/project/../project", "focused": True},
            ]},
        ]
        with patch.object(workspaces, "api", side_effect=responses):
            entry = workspaces.workspace_entries()[0]
        self.assertEqual(entry["path"], Path("/tmp/project").resolve())
        self.assertEqual(len(entry["paths"]), 2)

    def test_existing_pane_directory_focuses_workspace(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root).resolve()
            with patch.object(workspaces, "workspace_entries", return_value=[
                {"id": "w7", "paths": [path]}
            ]), patch.object(workspaces, "api") as api:
                workspaces.open_folder(path)
            api.assert_called_once_with("workspace", "focus", "w7")

    def test_new_workspace_preserves_spaces_in_path(self):
        with tempfile.TemporaryDirectory(prefix="workspace space ") as root:
            path = Path(root).resolve()
            with patch.object(workspaces, "workspace_entries", return_value=[]), \
                    patch.object(workspaces, "api") as api:
                workspaces.open_folder(path)
            api.assert_called_once_with("workspace", "create", "--label", path.name,
                                        "--cwd", str(path), "--focus")

    def test_root_discovery_includes_nested_projects_and_deduplicates(self):
        with tempfile.TemporaryDirectory() as root:
            parent = Path(root).resolve()
            project = parent / "project"
            (project / "nested").mkdir(parents=True)
            with patch.dict(workspaces.os.environ, {"HERDR_PROJECT_ROOTS": str(parent)}), \
                    patch.object(workspaces, "workspace_entries", return_value=[]), \
                    patch.object(workspaces.shutil, "which", return_value=None):
                entries = workspaces.search_entries(project)
            paths = [entry["path"] for entry in entries]
            self.assertEqual(paths.count(project), 1)
            self.assertIn(project / "nested", paths)

    def test_home_is_default_root_and_dependencies_are_skipped(self):
        with tempfile.TemporaryDirectory() as root:
            home = Path(root).resolve()
            project = home / "ia" / "charge-code-curator"
            project.mkdir(parents=True)
            (project / "node_modules" / "dependency").mkdir(parents=True)
            (home / "Library" / "cache").mkdir(parents=True)
            (home / ".cache").mkdir()
            env = {k: v for k, v in workspaces.os.environ.items() if k != "HERDR_PROJECT_ROOTS"}
            with patch.dict(workspaces.os.environ, env, clear=True), \
                    patch.object(workspaces.Path, "home", return_value=home), \
                    patch.object(workspaces, "workspace_entries", return_value=[]), \
                    patch.object(workspaces.shutil, "which", return_value=None):
                entries = workspaces.search_entries(home)
            paths = [entry["path"] for entry in entries]
            self.assertIn(project, paths)
            self.assertNotIn(project / "node_modules", paths)
            self.assertNotIn(home / "Library", paths)
            self.assertNotIn(home / ".cache", paths)

    def test_control_characters_are_not_rendered(self):
        self.assertEqual(workspaces.display("folder\n\x1b[31m"), "folder??[31m")

    def test_cache_avoids_rescanning_and_refresh_discovers_new_folder(self):
        with tempfile.TemporaryDirectory() as root:
            home = Path(root).resolve()
            original = home / "original"
            original.mkdir()
            with patch.dict(workspaces.os.environ, {"HERDR_PROJECT_ROOTS": str(home)}):
                first = workspaces.cached_folders()
                new = home / "new"
                new.mkdir()
                with patch.object(workspaces, "project_folders", side_effect=AssertionError("rescanned")):
                    self.assertEqual(workspaces.cached_folders(), first)
                self.assertIn(new, workspaces.cached_folders(refresh=True))

    def test_expired_or_changed_root_cache_is_rebuilt(self):
        with tempfile.TemporaryDirectory() as root:
            home = Path(root).resolve()
            (home / "project").mkdir()
            with patch.dict(workspaces.os.environ, {"HERDR_PROJECT_ROOTS": str(home)}), \
                    patch.object(workspaces.time, "time", return_value=1000):
                workspaces.cached_folders()
            (home / "new").mkdir()
            with patch.dict(workspaces.os.environ, {"HERDR_PROJECT_ROOTS": str(home)}), \
                    patch.object(workspaces.time, "time", return_value=1301):
                self.assertIn(home / "new", workspaces.cached_folders())
            with patch.dict(workspaces.os.environ, {"HERDR_PROJECT_ROOTS": str(home / "project")}):
                self.assertEqual(workspaces.cached_folders(), [home / "project"])

    def test_workspaces_always_first_then_frequency_and_recency(self):
        workspace = {"kind": "Workspace", "label": "open", "id": "w7", "path": Path("/tmp/open")}
        frequent = workspaces.folder_entry(Path("/tmp/frequent"))
        recent = workspaces.folder_entry(Path("/tmp/recent"))
        older = workspaces.folder_entry(Path("/tmp/older"))
        with patch.object(workspaces.time, "time", return_value=1000):
            workspaces.record_usage(older)
            workspaces.record_usage(frequent)
            workspaces.record_usage(frequent)
        with patch.object(workspaces.time, "time", return_value=1001):
            workspaces.record_usage(recent)
        ranked = workspaces.rank_entries([older, recent, frequent, workspace])
        self.assertEqual(ranked, [workspace, frequent, recent, older])
        # A newly opened workspace inherits the folder's previous selection count.
        frequent_workspace = dict(frequent, kind="Workspace", id="w8")
        self.assertEqual(workspaces.rank_entries([workspace, frequent_workspace])[0], frequent_workspace)

    def test_ctrl_r_can_refresh_even_with_no_matches(self):
        result = subprocess.CompletedProcess([], 1, "ctrl-r\0", "")
        with patch.object(workspaces.subprocess, "run", return_value=result):
            self.assertEqual(workspaces.choose([]), {"kind": "Refresh"})

    def test_refresh_reopens_picker_without_mutating_or_recording_usage(self):
        with patch.object(workspaces, "search_entries", return_value=[]) as search, \
                patch.object(workspaces, "choose", side_effect=[{"kind": "Refresh"}, None]), \
                patch.object(workspaces.shutil, "which", return_value="fzf"), \
                patch.object(workspaces, "api") as api, \
                patch.object(workspaces, "record_usage") as record:
            workspaces.main()
            self.assertFalse(search.call_args_list[0].kwargs["refresh"])
            self.assertTrue(search.call_args_list[1].kwargs["refresh"])
            api.assert_not_called()
            record.assert_not_called()

    def test_failed_open_does_not_record_usage(self):
        folder = workspaces.folder_entry(Path("/tmp/project"))
        with patch.object(workspaces, "search_entries", return_value=[folder]), \
                patch.object(workspaces, "choose", side_effect=[folder, None]), \
                patch.object(workspaces.shutil, "which", return_value="fzf"), \
                patch.object(workspaces, "open_folder", side_effect=ValueError("Folder removed")), \
                patch("builtins.input", return_value=""), \
                patch.object(workspaces, "record_usage") as record:
            workspaces.main()
            record.assert_not_called()


if __name__ == "__main__":
    unittest.main()
