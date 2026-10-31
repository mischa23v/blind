#!/usr/bin/env python3
"""Execute the early workflow shell with REAL exporter code and bounded stubs.

Only git provenance replies and xcresulttool JSON are synthetic. The summary
writer, case parser, count reconciliation, log witness, optional attachment
collector, source-hash reads, and final artifact encoder execute unchanged.
This tests reporting order, not Apple execution or real checkout provenance.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / '.github/workflows/native-apple.yml'
STEP = 'Extract bounded hosted-unit case statuses before UI tests'
SHA = 'a' * 40
TARGET = 'IndoorGoalContinuityTests/testTrackingLossStillInvalidatesRetainedMapFrame'
SENTINEL = 'PRIVATE_SUMMARY_FIELD_MUST_NOT_ESCAPE'


def workflow_command(path=WORKFLOW):
    """Read the actual unchanged step name/run block; do not duplicate its fix."""
    source = path.read_text()
    match = re.search(r'^      - name: ' + re.escape(STEP) + r'\n(?P<body>.*?)(?=^      - name: |\Z)',
                      source, re.M | re.S)
    if match is None:
        raise AssertionError('Missing exact early reporting step')
    body = match['body']
    run = re.search(r'^        run: (?P<inline>[^\n]*)\n(?P<block>(?:          [^\n]*\n)*)', body, re.M)
    if run is None:
        raise AssertionError('Unsupported early reporting run schema')
    return ('\n'.join(line[10:] for line in run['block'].splitlines()) + '\n'
            if run['inline'] == '|' else run['inline'] + '\n')


STUB = '''import json,os,pathlib,sys
args=sys.argv[1:]
tool=pathlib.Path(sys.argv[0]).name
out=pathlib.Path(os.environ['RUNNER_TEMP'])/'blind-native-ci'
record={'tool':tool,'args':args,'summaryExists':(out/'unit-summary.json').is_file()}
with open(os.environ['CALLS'],'a') as stream:stream.write(json.dumps(record)+'\\n')
if tool=='git':
    assert args[:2]==['-C',os.environ['FIXTURE_REPO']]
    command=args[2:]
    if command==['rev-parse','HEAD']:
        print(('b' if os.environ.get('BAD_HEAD') else 'a')*40)
    elif command==['diff','--quiet','HEAD','--']:
        pass
    else:
        assert command==['status','--porcelain=v1','-z','--untracked-files=all','--',
                         'ios','BlindCore','BlindMemory','tools/ci','.github/workflows']
elif tool=='xcrun':
    assert args[:3]==['xcresulttool','get','test-results']
    assert args[3] in ('summary','tests')
    assert args[4:]==['--path',str(out/'unit.xcresult'),'--compact']
    if not (out/'unit.xcresult').is_dir():sys.exit(4)
    if args[3]=='summary' and os.environ.get('SUMMARY_FAILURE'):
        print('PRIVATE_SUMMARY_FIELD_MUST_NOT_ESCAPE',file=sys.stderr)
        sys.exit(9)
    print(pathlib.Path(os.environ['SUMMARY_JSON'] if args[3]=='summary' else os.environ['TESTS_JSON']).read_text())
else:
    raise AssertionError('Unexpected tool')
'''


class EarlySummaryIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='blind-early-summary-test-')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / 'repo'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.out = self.base / 'runner' / 'blind-native-ci'
        self.out.mkdir(parents=True)
        (self.out / 'unit.xcresult').mkdir()
        # Use exact production bytes, not a hand-written collector imitation.
        for relative in ('tools/ci/export-native-unit-statuses.py',
                         'tools/ci/native-route-diagnostic-evidence.py',
                         'research/indoor-io-buffered-diagnostic/resolution.py'):
            destination = self.repo / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
            self.assertEqual(destination.read_bytes(), (ROOT / relative).read_bytes())
        for relative in ('ios/BlindAssistTests/CommunityTests.swift', 'ios/BlindAssist/SpatialMapIO.swift'):
            destination = self.repo / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text('// Controlled provenance fixture, not native source execution.\n')
        (self.out / 'unit.log').write_text(
            "Test Case '-[IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' started.\n"
            "Test Case '-[IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' passed (0.1 seconds).\n")
        self.summary = {'result':'Failed','totalTestCount':3,'passedTests':1,'failedTests':1,
                        'skippedTests':1,'expectedFailures':0,'privateCameraHistory':SENTINEL}
        self.cases = [
            {'nodeType':'Test Case','nodeIdentifier':TARGET+'()','result':'Passed'},
            {'nodeType':'Test Case','nodeIdentifier':'SyntheticReportingTests/testFailure()','result':'Failed'},
            {'nodeType':'Test Case','nodeIdentifier':'SyntheticReportingTests/testSkip()','result':'Skipped'}]
        self.summary_path = self.base / 'synthetic-summary.json'
        self.tests_path = self.base / 'synthetic-tests.json'
        self.calls = self.base / 'calls.jsonl'
        self.env = dict(os.environ, PATH=str(self.bin)+os.pathsep+os.environ.get('PATH',''),
                        RUNNER_TEMP=str(self.base/'runner'), FIXTURE_REPO=str(self.repo),
                        GITHUB_SHA=SHA, CALLS=str(self.calls), SUMMARY_JSON=str(self.summary_path),
                        TESTS_JSON=str(self.tests_path), PYTHONDONTWRITEBYTECODE='1')
        for name in ('git','xcrun'):
            script = self.bin / name
            script.write_text('#!'+sys.executable+'\n'+STUB)
            script.chmod(0o755)

    def execute(self, command=None):
        self.summary_path.write_text(json.dumps(self.summary))
        self.tests_path.write_text(json.dumps({'testNodes':self.cases}))
        completed = subprocess.run(['bash','--noprofile','--norc','-e','-o','pipefail','-c',
                                    workflow_command() if command is None else command],
                                   cwd=self.repo, env=self.env, capture_output=True, text=True, timeout=10)
        self.assertLess(len(completed.stdout.encode())+len(completed.stderr.encode()),1024*1024)
        result = json.loads((self.out/'unit-case-statuses.json').read_text())
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        return completed, result, calls

    def assert_incomplete(self, result):
        self.assertFalse(result['complete'])
        self.assertFalse(result['target_pass_verified'])
        self.assertFalse(result['source_verified'])
        self.assertEqual(result['routeDiagnosticEvidence']['status'],'source_or_cases_unverified')

    def test_current_workflow_writes_summary_before_real_case_reconciliation(self):
        self.assertFalse((self.out/'unit-summary.json').exists())
        completed, result, calls = self.execute()
        self.assertEqual(completed.returncode,0,completed.stderr)
        self.assertTrue(result['complete'])
        self.assertTrue(result['source_verified']) # Controlled git reply, NOT real provenance evidence.
        self.assertTrue(result['target_pass_verified']) # Only synthetic exact target/log witness.
        self.assertEqual(result['case_count'],3)
        self.assertEqual(result['counts'],{'Passed':1,'Failed':1,'Skipped':1,'Expected Failure':0})
        self.assertEqual([case['result'] for case in result['cases']],['Passed','Failed','Skipped'])
        queries = [call for call in calls if call['tool']=='xcrun']
        self.assertEqual([call['args'][3] for call in queries],['summary','tests'])
        self.assertFalse(queries[0]['summaryExists'])
        self.assertTrue(queries[1]['summaryExists'])
        self.assertEqual(result['routeDiagnosticEvidence']['status'],'not_observed')
        # No suite/all-test attachment export, no UI query, no diagnostic source read.
        self.assertTrue(all(call['args'][:3]==['xcresulttool','get','test-results'] for call in queries))
        sanitized = json.loads((self.out/'unit-summary.json').read_text())
        self.assertNotIn('privateCameraHistory',sanitized)
        self.assertNotIn(SENTINEL,completed.stdout+completed.stderr+json.dumps(result))

    def test_previous_three_argument_only_flow_stays_incomplete_without_summary(self):
        command = workflow_command(Path(__file__).with_name('native-apple.before.yml'))
        completed, result, calls = self.execute(command)
        self.assertEqual(completed.returncode,0) # Historical || true masked only shell failure.
        self.assert_incomplete(result)
        self.assertEqual(result['error_type'],'FileNotFoundError')
        self.assertFalse((self.out/'unit-summary.json').exists())
        self.assertEqual([call['args'][3] for call in calls if call['tool']=='xcrun'],['tests'])
        # Preserve the actual collector's own nonzero failure too, separately
        # from the exact historical workflow's reporting-only shell fallback.
        self.assertTrue(command.endswith(' || true\n'))
        completed, result, _ = self.execute(command.removesuffix(' || true\n')+'\n')
        self.assertEqual(completed.returncode,1)
        self.assert_incomplete(result)

    def test_mismatched_aggregate_is_not_relaxed_by_workflow_fix(self):
        self.summary['failedTests']=2
        completed, result, _ = self.execute()
        self.assertEqual(completed.returncode,0) # Existing || true keeps evidence flow; verdict stays false.
        self.assert_incomplete(result)
        self.assertIn('Case counts disagree with summary: failedTests',result['error'])

    def test_failed_summary_overwrites_stale_success_and_keeps_error_private(self):
        (self.out/'unit-summary.json').write_text(json.dumps(self.summary))
        self.env['SUMMARY_FAILURE']='1'
        completed, result, calls = self.execute()
        self.assertEqual(completed.returncode,0)
        self.assert_incomplete(result)
        summary = json.loads((self.out/'unit-summary.json').read_text())
        self.assertFalse(summary['complete'])
        self.assertNotIn('totalTestCount',summary)
        self.assertEqual([call['args'][3] for call in calls if call['tool']=='xcrun'],['summary','tests'])
        self.assertNotIn(SENTINEL,completed.stdout+completed.stderr+json.dumps(result)+json.dumps(summary))

    def test_missing_bundle_skips_summary_but_never_claims_complete(self):
        (self.out/'unit.xcresult').rmdir()
        completed, result, calls = self.execute()
        self.assertEqual(completed.returncode,0)
        self.assert_incomplete(result)
        self.assertFalse((self.out/'unit-summary.json').exists())
        self.assertEqual([call['args'][3] for call in calls if call['tool']=='xcrun'],['tests'])

    def test_source_head_mismatch_still_blocks_real_collector(self):
        self.env['BAD_HEAD']='1'
        completed, result, calls = self.execute()
        self.assertEqual(completed.returncode,0)
        self.assert_incomplete(result)
        self.assertIn('Checkout HEAD differs from workflow SHA',result['error'])
        self.assertEqual([call['args'][3] for call in calls if call['tool']=='xcrun'],['summary'])


if __name__ == '__main__':
    unittest.main()
