import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('exporter', Path(__file__).parents[1] / 'ci/export-practice-layout-screenshots.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

ROLES = ('button', 'header', 'footer', 'footer-end', 'ask-action', 'ask-reason', 'ask-reason-end')

class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'; self.source.mkdir()
        self.output = self.root / 'output'
        self.items = []
        for role in ROLES:
            name = role + '.png'
            (self.source / name).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            self.items.append(dict(suggestedHumanReadableName=f'practice-layout-large-{role}_1_ABCD.png', exportedFileName=name))
    def run_export(self, size='large'):
        (self.source / 'manifest.json').write_text(json.dumps([dict(attachments=self.items)]))
        module.export(self.source, self.output, size)
    def test_only_authored_seven(self):
        self.items.append(dict(suggestedHumanReadableName='AutomaticScreenshot.png', exportedFileName='unread.png'))
        self.run_export()
        self.assertEqual(sorted(p.name for p in self.output.iterdir()), sorted('large-' + role + '.png' for role in ROLES))
    def test_missing_role_fails(self):
        self.items.pop()
        with self.assertRaisesRegex(ValueError, 'Missing authored'): self.run_export()
    def test_empty_fails(self):
        self.items=[]
        with self.assertRaisesRegex(ValueError, 'Missing authored'): self.run_export()
    def test_duplicate_fails(self):
        self.items.append(self.items[0])
        with self.assertRaisesRegex(ValueError, 'Duplicate'): self.run_export()
    def test_traversal_fails(self):
        self.items[0]['exportedFileName']='../button.png'
        with self.assertRaisesRegex(ValueError, 'flat PNG'): self.run_export()
    def test_nonpng_fails(self):
        (self.source/'button.png').write_bytes(b'not an image')
        with self.assertRaisesRegex(ValueError, 'PNG signature'): self.run_export()
    def test_missing_manifest_fails(self):
        with self.assertRaises(FileNotFoundError): module.export(self.source,self.output,'large')
    def test_missing_exported_file_fails(self):
        (self.source/'button.png').unlink()
        with self.assertRaises(FileNotFoundError): self.run_export()
    def test_unrelated_name_does_not_satisfy_role(self):
        self.items[0]['suggestedHumanReadableName']='practice-layout-large-buttonOther.png'
        with self.assertRaisesRegex(ValueError,'Missing authored'): self.run_export()
    def test_stale_output_fails(self):
        self.run_export()
        with self.assertRaisesRegex(ValueError,'stale/duplicate'): self.run_export()

    def test_exact_roles_at_largest_size(self):
        size = 'accessibility-extra-extra-extra-large'
        for item in self.items:
            item['suggestedHumanReadableName'] = item['suggestedHumanReadableName'].replace('practice-layout-large-', 'practice-layout-' + size + '-')
        self.run_export(size)
        self.assertEqual(sorted(p.name for p in self.output.iterdir()), sorted(size + '-' + role + '.png' for role in ROLES))
    def test_every_missing_role_fails(self):
        original = list(self.items)
        for role in ROLES:
            self.items = [item for item in original if item['exportedFileName'] != role + '.png']
            with self.assertRaisesRegex(ValueError, 'Missing authored'): self.run_export()
    def test_symlink_rejected(self):
        path = self.source / 'ask-reason-end.png'; path.unlink()
        target = self.root / 'outside.png'; target.write_bytes(b'\x89PNG\r\n\x1a\nfixture'); path.symlink_to(target)
        with self.assertRaisesRegex(ValueError, 'escapes'): self.run_export()
    def test_unknown_schema_rejected(self):
        (self.source / 'manifest.json').write_text('{}')
        with self.assertRaises(ValueError): module.export(self.source, self.output, 'large')
    def test_unknown_size_rejected(self):
        with self.assertRaisesRegex(ValueError, 'Unexpected size'): self.run_export('made-up-size')
    def test_wrong_size_cannot_fill_missing_role(self):
        self.items[-1]['suggestedHumanReadableName'] = 'practice-layout-accessibility-extra-extra-extra-large-ask-reason-end.png'
        with self.assertRaisesRegex(ValueError, 'Missing authored'): self.run_export()

if __name__ == '__main__': unittest.main()
