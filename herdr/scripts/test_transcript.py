"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

import json
import os
from pathlib import Path
import re
import tempfile
import time
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



def feed(event, at):
    return notification('<task-notification><summary>Monitor event: "herdr agent feed"</summary>'
                        f"<event>{event}</event></task-notification>", at=at)


def content_lines(markdown):
    """What a render says, without its headings and blank lines."""
    return [line for line in markdown.splitlines() if line.strip() and not re.match(r"^#{1,3} \d", line)]


# One session from 23:58 to 00:02 UTC (TZ is pinned to UTC in DayTests).
NIGHT = [
    {"type": "ai-title", "aiTitle": "Night shift"},
    human("check ▲ w5:p2", at="2026-11-04T23:58:00Z"),
    assistant({"type": "tool_use", "name": "Bash", "input": {"command": "herdr agent read w5:p2"}},
              at="2026-11-04T23:58:30Z"),
    assistant({"type": "text", "text": "▲ w5:p2 (donburi) is idle."}, at="2026-11-04T23:59:59Z"),
    feed("00:00:01 finished ◆ api-impl (wJ:p2) codex in curator: Approve edit", at="2026-11-05T00:00:01Z"),
    assistant({"type": "text", "text": "◆ wJ:p2 finished."}, at="2026-11-05T00:00:05Z"),
    human("thanks", at="2026-11-05T00:02:00Z"),
]
MORNING = [human("good morning", at="2026-11-05T09:00:00Z"),
           assistant({"type": "text", "text": "Nothing is blocked."}, at="2026-11-05T09:00:05Z")]


class DayTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        env = patch.dict(os.environ, {"TZ": "UTC", "CLAUDE_CONFIG_DIR": str(self.root / "claude"),
                                       "XDG_STATE_HOME": str(self.root / "state")})
        env.start()
        time.tzset()
        self.addCleanup(time.tzset)
        self.addCleanup(env.stop)
        self.days = self.root / "days"

    def session(self, name, entries, folder="-ia-ds-hq"):
        path = self.root / "claude/projects" / folder / f"{name}.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(json.dumps(e) + "\n" for e in entries))
        return path

    def test_a_session_crossing_midnight_continues_on_the_next_day(self):
        days = transcript.render_days([self.session("night", NIGHT)])
        self.assertEqual(sorted(days), ["2026-11-04", "2026-11-05"])
        self.assertTrue(days["2026-11-04"].startswith("# 2026-11-04 23:58 · Night shift\n"))
        self.assertTrue(days["2026-11-05"].startswith("# 2026-11-05 00:00 · Night shift (continued)\n"))
        self.assertIn("00:00:01 finished ◆ api-impl (wJ:p2)", days["2026-11-05"])
        self.assertNotIn("00:00:01", days["2026-11-04"])

    def test_every_line_appears_exactly_once_across_days(self):
        path = self.session("night", NIGHT)
        whole = transcript.render([path])
        days = transcript.render_days([path])
        self.assertEqual(content_lines(days["2026-11-04"]) + content_lines(days["2026-11-05"]), content_lines(whole))

    def test_sessions_on_one_day_are_in_time_order(self):
        days = transcript.render_days([self.session("morning", MORNING), self.session("night", NIGHT)])
        self.assertLess(days["2026-11-05"].index("Night shift (continued)"), days["2026-11-05"].index("good morning"))

    def test_rendering_again_writes_nothing(self):
        paths = [self.session("night", NIGHT)]
        self.assertEqual(transcript.update_days(self.days, paths), ["2026-11-04", "2026-11-05"])
        before = {p.name: p.read_bytes() for p in self.days.iterdir()}
        self.assertEqual(transcript.update_days(self.days, paths), [])
        self.assertEqual({p.name: p.read_bytes() for p in self.days.iterdir()}, before)

    def test_a_day_file_is_never_shrunk(self):
        night, morning = self.session("night", NIGHT), self.session("morning", MORNING)
        transcript.update_days(self.days, [night, morning])
        kept = (self.days / "2026-11-05.md").read_text()
        # The night session leaves the window (or Claude deletes its transcript).
        self.assertEqual(transcript.update_days(self.days, [morning]), [])
        self.assertEqual((self.days / "2026-11-05.md").read_text(), kept)
        self.assertIn("Night shift (continued)", kept)

    def test_a_day_grows_as_the_session_goes_on(self):
        path = self.session("morning", MORNING[:1])
        transcript.update_days(self.days, [path])
        self.session("morning", MORNING)
        self.assertEqual(transcript.update_days(self.days, [path]), ["2026-11-05"])
        self.assertIn("Nothing is blocked.", (self.days / "2026-11-05.md").read_text())

    def test_index_counts_sessions_turns_feed_events_and_agents(self):
        transcript.update_days(self.days, [self.session("night", NIGHT), self.session("morning", MORNING)])
        index = (self.days / "index.md").read_text().splitlines()
        self.assertEqual(index[4], "| [2026-11-05](2026-11-05.md) | 2 | 4 | 1 | wJ:p2 api-impl |")
        self.assertEqual(index[5], "| [2026-11-04](2026-11-04.md) | 1 | 2 | 0 | w5:p2 donburi |")

    def test_main_writes_days_and_keeps_its_own_output(self):
        path = self.session("night", NIGHT)
        out = self.root / "view.md"
        with patch.object(transcript, "agent_session", return_value="night"):
            transcript.main(["--agent", "coordinator", "--out", str(out), "--days", str(self.days)])
        self.assertEqual(out.read_text(), transcript.render([path]))
        self.assertEqual(sorted(p.name for p in self.days.iterdir()),
                         ["2026-11-04.md", "2026-11-05.md", "index.md", "sources.json"])

    def test_backfill_takes_named_sessions_from_the_agents_folders_only(self):
        named = [{"type": "custom-title", "customTitle": "coordinator"}]
        self.session("known", MORNING)
        self.session("older", named + NIGHT)
        self.session("elsewhere", named + NIGHT, folder="-tmp-tests")
        self.session("other", NIGHT)
        history = self.root / "state/herdr/coordinator/coordinator-sessions.json"
        history.parent.mkdir(parents=True)
        history.write_text(json.dumps(["known"]))
        self.assertEqual(transcript.main(["--agent", "coordinator", "--days", str(self.days), "--backfill"]), 0)
        text = (self.days / "2026-11-05.md").read_text()
        self.assertIn("Night shift (continued)", text)
        self.assertIn("good morning", text)
        self.assertEqual(history.read_text(), json.dumps(["known"]))  # the agent's list is left alone
        found = transcript.named_sessions("coordinator", [self.root / "claude/projects/-ia-ds-hq"])
        self.assertEqual([p.stem for p in found], ["older"])

    def test_entries_copied_into_a_resumed_session_are_rendered_once(self):
        original = [dict(e, uuid=f"u{i}") for i, e in enumerate(MORNING)]
        later = human("still there?", at="2026-11-05T09:05:00Z")
        copy = original + [dict(later, uuid="u9")]  # Claude copies the session, then goes on
        first, second = self.session("original", original), self.session("copy", copy)
        days = transcript.render_days([second, first])
        self.assertEqual(days, transcript.render_days([first, second]))
        self.assertEqual(content_lines(days["2026-11-05"]),
                         content_lines(transcript.render([first])) + ["still there?"])
        self.assertEqual(days["2026-11-05"].splitlines().count("good morning"), 1)  # (titles aside)

    def test_a_copy_with_nothing_new_adds_no_empty_session(self):
        original = [dict(e, uuid=f"u{i}") for i, e in enumerate(MORNING)]
        days = transcript.render_days([self.session("original", original), self.session("copy", original)])
        self.assertEqual(days["2026-11-05"].count("\n# ") + days["2026-11-05"].startswith("# "), 1)

    def test_a_day_keeps_every_session_that_went_into_it(self):
        night, morning = self.session("night", NIGHT), self.session("morning", MORNING)
        transcript.update_days(self.days, [night, morning])  # e.g. the backfill
        # Later only the morning session is followed, and it grows past the
        # night's share of the day: the day is still rendered from both.
        more = [human(f"turn {i}", at=f"2026-11-05T10:0{i}:00Z") for i in range(8)]
        self.session("morning", MORNING + more)
        self.assertEqual(transcript.update_days(self.days, [morning]), ["2026-11-05"])
        text = (self.days / "2026-11-05.md").read_text()
        self.assertIn("Night shift (continued)", text)
        self.assertIn("turn 7", text)
        sources = json.loads((self.days / "sources.json").read_text())
        self.assertEqual(sources["2026-11-05"], sorted([str(night), str(morning)]))
        self.assertEqual(sources["2026-11-04"], [str(night)])

    def test_backfill_needs_agent_and_days(self):
        with self.assertRaises(SystemExit):
            transcript.main(["--session", "x", "--backfill"])

if __name__ == "__main__":
    unittest.main()
