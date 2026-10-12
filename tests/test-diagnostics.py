#!/usr/bin/python3
import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

script = Path(__file__).resolve().parents[1] / "usr/bin/up-steam-diagnostics"
loader = importlib.machinery.SourceFileLoader("diagnostics", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
diagnostics = importlib.util.module_from_spec(spec)
loader.exec_module(diagnostics)


class Diagnostics(unittest.TestCase):
    def test_environment_values_never_exposed(self):
        result = diagnostics.present_environment({"LD_PRELOAD": "/home/private/secret", "TOKEN": "password"})
        self.assertEqual(result, ["LD_PRELOAD"])

    def test_logs_only_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "cef_log.txt"
            log.write_text("ERROR account=secret GPU crash /home/private\n")
            result = diagnostics.log_counts(log)
            self.assertEqual(result["counts"]["gpu crash"], 1)
            self.assertNotIn("secret", str(result))
            self.assertNotIn("private", str(result))

    def test_missing_tool(self):
        with patch.object(diagnostics.subprocess, "run", side_effect=FileNotFoundError):
            self.assertEqual(diagnostics.command("absent"), (127, ""))

    def test_timeout(self):
        with patch.object(diagnostics.subprocess, "run",
                          side_effect=diagnostics.subprocess.TimeoutExpired("probe", 20)):
            self.assertEqual(diagnostics.command("probe"), (127, ""))


if __name__ == "__main__":
    unittest.main()
