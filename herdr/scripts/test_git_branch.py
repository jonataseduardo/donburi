"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("git-branch.sh")
GLYPH = ""


def git(cwd, *args):
    return subprocess.run(["git", "-C", str(cwd), *args], check=True, capture_output=True,
                          text=True, env={**os.environ, "GIT_CONFIG_GLOBAL": os.devnull}).stdout.strip()


class GitBranchTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.root = Path(root.name).resolve()
        self.repo = self.root / "repo"
        (self.repo / "src/deep").mkdir(parents=True)
        git(self.repo, "init", "-q", "-b", "feature/tab-bar")
        git(self.repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "init")

    def branch(self, cwd):
        result = subprocess.run([str(SCRIPT)], capture_output=True, text=True, check=True,
                                env={**os.environ, "HERDR_ACTIVE_PANE_CWD": str(cwd)})
        return result.stdout

    def assert_matches_git(self, cwd):
        """The tab bar shows what `git branch --show-current` prints."""
        expected = git(cwd, "branch", "--show-current")
        self.assertEqual(self.branch(cwd), f"{GLYPH} {expected}\n" if expected else "")

    def test_repo_and_subfolders(self):
        self.assertEqual(self.branch(self.repo / "src/deep"), f"{GLYPH} feature/tab-bar\n")
        self.assert_matches_git(self.repo)
        self.assert_matches_git(self.repo / "src/deep")

    def test_detached_head_is_blank(self):
        git(self.repo, "checkout", "-q", "--detach")
        self.assertEqual(self.branch(self.repo), "")
        self.assert_matches_git(self.repo)

    def test_linked_worktree_reads_its_own_head(self):
        worktree = self.root / "wt"
        git(self.repo, "worktree", "add", "-q", "-b", "other", str(worktree))
        self.assertEqual(self.branch(worktree), f"{GLYPH} other\n")
        self.assert_matches_git(worktree)

    def test_relative_gitdir_file(self):
        (self.root / "moved").mkdir()
        (self.repo / ".git").rename(self.root / "moved/.git")
        (self.repo / ".git").write_text("gitdir: ../moved/.git\n")
        self.assertEqual(self.branch(self.repo / "src"), f"{GLYPH} feature/tab-bar\n")

    def test_symlinked_folder_follows_the_real_path(self):
        link = self.root / "link"
        link.symlink_to(self.repo / "src")
        self.assertEqual(self.branch(link), f"{GLYPH} feature/tab-bar\n")

    def test_outside_a_repo_and_missing_folder_are_blank(self):
        (self.root / "plain").mkdir()
        self.assertEqual(self.branch(self.root / "plain"), "")
        self.assertEqual(self.branch(self.root / "gone"), "")

    def test_starts_no_git_in_a_normal_repo(self):
        """No git on PATH: the branch still shows, so the script never ran it."""
        env = {"HERDR_ACTIVE_PANE_CWD": str(self.repo), "PATH": str(self.root / "empty")}
        result = subprocess.run(["/bin/bash", str(SCRIPT)], capture_output=True, text=True, env=env)
        self.assertEqual((result.returncode, result.stdout), (0, f"{GLYPH} feature/tab-bar\n"))


if __name__ == "__main__":
    unittest.main()
