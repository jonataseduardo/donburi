#!/usr/bin/env python3
"""Exercise the real zsh launch functions with isolated HOME and fake CLIs."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")


@unittest.skipUnless(ZSH, "zsh is required")
class HarnessTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "launches.jsonl"
        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.bin),
            "LAUNCH_LOG": str(self.log),
            "HARNESS_EXIT": "0",
        }
        for name in ("claude", "opencode", "cursor-agent", "agent", "cursor"):
            self.script(name, """
import json, os, sys
from pathlib import Path
with open(os.environ['LAUNCH_LOG'], 'a') as log:
    log.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + '\\n')
sys.exit(int(os.environ['HARNESS_EXIT']))
""")
        self.script("caffeinate", """
import json, os, subprocess, sys
with open(os.environ['LAUNCH_LOG'], 'a') as log:
    log.write(json.dumps(['caffeinate', *sys.argv[1:]]) + '\\n')
try:
    sys.exit(subprocess.run(sys.argv[2:]).returncode)
except FileNotFoundError:
    sys.exit(127)
""")

    def script(self, name, body):
        path = self.bin / name
        path.write_text(f"#!{sys.executable}\n{body}")
        path.chmod(0o755)

    def launch(self, command):
        # eval parses aliases only after the real configuration has been sourced.
        return subprocess.run(
            [ZSH, "-dfc", 'source "$1"; eval "$2"', "test-harness",
             str(ROOT / "zsh/donburi.zsh"), command],
            env=self.env, capture_output=True, text=True,
        )

    def launches(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_all_harnesses_preserve_arguments(self):
        for name in ("claude", "opencode", "cursor-agent", "agent", "cursor", "oc"):
            with self.subTest(name=name):
                self.log.unlink(missing_ok=True)
                result = self.launch(f'{name} "a prompt with spaces" "" --model test')
                self.assertEqual(result.returncode, 0, result.stderr)
                binary = "opencode" if name == "oc" else name
                args = (["--wait"] if name == "cursor" else [])
                args += ["a prompt with spaces", "", "--model", "test"]
                self.assertEqual(self.launches(), [
                    ["caffeinate", "-i", binary, *args], [binary, *args],
                ])

    def test_exit_status(self):
        self.env["HARNESS_EXIT"] = "42"
        self.assertEqual(self.launch("claude").returncode, 42)

    def test_per_launch_opt_out(self):
        result = self.launch("DONBURI_CAFFEINATE=0 claude first; claude second")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launches(), [
            ["claude", "first"], ["caffeinate", "-i", "claude", "second"],
            ["claude", "second"],
        ])

    def test_missing_caffeinate_falls_back(self):
        (self.bin / "caffeinate").unlink()
        result = self.launch("opencode run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launches(), [["opencode", "run"]])

    def test_command_bypasses_gui_wrapper(self):
        result = self.launch("command cursor .")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.launches(), [["cursor", "."]])


if __name__ == "__main__":
    unittest.main()
