#!/usr/bin/python3
"""Repository contracts: reject incoherent or unsafe declarations before building."""
import ast
import configparser
import json
from pathlib import Path
import re
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class Policy(unittest.TestCase):
    def test_packages(self):
        data = json.loads((ROOT / "packages.json").read_text())
        for release, group in data.items():
            self.assertIn(release, ("all", "44"))
            include, exclude = (group[k]["up"] for k in ("include", "exclude"))
            self.assertFalse(set(include) & set(exclude))
            for items in (include, exclude):
                self.assertEqual(len(items), len(set(items)))
                for name in items:
                    self.assertRegex(name, r"^[a-zA-Z0-9][a-zA-Z0-9+._-]*$")
            self.assertFalse(any(re.match(r"kernel|mesa|steam(?:$|-devices$)|.*gamescope|.*mangohud|gamemode", p)
                                 for p in include + exclude), "Gaming foundation must remain upstream")

    def test_base(self):
        text = (ROOT / "Containerfile").read_text()
        images = re.findall(r"^FROM (ghcr.io/\S+)", text, re.M)
        self.assertEqual(len(images), 1)
        self.assertRegex(images[0], r"^ghcr.io/ublue-os/bazzite-gnome:stable@sha256:[a-f0-9]{64}$")
        self.assertNotIn("install-ogc", text)
        self.assertIn("bootc container lint", text)
        self.assertIn("up-verify-image", text)

    def test_up_personal_defaults(self):
        settings = configparser.ConfigParser()
        settings.read(ROOT / "etc/dconf/db/local.d/01-ublue")
        self.assertEqual(settings["org/gnome/desktop/interface"]["icon-theme"], "'Tela-dark'")
        self.assertEqual(settings["org/gnome/desktop/peripherals/mouse"]["accel-profile"], "'flat'")
        favorites = ast.literal_eval(settings["org/gnome/shell"]["favorite-apps"])
        self.assertIn("app.zen_browser.zen.desktop", favorites)
        self.assertIn("steam.desktop", favorites)
        self.assertIn("virt-manager.desktop", favorites)
        install = (ROOT / "etc/flatpak/user/install").read_text().split()
        self.assertEqual(len(install), len(set(install)))
        self.assertEqual(set(install), {
            "app.zen_browser.zen", "com.discordapp.Discord", "com.github.tchx84.Flatseal",
            "com.heroicgameslauncher.hgl", "com.usebottles.bottles",
            "io.github.celluloid_player.Celluloid", "com.github.marhkb.Pods",
            "org.fedoraproject.MediaWriter", "org.gnome.Calculator", "org.gnome.Calendar",
            "org.gnome.Extensions", "org.gnome.Loupe", "org.gnome.NautilusPreviewer",
            "org.gnome.Papers", "org.gnome.Snapshot", "org.gnome.TextEditor",
            "org.gnome.Weather", "org.gnome.baobab", "org.gnome.clocks", "org.gnome.font-viewer",
        })
        self.assertFalse((ROOT / "etc/flatpak/user/remove").read_text().strip())
        self.assertIn("app.zen_browser.zen", install)
        self.assertNotIn("com.valvesoftware.Steam", install)

    def test_ci_trust_boundary(self):
        workflow = yaml.safe_load((ROOT / ".github/workflows/build.yml").read_text())
        self.assertNotIn("pull_request_target", workflow.get("on", workflow.get(True, {})))
        jobs = workflow["jobs"]
        self.assertEqual(jobs["build"]["needs"], "validate")
        steps = jobs["publish"]["steps"]
        self.assertNotIn("packages", jobs["build"]["permissions"])
        for job in jobs.values():
            for step in job["steps"]:
                if "uses" in step:
                    self.assertRegex(step["uses"], r"@[a-f0-9]{40}$")
        publication = [s for s in steps if "COSIGN_PRIVATE_KEY" in s.get("env", {})]
        self.assertEqual(len(publication), 1)
        self.assertIn("github.event_name != 'pull_request'", publication[0]["if"])
        script = publication[0]["run"]
        self.assertIn("--new-bundle-format=false --use-signing-config=false", script)
        self.assertNotIn("skopeo copy", script)
        self.assertNotIn('for tag in', script)
        promotion = yaml.safe_load((ROOT / ".github/workflows/promote.yml").read_text())
        trigger = promotion.get("on", promotion.get(True))
        self.assertEqual(set(trigger), {"workflow_dispatch"})
        self.assertFalse(trigger["workflow_dispatch"]["inputs"]["validation_complete"]["default"])
        job = promotion["jobs"]["promote"]
        self.assertIn("inputs.validation_complete", job["if"])
        self.assertIn("default_branch", job["if"])
        self.assertIn("promote-image.sh manual", job["steps"][-1]["run"])
        promote = (ROOT / ".github/scripts/promote-image.sh").read_text()
        self.assertLess(promote.index("cosign verify"), promote.index("skopeo copy"))
        self.assertIn('"docker://${REPOSITORY}@${DIGEST}"', promote)
        self.assertNotIn("podman build", promote)
        self.assertIn('[[ "$actual" == "$DIGEST" ]]', promote)
        for step in job["steps"]:
            if "uses" in step:
                self.assertRegex(step["uses"], r"@[a-f0-9]{40}$")
        resolver = (ROOT / ".github/scripts/resolve-base.sh").read_text()
        self.assertIn("cosign verify --key keys/bazzite.pub", resolver)
        self.assertEqual(jobs["publish"]["needs"], "validate")
        self.assertIn("default_branch", jobs["publish"]["if"])
        self.assertEqual(jobs["publish"]["concurrency"], promotion["concurrency"])
        self.assertEqual(workflow["env"]["FEDORA_VERSION"], promotion["env"]["FEDORA_VERSION"])
        self.assertEqual(workflow.get("on", workflow.get(True))["schedule"], [{"cron": "05 10 * * *"}])
        self.assertEqual(workflow["concurrency"]["cancel-in-progress"],
                         "${{ github.event_name == 'pull_request' }}")
        names = [step.get("name") for step in steps]
        auto = steps[names.index("Automatically publish approved daily update")]
        self.assertIn("github.event_name == 'schedule'", auto["if"])
        self.assertIn("vars.BAZZITE_AUTO_PUBLISH_FEDORA == env.FEDORA_VERSION", auto["if"])
        self.assertIn("promote-image.sh automatic", auto["run"])
        self.assertLess(names.index("Build and lint"), names.index("Image smoke tests"))
        self.assertLess(names.index("Image smoke tests"), names.index("Publish candidate, sign and verify"))
        self.assertLess(names.index("Publish candidate, sign and verify"), names.index(auto["name"]))
        for step in steps:
            self.assertFalse(step.get("continue-on-error", False))
            self.assertNotIn("always()", step.get("if", ""))
            self.assertNotIn("failure()", step.get("if", ""))
        self.assertTrue(any("resolve-base.sh refresh" in step.get("run", "") for step in steps))
        self.assertTrue(any("resolve-base.sh pinned" in step.get("run", "")
                            for step in jobs["build"]["steps"]))

    def test_update_review(self):
        rules = json.loads((ROOT / "renovate.json").read_text())["packageRules"]
        self.assertFalse(any(rule.get("automerge", False) for rule in rules))

    def test_documentation(self):
        for name in ("architecture", "bazzite-comparison", "gaming-stack", "steam-troubleshooting",
                     "migration", "verification"):
            self.assertTrue((ROOT / "docs" / (name + ".md")).is_file())
        migration = (ROOT / "docs/migration.md").read_text()
        for contract in ("bootc rollback", "cosign verify", "Secure Boot", "/var", "GameMode"):
            self.assertIn(contract, migration)


if __name__ == "__main__":
    unittest.main()
