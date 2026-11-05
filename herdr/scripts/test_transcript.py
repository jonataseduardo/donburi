"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import transcript


def human(text, at="2026-11-04T16:00:00Z"):
    return {"type": "user", "timestamp": at, "origin": {"kind": "human"}, "message": {"content": text}}


def assistant(*blocks, at="2026-11-04T16:00:05Z"):
    return {"type": "assistant", "timestamp": at, "message": {"content": list(blocks)}}


def notification(text, at="2026-11-04T16:01:00Z"):
    return {"type": "user", "timestamp": at, "origin": {"kind": "task-notification"}, "message": {"content": text}}


FEED = ('<task-notification>\n<task-id>b1</task-id>\n<summary>Monitor event: "herdr agent feed"</summary>\n'
        "<event>16:01:00 blocked  ● wJ:p2 claude in curator: Fix OCR</event>\n</task-notification>")


class RenderTests(unittest.TestCase):
    def render(self, *entries):
        return transcript.render_session(list(entries))

    def test_turns_tools_and_text(self):
        text = self.render(
            {"type": "ai-title", "aiTitle": "Agent status"},
            human("what needs me?"),
            assistant({"type": "thinking", "thinking": "secret"},
                      {"type": "tool_use", "name": "Bash", "input": {"command": "herdr agent list"}},
                      {"type": "tool_use", "name": "Read", "input": {"file_path": "/tmp/x"}},
                      {"type": "text", "text": "Nothing is blocked."}),
        )
        self.assertTrue(text.startswith("# "))
        self.assertIn("· Agent status\n", text)
        self.assertIn("· you\n\nwhat needs me?", text)
        self.assertIn("- ▸ Bash `herdr agent list`\n- ▸ Read `/tmp/x`\n\nNothing is blocked.", text)
        self.assertNotIn("secret", text)

    def test_one_claude_heading_per_run_of_assistant_messages(self):
        text = self.render(human("hi"), assistant({"type": "text", "text": "a"}), assistant({"type": "text", "text": "b"}))
        self.assertEqual(text.count("· claude"), 1)

    def test_monitor_event_becomes_feed_block(self):
        text = self.render(notification(FEED))
        self.assertIn("· feed\n\n```text\n16:01:00 blocked  ● wJ:p2 claude in curator: Fix OCR\n```", text)
        self.assertNotIn("<task-notification>", text)

    def test_background_task_summary(self):
        task = ("<task-notification><summary>Background command \"tests\" completed (exit code 0)</summary>"
                "<status>completed</status></task-notification>")
        self.assertIn('Background command "tests" completed (exit code 0)\n```', self.render(notification(task)))

    def test_queued_messages_from_user_and_from_feed(self):
        user = {"type": "attachment", "timestamp": "2026-11-04T16:02:00Z",
                "attachment": {"type": "queued_command", "prompt": "also check CI", "origin": {"kind": "human"}}}
        feed = {"type": "attachment", "timestamp": "2026-11-04T16:02:00Z",
                "attachment": {"type": "queued_command", "prompt": FEED, "origin": {"kind": "task-notification"}}}
        text = self.render(user, feed)
        self.assertIn("· you (while it worked)\n\nalso check CI", text)
        self.assertIn("· feed", text)
        self.assertNotIn("<summary>", text)

    def test_headings_in_messages_are_demoted_outside_code(self):
        text = self.render(human("# Plan\n```sh\n# comment\n```"))
        self.assertIn("### Plan", text)
        self.assertIn("\n# comment\n", text)

    def test_title_falls_back_to_first_prompt(self):
        self.assertIn("· fix the flaky test\n", self.render(human("fix the flaky test")))

    def test_system_reminders_and_tool_results_are_skipped(self):
        text = self.render({"type": "user", "message": {"content": [{"type": "tool_result", "content": "noise"}]}},
                           {"type": "attachment", "attachment": {"type": "date"}})
        self.assertNotIn("noise", text)


class FileTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        env = patch.dict(transcript.os.environ, {"CLAUDE_CONFIG_DIR": str(self.root / "claude"),
                                                  "XDG_STATE_HOME": str(self.root / "state")})
        env.start()
        self.addCleanup(env.stop)

    def test_find_transcript_by_id_or_path(self):
        path = self.root / "claude/projects/-tmp-repo/abc.jsonl"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(human("hi")) + "\n{partial")
        self.assertEqual(transcript.find_transcript("abc"), path)
        self.assertEqual(transcript.find_transcript(str(path)), path)
        self.assertIsNone(transcript.find_transcript("missing"))
        self.assertEqual(len(transcript.read_entries(path)), 1)

    def test_history_remembers_sessions_in_order(self):
        history = self.root / "state/agent-sessions.json"
        transcript.remember(history, "one", 2)
        transcript.remember(history, "two", 2)
        self.assertEqual(transcript.remember(history, "one", 2), ["one", "two"])
        self.assertEqual(transcript.remember(history, None, 2), ["one", "two"])

    def test_agent_mode_renders_the_agent_sessions(self):
        path = self.root / "claude/projects/-tmp-repo/s1.jsonl"
        path.parent.mkdir(parents=True)
        path.write_text(json.dumps(human("hello coordinator")))
        out = self.root / "view.md"
        with patch.object(transcript, "agent_session", return_value="s1"):
            transcript.main(["--agent", "coordinator", "--out", str(out)])
        self.assertIn("hello coordinator", out.read_text())

    def test_empty_history_has_placeholder(self):
        self.assertEqual(transcript.render([]), "_No conversation yet._\n")


if __name__ == "__main__":
    unittest.main()
