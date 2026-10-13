#!/usr/bin/python3
"""Run only the hardware-service blocks; never run host composition scripts."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CUSTOMIZE = (ROOT / "customize.sh").read_text().split(
    "# Hardware-specific tools remain available", 1)[1].split(
    "# Record the composed result", 1)[0]
CUSTOMIZE = CUSTOMIZE[CUSTOMIZE.index("\n") + 1:]
VERIFY = (ROOT / "usr/libexec/up-verify-image").read_text().split(
    "for unit in fw-fanctrl.service", 1)[1].split(
    'test "$(systemctl is-enabled input-remapper.service)"', 1)[0]
VERIFY = "for unit in fw-fanctrl.service" + VERIFY

# Shell functions intercept every external command in the selected blocks.
DOUBLES = r'''
rpm() {
    [[ "$*" == '-q --quiet displaylink' ]] || exit 90
    [[ "$PACKAGE_PRESENT" == 1 ]]
}
systemctl() {
    printf '%s\n' "$*" >> "$CALL_LOG"
    if [[ "$1" == disable ]]; then
        [[ "$*" != *"$FAIL_UNIT"* ]]
    elif [[ "$1" == is-enabled ]]; then
        if [[ "$2" == displaylink.service ]]; then
            printf '%s\n' "$DISPLAYLINK_STATE"
            [[ "$DISPLAYLINK_STATE" == enabled ]]
        else
            echo disabled
            return 1
        fi
    else
        exit 91
    fi
}
'''


class OptionalDisplayLink(unittest.TestCase):
    def run_block(self, block, present, state="disabled", fail_unit="none", success=True):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / "calls"
            result = subprocess.run(
                ["bash", "-euo", "pipefail", "-c", DOUBLES + block],
                env=dict(os.environ, PACKAGE_PRESENT=str(int(present)),
                         DISPLAYLINK_STATE=state, FAIL_UNIT=fail_unit, CALL_LOG=str(log)),
                capture_output=True, text=True)
            self.assertEqual(result.returncode == 0, success, result.stderr)
            return log.read_text()

    def test_upstream_without_displaylink(self):
        for block in (CUSTOMIZE, VERIFY):
            calls = self.run_block(block, present=False)
            self.assertNotIn("displaylink.service", calls)
            self.assertIn("fw-fanctrl.service", calls)
            self.assertIn("scx_loader.service", calls)

    def test_bundled_displaylink_is_disabled_and_checked(self):
        self.assertIn("disable displaylink.service", self.run_block(CUSTOMIZE, present=True))
        self.assertIn("is-enabled displaylink.service", self.run_block(VERIFY, present=True))

    def test_present_package_disable_failure_is_fatal(self):
        self.run_block(CUSTOMIZE, present=True, fail_unit="displaylink.service", success=False)

    def test_other_disable_failure_is_fatal(self):
        self.run_block(CUSTOMIZE, present=False, fail_unit="fw-fanctrl.service", success=False)

    def test_present_package_must_have_disabled_unit(self):
        for state in ("enabled", "not-found", "", "masked"):
            with self.subTest(state=state):
                self.run_block(VERIFY, present=True, state=state, success=False)

    def test_displaylink_is_not_an_unconditional_required_rpm(self):
        verifier = (ROOT / "usr/libexec/up-verify-image").read_text()
        required = verifier.split("rpm -q gnome-shell", 1)[1].split("# Every declared exclusion", 1)[0]
        self.assertNotIn("displaylink", required.split())


if __name__ == "__main__":
    unittest.main()
