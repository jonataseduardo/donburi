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
KEYS = REPO / "claude" / "keybindings.json"
SKILLS = REPO / "herdr" / "skills"


class ClaudeSettingsTests(unittest.TestCase):
    def setUp(self):
        root = tempfile.TemporaryDirectory()
        self.addCleanup(root.cleanup)
        self.dir = Path(root.name) / ".claude"
        self.env = {**os.environ, "CLAUDE_CONFIG_DIR": str(self.dir)}

    def install(self, *args):
        return subprocess.run([str(INSTALL), *args], env=self.env, capture_output=True, text=True)

    def backups(self, name):
        return sorted(self.dir.glob(f"{name}.donburi-backup-*"))

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
        self.assertEqual([json.loads(b.read_text()) for b in self.backups("settings.json")], [user])

    def test_every_change_keeps_its_own_backup(self):
        self.dir.mkdir()
        first = {"statusLine": {"type": "command", "command": "mine"}}
        (self.dir / "settings.json").write_text(json.dumps(first))
        self.assertEqual(self.install().returncode, 0)
        second = {**LAYER, "editorMode": "normal"}
        (self.dir / "settings.json").write_text(json.dumps(second))
        self.assertEqual(self.install().returncode, 0)
        saved = [json.loads(b.read_text()) for b in self.backups("settings.json")]
        self.assertEqual(len(saved), 2)
        self.assertIn(first, saved)  # the original survives a later run
        self.assertIn(second, saved)

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
        settings, _ = json.JSONDecoder().raw_decode(result.stdout)
        self.assertEqual(settings["editorMode"], "vim")
        self.assertIn("would link", result.stdout)
        self.assertFalse((self.dir / "settings.json").exists())
        self.assertFalse((self.dir / "keybindings.json").exists())
        self.assertIn(f"would link {self.dir / 'skills/open-agent'}", result.stdout)
        self.assertFalse((self.dir / "skills").exists())

    def transcript(self, data):
        return next(b["bindings"] for b in data["bindings"] if b["context"] == "Transcript")

    def test_keybindings_are_vim_scrolling_in_the_transcript(self):
        keys = self.transcript(json.loads(KEYS.read_text()))
        self.assertEqual(keys["j"], "scroll:lineDown")
        self.assertEqual(keys["k"], "scroll:lineUp")
        self.assertEqual(keys["g"], "scroll:top")
        self.assertEqual(keys["shift+g"], "scroll:bottom")
        self.assertEqual(keys["ctrl+u"], "scroll:halfPageUp")
        self.assertNotIn("ctrl+d", keys)  # reserved: Claude Code always exits on it

    def test_keybindings_are_linked_when_missing(self):
        self.assertEqual(self.install().returncode, 0)
        target = self.dir / "keybindings.json"
        self.assertTrue(target.is_symlink())
        self.assertEqual(target.resolve(), KEYS.resolve())
        self.assertIn("already linked", self.install().stdout)

    def test_existing_keybindings_are_merged_not_clobbered(self):
        self.dir.mkdir()
        user = {"bindings": [
            {"context": "Chat", "bindings": {"ctrl+e": "chat:externalEditor"}},
            {"context": "Transcript", "bindings": {"d": None, "j": "transcript:exit"}},
        ]}
        (self.dir / "keybindings.json").write_text(json.dumps(user))
        self.assertEqual(self.install().returncode, 0)
        merged = json.loads((self.dir / "keybindings.json").read_text())
        self.assertFalse((self.dir / "keybindings.json").is_symlink())
        self.assertEqual(merged["bindings"][0], user["bindings"][0])
        transcript = self.transcript(merged)
        self.assertIsNone(transcript["d"])                  # the user's unbinding stays
        self.assertEqual(transcript["j"], "transcript:exit")  # the user's key wins
        self.assertEqual(transcript["k"], "scroll:lineUp")
        self.assertEqual([json.loads(b.read_text()) for b in self.backups("keybindings.json")], [user])
        self.assertIn("keybindings already up to date", self.install().stdout)

    def test_existing_keybindings_without_a_transcript_block_get_one(self):
        self.dir.mkdir()
        (self.dir / "keybindings.json").write_text('{"bindings": [{"context": "Chat", "bindings": {}}]}')
        self.assertEqual(self.install().returncode, 0)
        merged = json.loads((self.dir / "keybindings.json").read_text())
        self.assertEqual(self.transcript(merged)["g"], "scroll:top")

    def test_skills_are_linked_when_missing(self):
        self.assertEqual(self.install().returncode, 0)
        link = self.dir / "skills/open-agent"
        self.assertTrue(link.is_symlink())
        self.assertEqual(link.resolve(), SKILLS.resolve() / "open-agent")
        self.assertIn("skill already linked", self.install().stdout)

    def test_a_skill_already_there_is_left_alone(self):
        mine = self.dir / "skills/open-agent"
        mine.mkdir(parents=True)
        (mine / "SKILL.md").write_text("my own")
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(mine.is_symlink())
        self.assertEqual((mine / "SKILL.md").read_text(), "my own")
        self.assertIn("already exists", result.stderr)


if __name__ == "__main__":
    unittest.main()
