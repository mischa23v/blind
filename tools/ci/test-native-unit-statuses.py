#!/usr/bin/env python3
"""Synthetic metadata parser fixtures, not native XCTest executions."""
import importlib.util
from pathlib import Path
import sys
import tempfile
import contextlib
import io
import json
import os
import shutil
import time
from unittest.mock import patch
import unittest

spec = importlib.util.spec_from_file_location('exporter', Path(__file__).with_name('export-native-unit-statuses.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def case(status='Passed', identifier=m.TARGET + '()'):
    return {'nodeType': 'Test Case', 'nodeIdentifier': identifier, 'result': status}

def root(*nodes):
    return {'testNodes': [{'nodeType': 'Test Suite', 'children': list(nodes)}]}

class EvidenceTests(unittest.TestCase):
    def test_counts_match(self):
        counts=m.reconcile(m.cases_from(root(case())), {'totalTestCount':1,'passedTests':1,'failedTests':0,'skippedTests':0,'expectedFailures':0})
        self.assertEqual(counts['Passed'],1)
    def test_counts_mismatch_rejected(self):
        with self.assertRaises(ValueError):m.reconcile(m.cases_from(root(case())), {'totalTestCount':155,'passedTests':148,'failedTests':5,'skippedTests':2,'expectedFailures':0})
    def test_target_pass_record(self):
        self.assertEqual(m.target_records(m.cases_from(root(case()))), [{'identifier':m.TARGET+'()', 'result':'Passed'}])
    def test_prefixed_identifier(self):
        self.assertEqual(len(m.target_records(m.cases_from(root(case(identifier='BlindAssistTests/'+m.TARGET))))),1)
    def test_similar_name_not_target(self):
        self.assertEqual(m.target_records(m.cases_from(root(case(identifier=m.TARGET+'Extra()')))),[])
    def test_failure_and_skip_retained(self):
        self.assertEqual([x['result'] for x in m.cases_from(root(case('Failed'),case('Skipped')))],['Failed','Skipped'])
    def test_duplicate_not_collapsed(self):
        self.assertEqual(len(m.target_records(m.cases_from(root(case(),case())))),2)
    def test_parameterized_children_not_added(self):
        node=case('Failed');node['children']=[case(),case()]
        self.assertEqual(len(m.cases_from(root(node))),1)
    def test_unknown_schema_rejected(self):
        for p in [{},[],{'testNodes':None}]:
            with self.assertRaises(ValueError):m.cases_from(p)
    def test_unknown_status_rejected(self):
        for status in [None,[], 'Maybe','Success']:
            with self.assertRaises(ValueError):m.cases_from(root(case(status)))
    def test_empty_rejected(self):
        with self.assertRaises(ValueError):m.cases_from(root())
    def test_deep_rejected(self):
        n=case()
        for _ in range(34):n={'children':[n]}
        with self.assertRaises(ValueError):m.cases_from(root(n))
    def test_bad_identifier_rejected(self):
        with self.assertRaises(ValueError):m.cases_from(root(case(identifier='x'*513)))
    def test_witness_exact(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'log';p.write_text("Test Case '-[BlindAssistTests.IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' started.\nTest Case '-[BlindAssistTests.IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' passed (0.1 seconds).\n")
            self.assertEqual(m.log_witness(p),['started','passed'])
    def test_failed_witness_not_passed(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'log';p.write_text("Test Case '-[IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' failed (10.1 seconds).\n")
            self.assertEqual(m.log_witness(p),['failed'])
    def test_query_success(self):
        self.assertEqual(m.query([sys.executable,'-c','print("ok")']),b'ok\n')
    def test_query_exit_failure(self):
        with self.assertRaises(ValueError):m.query([sys.executable,'-c','raise SystemExit(2)'])
    def test_query_timeout(self):
        with self.assertRaises(ValueError):m.query([sys.executable,'-c','import time;time.sleep(1)'],seconds=.05)
    def test_query_cap(self):
        with self.assertRaises(ValueError):m.query([sys.executable,'-c','import sys;sys.stdout.write("x"*5000000)'])

class AdversarialTests(unittest.TestCase):
    def test_app_prefixed_witness_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'log';p.write_text("APP OUTPUT Test Case '-[IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' passed (0.1 seconds).\n")
            self.assertEqual(m.log_witness(p),[])
    def test_long_line_read_bounded(self):
        class Stream:
            def __enter__(self):return self
            def __exit__(self,*args):pass
            def readline(self,size):
                self.assertion = size
                assert size == 1024*1024+1
                return b'x'*size
        with patch('builtins.open',return_value=Stream()):
            with self.assertRaises(ValueError):m.log_witness('unused')
    @unittest.skipUnless(hasattr(os,'fork'),'POSIX child process fixture')
    def test_exited_leader_descendant_is_killed(self):
        with tempfile.TemporaryDirectory() as d:
            marker=Path(d)/'survived'
            code="import os,time,pathlib; pid=os.fork();\nif pid: os._exit(0)\ntime.sleep(.4);pathlib.Path("+repr(str(marker))+").write_text('survived')"
            with self.assertRaises(ValueError):m.query([sys.executable,'-c',code],seconds=.15)
            time.sleep(.45)
            self.assertFalse(marker.exists())
    def test_missing_invalid_mismatched_source(self):
        for expected in [None,'bad','A'*40]:
            with self.assertRaises(ValueError):m.provenance(Path('.'),expected)
        with patch.object(m,'query',return_value=b'b'*40):
            with self.assertRaises(ValueError):m.provenance(Path('.'),'a'*40)
    def test_generated_pin_validation(self):
        with tempfile.TemporaryDirectory() as d:
            repo=Path(d);parser=repo/'research/indoor-io-buffered-diagnostic/resolution.py';parser.parent.mkdir(parents=True)
            shutil.copy2(Path(__file__).resolve().parents[2]/'research/indoor-io-buffered-diagnostic/resolution.py',parser)
            lock=repo/'BlindMemory/Package.resolved';lock.parent.mkdir()
            good={'version':3,'pins':[{'identity':'grdb.swift','kind':'remoteSourceControl','location':'https://github.com/groue/GRDB.swift.git','state':{'revision':'b83108d10f42680d78f23fe4d4d80fc88dab3212','version':'7.11.1'}}]}
            lock.write_text(json.dumps(good))
            def attempt():
                with patch.object(m,'query',side_effect=[b'a'*40,b'',b'?? BlindMemory/Package.resolved\0']):return m.provenance(repo,'a'*40)
            self.assertTrue(attempt()['tracked_source_clean'])
            good['pins'][0]['state']['revision']='f'*40;lock.write_text(json.dumps(good))
            with self.assertRaises(ValueError):attempt()
    def test_main_missing_or_dirty_source_persists_incomplete(self):
        with tempfile.TemporaryDirectory() as d:
            out=Path(d)/'out.json'
            for expected in ['', 'bad', 'a'*40]:
                with patch.object(sys,'argv',['exporter','unused','unused',str(out)]),patch.dict(os.environ,{'GITHUB_SHA':expected}),patch.object(m,'provenance',side_effect=ValueError('source unverified')),contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(m.main(),1)
                report=json.loads(out.read_text());self.assertFalse(report['complete']);self.assertFalse(report['target_pass_verified']);self.assertNotIn('source_commit',report)
    def test_unexpected_untracked_rejected(self):
        with patch.object(m,'query',side_effect=[b'a'*40,b'',b'?? ios/unexpected.swift\0']):
            with self.assertRaises(ValueError):m.provenance(Path('.'),'a'*40)
    def test_dirty_tracked_rejected(self):
        with patch.object(m,'query',side_effect=[b'a'*40,ValueError('dirty')]):
            with self.assertRaises(ValueError):m.provenance(Path('.'),'a'*40)
    def run_main(self,cases,events=('started','passed'),source_after=None,raw=None):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);log=p/'unit.log';out=p/'statuses.json'
            log.write_text(''.join("Test Case '-[IndoorGoalContinuityTests testTrackingLossStillInvalidatesRetainedMapFrame]' "+e+('.\n' if e=='started' else ' (0.1 seconds).\n') for e in events))
            summary={'totalTestCount':len(cases),'passedTests':sum(c['result']=='Passed' for c in cases),'failedTests':sum(c['result']=='Failed' for c in cases),'skippedTests':sum(c['result']=='Skipped' for c in cases),'expectedFailures':sum(c['result']=='Expected Failure' for c in cases)}
            (p/'unit-summary.json').write_text(json.dumps(summary))
            source={'actual_head':'a'*40,'tracked_source_clean':True}
            after=source if source_after is None else source_after
            with patch.object(sys,'argv',['exporter',str(p/'unit.xcresult'),str(log),str(out)]), patch.dict(os.environ,{'GITHUB_SHA':'a'*40}), patch.object(m,'query',return_value=raw if raw is not None else json.dumps(root(*cases)).encode()), patch.object(m,'provenance',side_effect=[source,after]), contextlib.redirect_stdout(io.StringIO()):
                code=m.main()
            return code,json.loads(out.read_text())
    def test_main_positive_witness(self):
        code,r=self.run_main([case()]);self.assertEqual(code,0);self.assertTrue(r['target_pass_verified'])
    def test_main_failed_skipped_duplicate_or_missing_never_verified(self):
        for cases,events in [([case('Failed')],('started','passed')),([case('Skipped')],('started','passed')),([case(),case()],('started','passed')),([case()],()),([case()],('started','failed'))]:
            _,r=self.run_main(cases,events);self.assertFalse(r['target_pass_verified'])
    def test_main_source_changes_clear_pass(self):
        code,r=self.run_main([case()],source_after={'actual_head':'b'*40});self.assertEqual(code,1);self.assertFalse(r['complete']);self.assertFalse(r['target_pass_verified'])
    def test_deep_json_persists_failure(self):
        code,r=self.run_main([case()],raw=b'['*3000+b']'*3000);self.assertEqual(code,1);self.assertFalse(r['complete']);self.assertFalse(r['target_pass_verified'])

if __name__=='__main__':unittest.main()
