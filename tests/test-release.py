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
            'org.opencontainers.image.base.name': 'ghcr.io/ublue-os/bazzite-gnome:stable-44',
        }
        key = 'previous_labels' if args[-1].endswith(state['previous']) else 'candidate_labels'
        labels.update(state.get(key, {}))
        print(json.dumps({'config': {'Labels': labels}}))
    elif args[-1].startswith('docker://ghcr.io/ublue-os/bazzite-gnome:'):
        if state.get('resolution_failure'):
            sys.exit(1)
        print(state['base'])
    else:
        if state.get('missing_previous') and args[-1] not in state.get('tags', {}):
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
                        GITHUB_ENV=str(self.cwd / 'env'),
                        GITHUB_STEP_SUMMARY=str(self.cwd / 'summary'),
                        REGISTRY_AUTH_FILE=str(self.cwd / 'auth'),
                        REPOSITORY=REPOSITORY, DIGEST=CANDIDATE, CHANNEL='stable-44')

    def run_script(self, name, *args, success=True):
        (self.cwd / 'state.json').write_text(json.dumps(self.state))
        result = subprocess.run(['bash', str(ROOT / '.github/scripts' / name), *args],
                                cwd=self.cwd, env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.calls = [json.loads(line) for line in (self.cwd / 'calls').read_text().splitlines()] \
            if (self.cwd / 'calls').exists() else []
        return self.calls

    def no_copy(self):
        self.assertFalse(any(call[:2] == ['skopeo', 'copy'] for call in self.calls))

    def copies(self):
        return [call[-1].rsplit(':', 1)[1] for call in self.calls if call[:2] == ['skopeo', 'copy']]

    def exported(self):
        return dict(line.split('=', 1) for line in (self.cwd / 'env').read_text().splitlines())

    def test_refresh_uses_one_verified_digest_everywhere(self):
        calls = self.run_script('resolve-base.sh', 'refresh', 'stable-44')
        base = f'ghcr.io/ublue-os/bazzite-gnome:stable-44@{BASE}'
        self.assertIn(f'FROM {base} AS base', (self.cwd / 'Containerfile').read_text())
        self.assertEqual(self.exported(), {
            'BASE_DIGEST': BASE, 'UP_BASE_NAME': 'ghcr.io/ublue-os/bazzite-gnome:stable-44',
            'UP_CHANNEL': 'stable-44', 'UP_FEDORA_MAJOR': '44'})
        self.assertIn(base, (self.cwd / 'summary').read_text())
        self.assertEqual([call[:2] for call in calls],
                         [['skopeo', 'inspect'], ['cosign', 'verify'], ['podman', 'pull'], ['podman', 'run']])
        self.assertEqual(calls[0][-1], 'docker://ghcr.io/ublue-os/bazzite-gnome:stable-44')
        self.assertTrue(all(base in call for call in calls[1:]))
        self.assertIn('--network=none', calls[-1])

    def test_refresh_each_major_stream_from_its_own_tag(self):
        self.state['major'] = '45'
        calls = self.run_script('resolve-base.sh', 'refresh', 'stable-45')
        self.assertEqual(calls[0][-1], 'docker://ghcr.io/ublue-os/bazzite-gnome:stable-45')
        self.assertEqual(self.exported()['UP_FEDORA_MAJOR'], '45')
        self.assertEqual(self.exported()['UP_CHANNEL'], 'stable-45')

    def test_latest_rolls_with_upstream_stable_to_any_major(self):
        for major in ('44', '45', '46'):
            with self.subTest(major=major):
                (self.cwd / 'env').unlink(missing_ok=True)
                (self.cwd / 'calls').unlink(missing_ok=True)
                (self.cwd / 'Containerfile').write_text(self.original)
                self.state['major'] = major
                calls = self.run_script('resolve-base.sh', 'refresh', 'latest')
                self.assertEqual(calls[0][-1], 'docker://ghcr.io/ublue-os/bazzite-gnome:stable')
                self.assertIn(f'FROM ghcr.io/ublue-os/bazzite-gnome:stable@{BASE} AS base',
                              (self.cwd / 'Containerfile').read_text())
                self.assertEqual(self.exported(), {
                    'BASE_DIGEST': BASE, 'UP_BASE_NAME': 'ghcr.io/ublue-os/bazzite-gnome:stable',
                    'UP_CHANNEL': 'latest', 'UP_FEDORA_MAJOR': major})

    def test_pr_keeps_committed_pin(self):
        self.run_script('resolve-base.sh', 'pinned')
        self.assertEqual((self.cwd / 'Containerfile').read_text(), self.original)
        self.assertFalse(any(call[0] == 'skopeo' for call in self.calls))
        self.assertEqual(self.exported()['UP_CHANNEL'], 'stable-44')
        self.assertEqual(self.exported()['UP_FEDORA_MAJOR'], '44')

    def test_unrewritable_from_line_fails_before_build(self):
        (self.cwd / 'Containerfile').write_text(self.original.replace(' AS base', ' as base'))
        self.run_script('resolve-base.sh', 'refresh', 'stable-44', success=False)
        self.assertFalse((self.cwd / 'env').exists())

    def test_bad_upstream_never_changes_pin_or_exports_digest(self):
        scenarios = [('stable-44', {'major': '45'}), ('stable-44', {'major': '43'}),
                     ('stable-45', {'major': '44'}), ('stable-44', {'major': ''}),
                     ('latest', {'major': ''}), ('latest', {'major': 'rawhide'}),
                     ('stable-44', {'bad_signature': 'all'}), ('latest', {'bad_signature': 'all'}),
                     ('stable-44', {'base': 'sha256:invalid'}),
                     ('stable-44', {'resolution_failure': True}),
                     ('stable-44', {'podman_failure': 'pull'}),
                     ('stable-44', {'podman_failure': 'run'}),
                     ('', {}), ('stable', {}), ('stable-x', {}), ('beta', {})]
        for channel, scenario in scenarios:
            with self.subTest(channel=channel, scenario=scenario):
                self.state = {'base': BASE, 'previous': PREVIOUS, **scenario}
                self.run_script('resolve-base.sh', 'refresh', channel, success=False)
                self.assertEqual((self.cwd / 'Containerfile').read_text(), self.original)
                self.assertFalse((self.cwd / 'env').exists())

    def test_automatic_promotes_only_verified_digest_channel_first(self):
        calls = self.run_script('promote-image.sh', 'automatic')
        copies = [call for call in calls if call[:2] == ['skopeo', 'copy']]
        self.assertEqual(self.copies(), ['stable-44', '44'])
        for call in copies:
            self.assertIn('--preserve-digests', call)
            self.assertEqual(call[-2], f'docker://{REPOSITORY}@{CANDIDATE}')
        verifies = [call for call in calls if call[:2] == ['cosign', 'verify']]
        self.assertEqual([call[-1] for call in verifies],
                         [f'{REPOSITORY}@{CANDIDATE}', f'{REPOSITORY}@{PREVIOUS}'])
        self.assertLess(calls.index(verifies[-1]), calls.index(copies[0]))

    def test_new_major_stream_publishes_without_previous_tag(self):
        self.env['CHANNEL'] = 'stable-45'
        self.state.update(missing_previous=True, candidate_labels={
            'org.opencontainers.image.version': '45-test',
            'org.opencontainers.image.base.name': 'ghcr.io/ublue-os/bazzite-gnome:stable-45'})
        self.run_script('promote-image.sh', 'automatic')
        self.assertEqual(self.copies(), ['stable-45', '45'])

    def latest_candidate(self, major):
        self.env['CHANNEL'] = 'latest'
        self.state['candidate_labels'] = {
            'org.opencontainers.image.version': f'{major}-test',
            'org.opencontainers.image.base.name': 'ghcr.io/ublue-os/bazzite-gnome:stable'}

    def test_latest_moves_forward_to_new_major(self):
        self.latest_candidate('45')
        # The image on latest today was built from the floating tag on Fedora 44.
        self.state['previous_labels'] = {
            'org.opencontainers.image.base.name': 'ghcr.io/ublue-os/bazzite-gnome:stable'}
        self.run_script('promote-image.sh', 'automatic')
        self.assertEqual(self.copies(), ['latest'])

    def test_latest_updates_within_its_major(self):
        self.latest_candidate('45')
        self.state['previous_labels'] = {'org.opencontainers.image.version': '45-old'}
        self.run_script('promote-image.sh', 'automatic')
        self.assertEqual(self.copies(), ['latest'])

    def test_latest_never_moves_back_or_bootstraps_automatically(self):
        scenarios = [
            {'previous_labels': {'org.opencontainers.image.version': '46-test'}},
            {'missing_previous': True},
            {'previous_labels': {'org.opencontainers.image.base.name': 'silverblue'}},
            {'bad_signature': f'{REPOSITORY}@{PREVIOUS}'},
        ]
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                self.state = {'base': BASE, 'previous': PREVIOUS, **scenario}
                self.latest_candidate('45')
                self.run_script('promote-image.sh', 'automatic', success=False)
                self.no_copy()

    def test_unapproved_or_invalid_images_never_move_tags(self):
        stable = 'ghcr.io/ublue-os/bazzite-gnome:stable'
        scenarios = [
            ('stable-44', {'previous_labels': {'org.opencontainers.image.base.name': 'silverblue'}}),
            ('stable-44', {'previous_labels': {'org.opencontainers.image.version': '43-test'}}),
            ('stable-44', {'bad_signature': f'{REPOSITORY}@{PREVIOUS}'}),
            ('stable-44', {'bad_signature': f'{REPOSITORY}@{CANDIDATE}'}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.version': '45-test'}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.version': 'dev'}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.title': 'Other'}}),
            ('stable-44', {'candidate_labels': {'containers.bootc': '0'}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.base.name': None}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.base.name': stable}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.base.name': stable + '-45'}}),
            ('stable-44', {'candidate_labels': {'org.opencontainers.image.base.name': stable + '-44x'}}),
            ('latest', {'candidate_labels': {'org.opencontainers.image.base.name': stable + '-45'}}),
            ('latest', {'candidate_labels': {'org.opencontainers.image.title': 'Other'}}),
            ('latest', {'bad_signature': f'{REPOSITORY}@{CANDIDATE}'}),
            ('stable', {}), ('stable-x', {}), ('44', {}), ('', {}),
        ]
        for channel, scenario in scenarios:
            with self.subTest(channel=channel, scenario=scenario):
                self.state = {'base': BASE, 'previous': PREVIOUS, **scenario}
                if channel == 'latest':
                    self.latest_candidate('44')
                    self.state['candidate_labels'].update(scenario.get('candidate_labels', {}))
                self.env['CHANNEL'] = channel
                self.run_script('promote-image.sh', 'automatic', success=False)
                self.no_copy()

    def test_manual_bootstraps_migration(self):
        self.env['CHANNEL'] = 'latest'
        self.state['previous_labels'] = {'org.opencontainers.image.base.name': 'silverblue'}
        self.run_script('promote-image.sh', 'manual')
        self.assertFalse(any(call[-1] == f'{REPOSITORY}@{PREVIOUS}' for call in self.calls))
        self.assertEqual(self.copies(), ['latest'])

    def test_manual_exception_can_restore_validated_silverblue(self):
        self.state['candidate_labels'] = {'org.opencontainers.image.base.name': 'silverblue'}
        self.run_script('promote-image.sh', 'manual')
        self.assertEqual(self.copies(), ['stable-44', '44'])

    def test_manual_major_stream_still_requires_its_major(self):
        self.state['candidate_labels'] = {'org.opencontainers.image.version': '45-test'}
        self.run_script('promote-image.sh', 'manual', success=False)
        self.no_copy()

    def test_failed_channel_tag_copy_does_not_touch_alias(self):
        self.state['copy_failure'] = 'stable-44'
        self.run_script('promote-image.sh', 'automatic', success=False)
        self.assertEqual(self.copies(), ['stable-44'])

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
