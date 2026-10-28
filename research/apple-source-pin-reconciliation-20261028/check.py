#!/usr/bin/env python3
"""Source/hash contracts only. Never starts native builds, CI or fixture execution."""
import ast
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PACKAGE = ROOT / 'research/room-mesh-package-75'
INGRESS = ROOT / 'research/mesh-candidate-ingress-83'
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
EXPECTED = {
    'BlindRoomMesh/Sources/BlindRoomMesh/Bridge.swift': '321a0488cc21b8367779b14898e551ac493af5472724fff74f682d3fa1915095',
    'BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift': '264a44959d812e9db9827644f3b5a6629acaa95d822cf4fe122adc2cb7a5f473',
    'BlindRoomMesh/Sources/CDetour/blind_detour_exclusion.cpp': 'f20ab288f7e6372b1d615c98d0cf2952e6bfed2956aeea5ae616785b68418d0d',
    'BlindRoomMesh/Sources/CDetour/include/blind_detour.h': '4f609d5d7db1e16ea257672d1dba04a178d56bd1d27a514a2bd66cbcf14eaba3',
}

class Contracts(unittest.TestCase):
    def test_exact_55_source_targets_match(self):
        pins = json.loads((PACKAGE / 'APPLE_SOURCE_PINS.json').read_text())
        self.assertEqual(len(pins), 55)
        for path, expected in pins.items():
            self.assertEqual(digest(PACKAGE / path), expected, path)

    def test_only_four_proven_adapted_pins_changed(self):
        old = json.loads((HERE / 'APPLE_SOURCE_PINS.json.before').read_text())
        current = json.loads((PACKAGE / 'APPLE_SOURCE_PINS.json').read_text())
        self.assertEqual(set(old), set(current))
        self.assertEqual({p: current[p] for p in old if current[p] != old[p]}, EXPECTED)
        self.assertEqual(sum(old[p] == current[p] for p in old), 51)

    def test_provenance_binds_current_sources_and_original_old_pins(self):
        report = json.loads((HERE / 'source-reconciliation.json').read_text())
        old = json.loads((HERE / 'APPLE_SOURCE_PINS.json.before').read_text())
        self.assertEqual(report['sourceCommit'], '9284719fe477135d4bcd85b2cbd2a587609ed428')
        self.assertEqual(report['pinBaselineCommit'], 'eb0fc673a72d1c9003cbceb5ef0f68c60e4f5563')
        self.assertEqual(len(report['sourceInventory']), 55)
        for row in report['changedAdaptedSourcePins']:
            self.assertEqual(row['oldSHA256'], old[row['path']])
            self.assertEqual(row['newSHA256'], EXPECTED[row['path']])
            self.assertEqual(row['adaptationCommit'], '4182e99544003abcc4778cf4b15801c4ca93084b')
        for row in report['sourceInventory']:
            self.assertEqual(digest(PACKAGE / row['path']), row['sha256'])

    def test_75_runner_and_required_counts_unchanged(self):
        path = PACKAGE / 'apple/ci.py'
        self.assertEqual(digest(path), '29bac96c47f2352f1b7af52dd6b0217c3238ab5707fa8ac9e7a38f4d8caa7bde')
        source = path.read_text()
        ast.parse(source)
        for text in ["for name,digest in pins.items():assert sha(H/name)==digest,name",
                     "len(a['checks'])==55", "len(b['checks'])==32",
                     "len(b['failureCommitChecks'])==5", "len(b['discardChecks'])==19",
                     "'--configuration','release','--jobs','1'", "FILE_CAP=128<<20", "SCRATCH_CAP=512<<20"]:
            self.assertIn(text, source)

    def test_83_runner_and_required_actual_result_unchanged(self):
        path = INGRESS / 'apple/ci.py'
        self.assertEqual(digest(path), '03fff8f2bf62e1cf2ea2ac5a0a0d2b11c78a17225a5a6314b0a68ff8b6ed92b3')
        source = path.read_text()
        for text in ["verify_pins(ROOT, HOME / 'SOURCE_PINS.json')",
                     "verify_pins(PACKAGE_HOME, PACKAGE_HOME / 'APPLE_SOURCE_PINS.json')",
                     "assert 'RESULT: 83 stage83 real-runtime synthetic checks passed' in fixture_log"]:
            self.assertIn(text, source)

    def test_active_nested_83_manifest_is_coherent(self):
        pins = json.loads((INGRESS / 'SOURCE_PINS.json').read_text())
        self.assertEqual(pins['research/room-mesh-package-75/APPLE_SOURCE_PINS.json'], digest(PACKAGE / 'APPLE_SOURCE_PINS.json'))
        self.assertEqual(len(pins), 14)
        for path, expected in pins.items():
            self.assertEqual(digest(ROOT / path), expected, path)

    def test_existing_verifier_still_rejects_a_changed_file(self):
        # Execute only the inspected pure verifier function, not module imports,
        # platform probes, native commands or main(). No runner is launched.
        tree = ast.parse((INGRESS / 'apple/ci.py').read_text())
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'verify_pins')
        scope = {'hashlib': hashlib, 'json': json}
        exec(compile(ast.Module(body=[function], type_ignores=[]), '<existing pin verifier only>', 'exec'), scope)
        with tempfile.TemporaryDirectory() as d:
            base = Path(d); source = base / 'synthetic.txt'; manifest = base / 'pins.json'
            source.write_text('fixed public synthetic source\n')
            manifest.write_text(json.dumps({'synthetic.txt': digest(source)}))
            scope['verify_pins'](base, manifest)
            source.write_text('changed public synthetic source\n')
            with self.assertRaises(AssertionError):
                scope['verify_pins'](base, manifest)

    def test_existing_workflow_copies_still_match(self):
        self.assertEqual((ROOT / '.github/workflows/native-room-mesh-package.yml').read_bytes(),
                         (PACKAGE / 'apple/native-room-mesh-package.yml').read_bytes())
        self.assertEqual((ROOT / '.github/workflows/mesh-candidate-ingress.yml').read_bytes(),
                         (INGRESS / 'apple/workflow-proposal.yml').read_bytes())

if __name__ == '__main__':
    unittest.main()
