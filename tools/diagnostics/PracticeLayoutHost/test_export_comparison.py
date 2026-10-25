import json
from pathlib import Path
import tempfile
import unittest

from export_comparison import export


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'; self.source.mkdir()
        self.destination = self.root / 'images'
        self.prefix = 'comparison-A-dynamicType-1'
        self.records = []
        for role in ('before', 'after'):
            filename = role + '.png'
            (self.source / filename).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            self.records.append({'suggestedHumanReadableName': self.prefix + '-' + role + '_1_ABC.png',
                                 'exportedFileName': filename})

    def run_export(self):
        (self.source / 'manifest.json').write_text(json.dumps([{'attachments': self.records}]))
        return export(self.source, self.destination, self.prefix)

    def test_author_allowlist_ignores_automatic(self):
        self.records.append({'suggestedHumanReadableName': 'AutomaticScreenshot.png', 'exportedFileName': 'absent.png'})
        result = self.run_export()
        self.assertEqual(result, [self.prefix + '-before.png', self.prefix + '-after.png'])

    def test_missing_fails(self):
        self.records.pop()
        with self.assertRaisesRegex(ValueError, 'Missing authored'): self.run_export()

    def test_duplicate_fails(self):
        self.records.append(self.records[0])
        with self.assertRaisesRegex(ValueError, 'Duplicate'): self.run_export()

    def test_stale_fails(self):
        self.run_export()
        with self.assertRaisesRegex(ValueError, 'stale'): self.run_export()

    def test_path_escape_fails(self):
        self.records[0]['exportedFileName'] = '../before.png'
        with self.assertRaisesRegex(ValueError, 'filename'): self.run_export()

    def test_symlink_fails(self):
        (self.source / 'before.png').unlink()
        (self.source / 'before.png').symlink_to(self.source / 'after.png')
        with self.assertRaisesRegex(ValueError, 'escapes'): self.run_export()

    def test_bad_png_fails(self):
        (self.source / 'before.png').write_bytes(b'not PNG')
        with self.assertRaisesRegex(ValueError, 'signature'): self.run_export()

    def test_missing_manifest_fails(self):
        with self.assertRaises(FileNotFoundError): export(self.source, self.destination, self.prefix)

    def test_unknown_schema_fails(self):
        (self.source / 'manifest.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'entries'): export(self.source, self.destination, self.prefix)

    def test_per_case_bytes_fail(self):
        with (self.source / 'before.png').open('ab') as stream: stream.truncate(16 * 1024 * 1024)
        with self.assertRaisesRegex(ValueError, '16 MiB'): self.run_export()

    def test_count_limit_fails(self):
        self.destination.mkdir()
        for i in range(29): (self.destination / f'{i}.png').write_bytes(b'x')
        with self.assertRaisesRegex(ValueError, '30 PNG'): self.run_export()

    def test_total_bytes_limit_fails(self):
        self.destination.mkdir()
        with (self.destination / 'existing.png').open('wb') as stream: stream.truncate(24 * 1024 * 1024)
        with self.assertRaisesRegex(ValueError, '24 MiB'): self.run_export()

    def test_all_prefixes(self):
        for variant in 'ABC':
            for suffix in ('dynamicType-1', 'dynamicType-2', 'hitRegion-1', 'hitRegion-2', 'endpoint'):
                prefix = f'comparison-{variant}-{suffix}'
                for record in self.records:
                    record['suggestedHumanReadableName'] = record['suggestedHumanReadableName'].replace(self.prefix, prefix)
                self.prefix = prefix
                self.run_export()
        self.assertEqual(len(list(self.destination.glob('*.png'))), 30)


if __name__ == '__main__':
    unittest.main()
