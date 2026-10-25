"""Local optional adapter failure checks. No manufacturer source in this file."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest

import official_pdf_replay as adapter


class OfficialPDFReplayAdapterTests(unittest.TestCase):
    def private_copy(self, directory):
        original = Path(os.environ["BLIND_REFERENCE_REPLAY_INPUT"]).parent
        target = Path(directory) / "private"
        target.mkdir()
        for name in ["official-reference-input.json", "official-reference-output.json", "extraction-redacted.json"]:
            (target / name).write_bytes((original / name).read_bytes())
        return target

    def test_unexpected_locator_cannot_leak_into_redacted_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            private = self.private_copy(directory)
            path = private / "official-reference-output.json"
            value = json.loads(path.read_text())
            value["chunks"][0]["locator"] = "UNEXPECTED AUTHORED LOCATOR"
            path.write_text(json.dumps(value))
            output = Path(directory) / "redacted.json"
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                adapter.redact(SimpleNamespace(private_output=str(private), evidence_output=str(output)))
            self.assertFalse(output.exists())

    def test_source_modification_is_not_silently_rebaselined(self):
        with tempfile.TemporaryDirectory() as directory:
            private = self.private_copy(directory)
            path = private / "official-reference-input.json"
            value = json.loads(path.read_text())
            value["positive"]["text"] += " AUTHORED MODIFICATION"
            path.write_text(json.dumps(value))
            output = Path(directory) / "redacted.json"
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                adapter.redact(SimpleNamespace(private_output=str(private), evidence_output=str(output)))
            self.assertFalse(output.exists())

    def test_unknown_private_metadata_field_is_not_published(self):
        with tempfile.TemporaryDirectory() as directory:
            private = self.private_copy(directory)
            path = private / "extraction-redacted.json"
            value = json.loads(path.read_text())
            value["rawText"] = "AUTHORED SENTINEL THAT MUST NOT BE PUBLISHED"
            path.write_text(json.dumps(value))
            output = Path(directory) / "redacted.json"
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                adapter.redact(SimpleNamespace(private_output=str(private), evidence_output=str(output)))
            self.assertFalse(output.exists())

    def test_wrong_pdf_bytes_are_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as directory:
            pdf = Path(directory) / "not-the-official-manual.pdf"
            pdf.write_bytes(b"%PDF-AUTHORED-WRONG-BYTES")
            output = Path(directory) / "private"
            with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
                adapter.extract(SimpleNamespace(pdf=str(pdf), private_output=str(output)))
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
