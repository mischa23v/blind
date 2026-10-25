import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('audit_export', Path(__file__).parents[1] / 'ci/export-full-audit-evidence.py')
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'export'; self.source.mkdir()
        self.destination = self.root / 'artifacts'
        self.items = []

    def add(self, role):
        filename = role + '.png'
        (self.source / filename).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        self.items.append({'suggestedHumanReadableName': 'full-audit-' + role + '_1_ABCD.png',
                           'exportedFileName': filename})

    def run_export(self):
        (self.source / 'manifest.json').write_text(json.dumps([{'attachments': self.items}]))
        return module.collect(self.source, self.destination)

    def test_camera_pair_ask_absent_explicit(self):
        for role in module.ROLES[:2]: self.add(role)
        result = self.run_export()
        self.assertTrue(result['evidenceComplete'])
        self.assertEqual(result['phases']['ask']['status'], 'not_observed')
        self.assertEqual(len(result['screenshots']), 2)

    def test_all_four_exact_named(self):
        for role in module.ROLES: self.add(role)
        self.items.append({'suggestedHumanReadableName': 'automatic.png', 'exportedFileName': 'missing.png'})
        result = self.run_export()
        self.assertTrue(result['evidenceComplete']); self.assertEqual(len(result['screenshots']), 4)

    def test_partial_ask_fails_retains_three(self):
        for role in module.ROLES[:3]: self.add(role)
        result = self.run_export()
        self.assertFalse(result['evidenceComplete']); self.assertEqual(len(result['screenshots']), 3)
        self.assertEqual(result['phases']['ask']['missingRoles'], ['ask-after'])

    def test_missing_camera_fails_retains_available(self):
        self.add('camera-before')
        result = self.run_export()
        self.assertFalse(result['evidenceComplete']); self.assertEqual(len(result['screenshots']), 1)

    def test_duplicate_fails_retains_valid_unique(self):
        for role in module.ROLES[:2]: self.add(role)
        self.items.append(self.items[0])
        result = self.run_export()
        self.assertFalse(result['evidenceComplete']); self.assertEqual(len(result['screenshots']), 2)

    def test_path_escape_rejected_but_other_retained(self):
        for role in module.ROLES[:2]: self.add(role)
        self.items[0]['exportedFileName'] = '../other.png'
        result = self.run_export()
        self.assertFalse(result['evidenceComplete']); self.assertEqual(result['screenshots'], ['full-audit-camera-after.png'])

    def test_bad_png_rejected(self):
        for role in module.ROLES[:2]: self.add(role)
        (self.source / 'camera-before.png').write_bytes(b'bad')
        self.assertFalse(self.run_export()['evidenceComplete'])

    def test_symlink_rejected(self):
        for role in module.ROLES[:2]: self.add(role)
        path = self.source / 'camera-before.png'; path.unlink(); path.symlink_to(self.source / 'camera-after.png')
        self.assertFalse(self.run_export()['evidenceComplete'])

    def test_oversized_fails_and_remains_bounded(self):
        for role in module.ROLES[:2]: self.add(role)
        with (self.source / 'camera-before.png').open('ab') as stream: stream.truncate(module.MAX_BYTES + 1)
        result = self.run_export()
        self.assertFalse(result['evidenceComplete']); self.assertLessEqual(result['screenshotBytes'], module.MAX_BYTES)
        self.assertEqual(result['screenshots'], ['full-audit-camera-after.png'])

    def test_missing_manifest_explicit_json(self):
        result = module.collect(self.source, self.destination)
        self.assertFalse(result['evidenceComplete']); self.assertTrue((self.destination / 'evidence.json').exists())

    def test_export_failure_explicit_json(self):
        result = module.collect(self.source, self.destination, 'Missing xcresult')
        self.assertFalse(result['evidenceComplete']); self.assertEqual(result['errors'], ['Missing xcresult'])


if __name__ == '__main__': unittest.main()
