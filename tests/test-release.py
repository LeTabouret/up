#!/usr/bin/python3
"""Exercise release scripts with isolated registry/container/signature doubles."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
BASE = "sha256:" + "a" * 64
CANDIDATE = "sha256:" + "b" * 64
PREVIOUS = "sha256:" + "c" * 64
REPOSITORY = "ghcr.io/letabouret/up"

TOOL = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open('calls', 'a') as f:
    f.write(json.dumps([tool, *args]) + '\n')
state = json.loads(pathlib.Path('state.json').read_text())
if tool == 'cosign':
    if state.get('bad_signature') in ('all', args[-1]) or state.get('cosign_failure') == args[0]:
        sys.exit(1)
elif tool == 'podman':
    if state.get('podman_failure') == args[0]:
        sys.exit(1)
    if args[0] == 'run':
        print(state.get('major', '44'))
    elif args[0] == 'push':
        pathlib.Path(args[args.index('--digestfile') + 1]).write_text(state['candidate'])
elif tool == 'skopeo':
    if args[0] == 'copy':
        if state.get('copy_failure') == args[-1].rsplit(':', 1)[1]:
            sys.exit(1)
        state.setdefault('tags', {})[args[-1]] = args[-2].split('@')[1]
        pathlib.Path('state.json').write_text(json.dumps(state))
    elif '--config' in args:
        labels = {
            'org.opencontainers.image.title': 'Up', 'containers.bootc': '1',
            'org.opencontainers.image.version': '44-test',
            'org.opencontainers.image.base.name': 'ghcr.io/ublue-os/bazzite-gnome:stable',
        }
        key = 'previous_labels' if args[-1].endswith(state['previous']) else 'candidate_labels'
        labels.update(state.get(key, {}))
        print(json.dumps({'config': {'Labels': labels}}))
    elif args[-1].endswith('bazzite-gnome:stable'):
        if state.get('resolution_failure'):
            sys.exit(1)
        print(state['base'])
    else:
        if state.get('missing_latest'):
            sys.exit(1)
        print(state.get('tags', {}).get(args[-1], state['previous']))
'''


class Release(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cwd = Path(self.temp.name)
        self.bin = self.cwd / 'bin'
        self.bin.mkdir()
        for name in ('skopeo', 'cosign', 'podman'):
            path = self.bin / name
            path.write_text(TOOL)
            path.chmod(0o755)
        shutil.copyfile(ROOT / 'Containerfile', self.cwd / 'Containerfile')
        self.original = (self.cwd / 'Containerfile').read_text()
        self.state = {'base': BASE, 'previous': PREVIOUS, 'candidate': CANDIDATE}
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}',
                        FEDORA_VERSION='44', GITHUB_ENV=str(self.cwd / 'env'),
                        GITHUB_STEP_SUMMARY=str(self.cwd / 'summary'),
                        REGISTRY_AUTH_FILE=str(self.cwd / 'auth'),
                        REPOSITORY=REPOSITORY, DIGEST=CANDIDATE,
                        BAZZITE_AUTO_PUBLISH_FEDORA='44')

    def run_script(self, name, mode, success=True):
        (self.cwd / 'state.json').write_text(json.dumps(self.state))
        result = subprocess.run(['bash', str(ROOT / '.github/scripts' / name), mode],
                                cwd=self.cwd, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.calls = [json.loads(line) for line in (self.cwd / 'calls').read_text().splitlines()] \
            if (self.cwd / 'calls').exists() else []
        return self.calls

    def no_copy(self):
        self.assertFalse(any(call[:2] == ['skopeo', 'copy'] for call in self.calls))

    def test_refresh_uses_one_verified_digest_everywhere(self):
        calls = self.run_script('resolve-base.sh', 'refresh')
        base = f'ghcr.io/ublue-os/bazzite-gnome:stable@{BASE}'
        self.assertIn(f'FROM {base} AS base', (self.cwd / 'Containerfile').read_text())
        self.assertEqual((self.cwd / 'env').read_text(), f'BASE_DIGEST={BASE}\n')
        self.assertIn(base, (self.cwd / 'summary').read_text())
        self.assertEqual([call[:2] for call in calls],
                         [['skopeo', 'inspect'], ['cosign', 'verify'], ['podman', 'pull'], ['podman', 'run']])
        self.assertTrue(all(base in call for call in calls[1:]))
        self.assertIn('--network=none', calls[-1])

    def test_pr_keeps_committed_pin(self):
        self.run_script('resolve-base.sh', 'pinned')
        self.assertEqual((self.cwd / 'Containerfile').read_text(), self.original)
        self.assertFalse(any(call[0] == 'skopeo' for call in self.calls))

    def test_unrewritable_from_line_fails_before_build(self):
        (self.cwd / 'Containerfile').write_text(self.original.replace(' AS base', ' as base'))
        self.run_script('resolve-base.sh', 'refresh', success=False)
        self.assertFalse((self.cwd / 'env').exists())

    def test_bad_upstream_never_changes_pin_or_exports_digest(self):
        scenarios = [{'major': '45'}, {'major': '43'}, {'major': ''},
                     {'bad_signature': 'all'}, {'base': 'sha256:invalid'},
                     {'resolution_failure': True}, {'podman_failure': 'pull'},
                     {'podman_failure': 'run'}]
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                self.state = {'base': BASE, 'previous': PREVIOUS, **scenario}
                self.run_script('resolve-base.sh', 'refresh', success=False)
                self.assertEqual((self.cwd / 'Containerfile').read_text(), self.original)
                self.assertFalse((self.cwd / 'env').exists())

    def test_automatic_promotes_only_verified_digest_latest_last(self):
        calls = self.run_script('promote-image.sh', 'automatic')
        copies = [call for call in calls if call[:2] == ['skopeo', 'copy']]
        self.assertEqual([call[-1] for call in copies],
                         [f'docker://{REPOSITORY}:44', f'docker://{REPOSITORY}:latest'])
        for call in copies:
            self.assertIn('--preserve-digests', call)
            self.assertEqual(call[-2], f'docker://{REPOSITORY}@{CANDIDATE}')
        verifies = [call for call in calls if call[:2] == ['cosign', 'verify']]
        self.assertEqual([call[-1] for call in verifies],
                         [f'{REPOSITORY}@{PREVIOUS}', f'{REPOSITORY}@{CANDIDATE}'])
        self.assertLess(calls.index(verifies[-1]), calls.index(copies[0]))

    def test_opt_in_is_explicit_and_major_specific(self):
        for value in ('', 'true', '45'):
            with self.subTest(value=value):
                self.env['BAZZITE_AUTO_PUBLISH_FEDORA'] = value
                self.run_script('promote-image.sh', 'automatic', success=False)
                self.no_copy()

    def test_unapproved_or_invalid_images_never_move_tags(self):
        scenarios = [
            {'missing_latest': True},
            {'previous_labels': {'org.opencontainers.image.base.name': 'silverblue'}},
            {'previous_labels': {'org.opencontainers.image.version': '43-test'}},
            {'bad_signature': f'{REPOSITORY}@{PREVIOUS}'},
            {'bad_signature': f'{REPOSITORY}@{CANDIDATE}'},
            {'candidate_labels': {'org.opencontainers.image.version': '45-test'}},
            {'candidate_labels': {'org.opencontainers.image.title': 'Other'}},
            {'candidate_labels': {'containers.bootc': '0'}},
            {'candidate_labels': {'org.opencontainers.image.base.name': None}},
        ]
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                self.state = {'base': BASE, 'previous': PREVIOUS, **scenario}
                self.run_script('promote-image.sh', 'automatic', success=False)
                self.no_copy()

    def test_manual_bootstraps_migration_without_auto_opt_in(self):
        self.env.pop('BAZZITE_AUTO_PUBLISH_FEDORA')
        self.state['previous_labels'] = {'org.opencontainers.image.base.name': 'silverblue'}
        self.run_script('promote-image.sh', 'manual')
        self.assertFalse(any(call[-1] == f'{REPOSITORY}@{PREVIOUS}' for call in self.calls))

    def test_manual_exception_can_restore_validated_silverblue(self):
        self.env.pop('BAZZITE_AUTO_PUBLISH_FEDORA')
        self.state['candidate_labels'] = {'org.opencontainers.image.base.name': 'silverblue'}
        self.run_script('promote-image.sh', 'manual')
        self.assertEqual(sum(call[:2] == ['skopeo', 'copy'] for call in self.calls), 2)

    def test_failed_major_tag_copy_does_not_touch_latest(self):
        self.state['copy_failure'] = '44'
        self.run_script('promote-image.sh', 'automatic', success=False)
        copies = [call for call in self.calls if call[:2] == ['skopeo', 'copy']]
        self.assertEqual(len(copies), 1)
        self.assertEqual(copies[0][-1], f'docker://{REPOSITORY}:44')

    def test_invalid_digest_never_contacts_registry(self):
        self.env['DIGEST'] = 'latest'
        self.run_script('promote-image.sh', 'manual', success=False)
        self.assertEqual(self.calls, [])

    def test_candidate_upload_signing_and_verification_fail_closed(self):
        workflow = yaml.safe_load((ROOT / '.github/workflows/build.yml').read_text())
        script = next(step['run'] for step in workflow['jobs']['publish']['steps']
                      if step.get('name') == 'Publish candidate, sign and verify')
        self.env.update(RUNNER_TEMP=str(self.cwd), GHCR_TOKEN='test-token',
                        GITHUB_ACTOR='test', COSIGN_PRIVATE_KEY='test-key', VERSION='44-test')
        scenarios = [({'podman_failure': 'push'}, []),
                     ({'cosign_failure': 'sign'}, ['sign']),
                     ({'cosign_failure': 'verify'}, ['sign', 'verify']),
                     ({}, ['sign', 'verify'])]
        for failure, expected in scenarios:
            with self.subTest(failure=failure):
                (self.cwd / 'calls').write_text('')
                (self.cwd / 'summary').unlink(missing_ok=True)
                (self.cwd / 'state.json').write_text(json.dumps({**self.state, **failure}))
                result = subprocess.run(['bash', '-c', script], cwd=self.cwd, env=self.env,
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, not failure, result.stderr)
                self.calls = [json.loads(line) for line in (self.cwd / 'calls').read_text().splitlines()]
                signatures = [call for call in self.calls if call[0] == 'cosign']
                self.assertEqual([call[1] for call in signatures], expected)
                for call in signatures:
                    self.assertEqual(call[-1], f'{REPOSITORY}@{CANDIDATE}')
                self.assertEqual((self.cwd / 'summary').exists(), not failure)
                self.no_copy()


if __name__ == '__main__':
    unittest.main()
