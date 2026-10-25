"""Portable exporter tests with mocked xcresulttool; never execute Apple tools."""
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch
import io
import json
import runpy
import subprocess
import sys
import tempfile
import unittest

PACKET = Path(__file__).resolve().parent
PASS = {'totalTestCount': 14, 'passedTests': 14, 'failedTests': 0, 'skippedTests': 0}


class ReceiptTests(unittest.TestCase):
    def export(self, summary=PASS, status=0, bundle=True, raw=None, error=None, log=''):
        with tempfile.TemporaryDirectory(prefix='selected-pdf-export-') as directory:
            out = Path(directory)
            if bundle:
                (out / 'probe.xcresult').mkdir()
            (out / 'test.log').write_text(log)
            returned = subprocess.CompletedProcess([], 0, raw if raw is not None else json.dumps(summary).encode(), b'')
            args = ['export-receipt.py', str(out), str(PACKET / 'source-pins.json'), str(status)]
            with patch.object(sys, 'argv', args), patch('subprocess.run', return_value=returned, side_effect=error) as native:
                with redirect_stdout(io.StringIO()), self.assertRaises(SystemExit) as caught:
                    runpy.run_path(str(PACKET / 'export-receipt.py'), run_name='__main__')
            receipt = json.loads((out / 'artifacts/receipt.json').read_text())
            files = {p.name: p.read_bytes() for p in (out / 'artifacts').iterdir()}
            return caught.exception.code, receipt, files, native.call_count

    def testExactFourteenPassesAcceptedWithoutInflatingScope(self):
        code, receipt, _, calls = self.export()
        self.assertEqual(code, 0); self.assertTrue(receipt['accepted']); self.assertEqual(calls, 1)
        for key in ['appControllerAcceptance', 'osPickerGrantAcceptance', 'voiceOverOrAudioAcceptance', 'participantAcceptance']:
            self.assertFalse(receipt[key])

    def testZeroExecutedCannotPass(self):
        code, receipt, _, _ = self.export({key: 0 for key in PASS})
        self.assertEqual(code, 1); self.assertFalse(receipt['accepted'])

    def testSkipCannotPass(self):
        code, receipt, _, _ = self.export(dict(PASS, passedTests=13, skippedTests=1))
        self.assertEqual(code, 1); self.assertFalse(receipt['accepted'])

    def testFailureExitCannotPassEvenWithSuccessCounts(self):
        code, receipt, _, _ = self.export(status=65)
        self.assertEqual(code, 1); self.assertFalse(receipt['accepted'])

    def testMissingBundleIsNotNativeSuccess(self):
        code, receipt, _, calls = self.export(bundle=False)
        self.assertEqual(code, 1); self.assertTrue(receipt['summaryUnavailable']); self.assertEqual(calls, 0)

    def testMalformedSummaryPreservesFailedReceipt(self):
        code, receipt, _, _ = self.export(raw=b'not json')
        self.assertEqual(code, 1); self.assertTrue(receipt['summaryUnavailable'])

    def testSummaryTimeoutPreservesFailedReceipt(self):
        code, receipt, _, _ = self.export(error=subprocess.TimeoutExpired('mocked-xcrun', 30))
        self.assertEqual(code, 1); self.assertTrue(receipt['summaryUnavailable'])

    def testUTF8DiagnosticTailHasByteBoundAndNoAttachmentExport(self):
        code, _, files, _ = self.export(log=('نص اختباري ' * 500 + '\n') * 100)
        self.assertEqual(code, 0)
        self.assertLessEqual(len(files['bounded-test.log.txt']), 32 * 1024)
        self.assertEqual(set(files), {'receipt.json', 'bounded-test.log.txt'})


if __name__ == '__main__':
    unittest.main()
