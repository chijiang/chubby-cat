"""Safety gates run real shell entry points; no credentials or Apple uploads."""
import os
from pathlib import Path
import subprocess
import unittest
import tempfile
import json

ROOT = Path(__file__).resolve().parents[1]

class ReleaseGates(unittest.TestCase):
    def run_script(self, script, *args, **extra):
        env = os.environ.copy()
        for key in ['SIGNING_IDENTITY', 'NOTARY_PROFILE', 'APP_VERSION', 'BUILD_NUMBER']:
            env.pop(key, None)
        env.update(extra)
        return subprocess.run(['bash', script, *args], cwd=ROOT, env=env, capture_output=True, text=True)

    def test_notarized_release_requires_real_signing_identity(self):
        result = self.run_script('scripts/release.sh', '--notarized', '--check')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SIGNING_IDENTITY', result.stderr)

    def test_adhoc_identity_cannot_be_a_notarized_release(self):
        result = self.run_script('scripts/release.sh', '--notarized', '--check', SIGNING_IDENTITY='-', NOTARY_PROFILE='fixture')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Developer ID Application', result.stderr)

    def test_notary_profile_is_required(self):
        result = self.run_script('scripts/release.sh', '--notarized', '--check', SIGNING_IDENTITY='Developer ID Application: Test (ABCDEFGHIJ)')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('NOTARY_PROFILE', result.stderr)

    def test_developer_id_build_cannot_silently_use_adhoc_signing(self):
        result = self.run_script('scripts/build-app.sh', 'release', '--check')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('SIGNING_IDENTITY', result.stderr)

    def test_version_values_cannot_inject_plist_content(self):
        result = self.run_script('scripts/build-app.sh', 'debug', '--check', APP_VERSION='<bad/>')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('APP_VERSION', result.stderr)

    def test_default_self_distribution_needs_no_apple_credentials(self):
        result = self.run_script('scripts/release.sh', '--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('not notarized', result.stdout)

    def test_preview_build_preflight_needs_no_apple_credentials(self):
        result = self.run_script('scripts/build-app.sh', 'preview', '--check')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unknown_distribution_flag_is_rejected(self):
        result = self.run_script('scripts/release.sh', '--unknown')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Usage:', result.stderr)

    def test_notary_gate_accepts_only_explicit_accepted_status(self):
        with tempfile.TemporaryDirectory() as folder:
            report = Path(folder) / 'report.json'
            for status, expected in [('Accepted', 0), ('Invalid', 1), ('In Progress', 1), (None, 1)]:
                report.write_text(json.dumps({'status': status}))
                result = subprocess.run(['python3', 'scripts/notary-status.py', str(report)], cwd=ROOT, capture_output=True)
                self.assertEqual(result.returncode, expected, status)

if __name__ == '__main__':
    unittest.main()
