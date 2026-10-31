#!/usr/bin/env python3
"""Portable proposal checks only. No Swift, Xcode, simulator, network or active edits.
Materializes reviewed preimages in a temporary directory and applies the proposal there.
Run explicitly after review: python3 research/native-diagnostics-proposal-20261029/test_proposal.py
"""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = 'ASK_LAYOUT_TRACE schema=1 sequence=1 uptime=123.25 event=appear role=reason category=large frame=((20.0, -1.5), (400.0, 72.0)) provenance=app_callback_not_audit_failure_state'
MARKER = 'ASK_LAYOUT_TRACE truncated=true limit=64'

class Proposal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='blind-diagnostics-proposal-')
        cls.work = Path(cls.temp.name)
        cls.original = {}
        cls.manifest = json.loads((HERE / 'source-hashes.json').read_text())
        for name, hashes in cls.manifest.items():
            if hashes['before_sha256'] is None:
                continue
            data = (ROOT / name).read_bytes()
            if hashlib.sha256(data).hexdigest() != hashes['before_sha256']:
                raise AssertionError('preimage changed: ' + name)
            cls.original[name] = data.decode()
            target = cls.work / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        subprocess.run(['git', 'apply', str(HERE / 'diagnostics-only.patch')], cwd=cls.work, check=True, capture_output=True)
        for name, hashes in cls.manifest.items():
            if hashlib.sha256((cls.work / name).read_bytes()).hexdigest() != hashes['after_sha256']:
                raise AssertionError('postimage mismatch: ' + name)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def extract(self, data):
        source = self.work / 'synthetic.log'
        source.write_bytes(data if isinstance(data, bytes) else data.encode())
        run = subprocess.run(['python3', 'tools/ci/extract-ask-layout-trace.py', str(source)], cwd=self.work, capture_output=True, text=True, timeout=10)
        self.assertEqual(run.returncode, 0)
        self.assertEqual(run.stderr, '')
        return run.stdout

    def test_closed_grammar_accepts_known_metadata(self):
        for category in ['xSmall','small','medium','large','xLarge','xxLarge','xxxLarge'] + ['accessibility'+str(i) for i in range(1,6)]:
            for event in ['appear','disappear','category','geometry']:
                for role in ['reason','ask-form']:
                    line = BASE.replace('category=large','category='+category).replace('event=appear','event='+event).replace('role=reason','role='+role)
                    self.assertIn(line+'\n', self.extract(line+'\n'))

    def test_unknown_formats_and_private_text_never_pass(self):
        variants = [BASE+' label=PRIVATE_SENTINEL', BASE.replace('role=reason','role=PRIVATE_SENTINEL'), BASE.replace('category=large','category=futureCategory'), BASE.replace('20.0','NaN'), BASE.replace('20.0','inf'), BASE.replace('schema=1','schema=2'), BASE.replace('sequence=1','sequence=65'), 'prefix '+BASE, BASE.replace('frame=((', 'frame={'), BASE+'\x00PRIVATE_SENTINEL', BASE.replace('123.25','1000000001'), BASE.replace('123.25','-1'), BASE.replace('400.0','-1'), BASE.replace('400.0','1000001'), BASE.replace('20.0','1000001'), BASE.replace('72.0','-1'), BASE.replace('123.25','9'*400)]
        result = self.extract('\n'.join(variants)+'\n')
        self.assertNotIn('PRIVATE_SENTINEL', result)
        self.assertNotIn('ASK_LAYOUT_TRACE schema=', result)
        self.assertIn('records=0', result)
        self.assertNotIn('passed', result.lower())
        self.assertIn('status=unavailable', result)
        self.assertIn('ui_outcome=not_inferred', result)

    def test_line_limit_and_recovery(self):
        result = self.extract('PRIVATE_SENTINEL' * 300 + '\n' + BASE + '\n')
        self.assertNotIn('PRIVATE_SENTINEL', result)
        self.assertEqual(result.count('ASK_LAYOUT_TRACE schema='), 1)
        self.assertNotIn(BASE, self.extract(BASE)) # Unterminated record unavailable.
        self.assertNotIn(BASE, self.extract(b'\xff'+BASE.encode()+b'\n'))

    def test_output_and_scan_bounds(self):
        result = self.extract((BASE+'\n')*100 + (MARKER+'\n')*3)
        self.assertEqual(result.count('ASK_LAYOUT_TRACE schema='),64)
        self.assertEqual(result.count(MARKER),1)
        self.assertIn('dropped_valid_records=36',result)
        self.assertIn('status=partial',result)
        self.assertLessEqual(len(result.splitlines()),67)
        self.assertTrue(all(len(line)<=2048 for line in result.splitlines()))
        result = self.extract(b'x'*(8*1024*1024) + b'\n' + BASE.encode()+b'\n')
        self.assertIn('scan_budget_reached=true',result)
        self.assertNotIn(BASE,result)

    def test_old_end_anchored_cpu_receipt_and_parser_unchanged(self):
        shell = 'tools/ci/native-apple.sh'
        after = (self.work / shell).read_text()
        oldgrep = next(x for x in self.original[shell].splitlines() if 'grep -E' in x and '^CLASSIFICATION_WORKER_CPU ' in x)
        self.assertIn(oldgrep,after)
        self.assertIn('records=([0-9]|[1-5][0-9]|6[0-4])$',oldgrep)
        for name in ['ClassificationIngressTests.swift','ClassifiedRoomMeshTests.swift']:
            path = 'ios/BlindAssistTests/'+name
            before = next(x for x in self.original[path].splitlines() if 'print("CLASSIFICATION_WORKER_CPU ' in x)
            self.assertIn(before,(self.work/path).read_text())
        pattern = r'^CLASSIFICATION_DIAGNOSTIC_LOCK lane=(ingress83|runtime75) records=([0-9]|[1-5][0-9]|6[0-4]) max_wait_us=[0-9]{1,15}$'
        for lane in ['ingress83','runtime75']:
            self.assertIsNotNone(re.fullmatch(pattern,f'CLASSIFICATION_DIAGNOSTIC_LOCK lane={lane} records=64 max_wait_us=123'))
        self.assertIsNone(re.fullmatch(pattern,'CLASSIFICATION_DIAGNOSTIC_LOCK lane=ingress83 records=1 max_wait_us='+'9'*16))
        for suffix in [' label=PRIVATE_SENTINEL',' extra=1','\nPRIVATE_SENTINEL']:
            self.assertIsNone(re.fullmatch(pattern,'CLASSIFICATION_DIAGNOSTIC_LOCK lane=ingress83 records=1 max_wait_us=1'+suffix))

    def test_timing_only_inside_debug_and_prelock(self):
        path = 'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift'
        before = self.original[path]
        after = (self.work/path).read_text()
        start = after.index(' private func recordDiagnosticStage(')
        body = after[start:after.index(' private func diagnosticRecorder()',start)]
        self.assertLess(body.index('let sampledAt='),body.index('locked {'))
        self.assertLess(body.index('let cpu='),body.index('locked {'))
        self.assertLess(body.index('let lockRequestedAt='),body.index('locked {'))
        self.assertGreater(body.index('let lockAcquiredAt='),body.index('locked {'))
        self.assertIn('(sampledAt-startedAt)',body)
        self.assertIn('(lockAcquiredAt-lockRequestedAt)',body)
        self.assertIn('diagnosticReceipts.count<64',body)
        # Only the identified DEBUG block may differ, not operational code/defaults.
        left = before.index('#if DEBUG\n /// Explicit synthetic-test opt-in.')
        right = before.index(' private func locked<T>',left)
        aleft = after.index('#if DEBUG\n /// Explicit synthetic-test opt-in.')
        aright = after.index(' private func locked<T>',aleft)
        self.assertEqual(before[:left],after[:aleft])
        self.assertEqual(before[right:],after[aright:])
        self.assertTrue(after[aleft:aright].rstrip().endswith('#endif'))

    def test_ui_exit_status_preserved_with_extractor_failure(self):
        text = (self.work/'tools/ci/native-apple.sh').read_text()
        harness = self.work/'logger-harness.sh'
        harness.write_text(text.split('\ncase "$mode" in',1)[0]+'\nrun_logged ui bash -c "$SYNTHETIC_COMMAND"\n')
        env = dict(os.environ, RUNNER_TEMP=str(self.work/'runner'))
        extractor = self.work/'tools/ci/extract-ask-layout-trace.py'
        saved = extractor.read_bytes()
        try:
            for broken in [False,True]:
                extractor.write_bytes(b'raise SystemExit(9)\n' if broken else saved)
                for code in [0,7]:
                    env['SYNTHETIC_COMMAND'] = "printf '%s\\n' '"+BASE+"'; exit "+str(code)
                    run = subprocess.run(['bash',str(harness),'ui'],cwd=self.work,env=env,capture_output=True,text=True,timeout=10)
                    self.assertEqual(run.returncode,code)
        finally:
            extractor.write_bytes(saved)

if __name__ == '__main__':
    unittest.main(verbosity=2)
