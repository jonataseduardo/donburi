"""claude/install.sh merges donburi's Claude Code layer without losing other keys.

Run with: python3 test/test_claude_settings.py
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent
INSTALL = REPO / "claude" / "install.sh"
LAYER = json.loads((REPO / "claude" / "settings.json").read_text())


class ClaudeSettingsTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.dir = Path(root.name) / ".claude"
        self.env = {**os.environ, "CLAUDE_CONFIG_DIR": str(self.dir)}

    def install(self, *args):
        return subprocess.run([str(INSTALL), *args], env=self.env, capture_output=True, text=True)

    def test_layer_has_the_global_keys(self):
        self.assertEqual(LAYER["editorMode"], "vim")
        self.assertNotIn("vimInsertModeRemaps", LAYER)
        self.assertEqual(LAYER["statusLine"]["refreshInterval"], 5)
        self.assertTrue(LAYER["statusLine"]["hideVimModeIndicator"])
        self.assertIn("statusline.py", LAYER["statusLine"]["command"])

    def test_merge_keeps_the_users_other_keys(self):
        self.dir.mkdir()
        user = {"enabledPlugins": {"x@y": True}, "permissions": {"allow": ["Bash(ls)"]},
                "statusLine": {"type": "command", "command": "old", "padding": 2}}
        (self.dir / "settings.json").write_text(json.dumps(user))
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        merged = json.loads((self.dir / "settings.json").read_text())
        self.assertEqual(merged["enabledPlugins"], user["enabledPlugins"])
        self.assertEqual(merged["permissions"], user["permissions"])
        self.assertEqual(merged["statusLine"], LAYER["statusLine"])  # replaced, not mixed
        self.assertEqual(merged["editorMode"], "vim")
        self.assertEqual(json.loads((self.dir / "settings.json.donburi-backup").read_text()), user)

    def test_second_run_changes_nothing(self):
        self.assertEqual(self.install().returncode, 0)
        before = (self.dir / "settings.json").read_text()
        result = self.install()
        self.assertIn("already up to date", result.stdout)
        self.assertEqual((self.dir / "settings.json").read_text(), before)

    def test_invalid_json_is_left_alone(self):
        self.dir.mkdir()
        (self.dir / "settings.json").write_text("{not json")
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.dir / "settings.json").read_text(), "{not json")

    def test_dry_run_writes_nothing(self):
        result = self.install("--dry-run")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["editorMode"], "vim")
        self.assertFalse((self.dir / "settings.json").exists())


if __name__ == "__main__":
    unittest.main()
