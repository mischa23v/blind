import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
spec = importlib.util.spec_from_file_location('exporter', Path(__file__).parents[1] / 'ci/export-practice-layout-screenshots.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ExportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.source = self.root / 'source'; self.source.mkdir()
        self.output = self.root / 'output'
        self.items = []
        for role in ('button', 'header', 'footer'):
            name = role + '.png'
            (self.source / name).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            self.items.append(dict(suggestedHumanReadableName=f'practice-layout-large-{role}_1_ABCD.png', exportedFileName=name))
    def run_export(self):
        (self.source / 'manifest.json').write_text(json.dumps([dict(attachments=self.items)]))
        module.export(self.source, self.output, 'large')
    def test_only_authored_three(self):
        self.items.append(dict(suggestedHumanReadableName='AutomaticScreenshot.png', exportedFileName='unread.png'))
        self.run_export()
        self.assertEqual(sorted(p.name for p in self.output.iterdir()), ['large-button.png','large-footer.png','large-header.png'])
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

if __name__ == '__main__': unittest.main()
