"""Run with: python3 -m unittest discover -s herdr/scripts -p 'test_*.py'."""

import re
import unittest

import coordinator_status


def plain(text):
    return re.sub(r"\033\[[0-9;]*m", "", text)


class StatusLineTests(unittest.TestCase):
    def test_banner_model_and_counts(self):
        line = coordinator_status.status_line("Haiku 4.5", {"agents": 18, "blocked": 2, "working": 1, "idle": 15})
        self.assertEqual(plain(line), " ◉ COORDINATOR  Haiku 4.5 18 agents · 2 blocked · 1 working")
        self.assertIn(coordinator_status.BLOCKED + "2 blocked", line)

    def test_quiet_fleet_shows_only_the_total(self):
        self.assertEqual(plain(coordinator_status.status_line("", {"agents": 1, "idle": 1})),
                         " ◉ COORDINATOR  1 agent")

    def test_vim_mode_follows_the_banner(self):
        line = plain(coordinator_status.status_line("Opus 5.5", {"agents": 1}, "NORMAL"))
        self.assertEqual(line, " ◉ COORDINATOR  NORMAL Opus 5.5 1 agent")

    def test_settings_hide_claudes_own_vim_indicator(self):
        import json
        from pathlib import Path
        settings = json.loads((Path(__file__).parent.parent / "coordinator-settings.json").read_text())
        self.assertTrue(settings["statusLine"]["hideVimModeIndicator"])

    def test_unreachable_herdr(self):
        self.assertIn("herdr unavailable", plain(coordinator_status.status_line("Haiku", None)))


if __name__ == "__main__":
    unittest.main()
