#!/usr/bin/env python3
"""Bounded synthetic parser/provenance controls; no Apple processes or workflows."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('seated_diagnostic', HERE/'export-seated-case-diagnostics.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
MAPPED=['SeatedMeshProjectionTests/testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt', 'SeatedMeshProjectionTests/testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation', 'SeatedMeshProjectionTests/testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges']
NAME=m.EXPECTED[0]
CASES=[{'identifier':name+'()', 'result':'Passed'} for name in m.EXPECTED]

def summary(cases):
    result={'totalTestCount':len(cases),'testFailures':[]}
    for key,status in [('passedTests','Passed'),('failedTests','Failed'),('skippedTests','Skipped'),('expectedFailures','Expected Failure')]:
        result[key]=sum(c['result']==status for c in cases)
    return result

def assertion(name=NAME,message='XCTAssertTrue failed',filename=None):
    cls,method=name.split('/')
    return f'/private/not-exported/{filename or cls}.swift:123: error: -[BlindAssistTests.{cls} {method}] : {message}\n'

class ProjectionTests(unittest.TestCase):
    def test_all_twenty_one_exact_identities(self):
        result=m.project_cases(CASES);self.assertEqual(len(result['cases']),21);self.assertTrue(result['exactCaseSetObserved'])
    def test_failed_skipped_and_expected_failures_preserved(self):
        for status in ['Failed','Skipped','Expected Failure']:
            rows=[{'identifier':NAME,'result':status}]
            self.assertEqual(m.project_cases(rows)['cases'],rows)
    def test_duplicates_preserved_not_clean(self):
        result=m.project_cases(CASES+[CASES[0]])
        self.assertEqual(len(result['cases']),22);self.assertEqual(result['duplicateExpectedCaseRows'],1);self.assertFalse(result['exactCaseSetObserved'])
    def test_unknown_identity_withheld(self):
        result=m.project_cases([{'identifier':'PrivateTests/testPersonal','result':'Failed'}])
        self.assertEqual(result['unexpectedCaseCount'],1);self.assertNotIn('Personal',str(result))
    def test_missing_cases_explicit(self):
        result=m.project_cases(CASES[:-1]);self.assertEqual(result['missingExpectedIdentities'],[m.EXPECTED[-1]])
    def test_case_cap_counts_omitted(self):
        result=m.project_cases([CASES[0]]*129)
        self.assertEqual(len(result['cases']),128);self.assertEqual(result['caseRowsOmitted'],1)
    def test_exact_identity_forms(self):
        for raw in [NAME,NAME+'()','BlindAssistTests/'+NAME+'()', '-[BlindAssistTests.'+NAME.replace('/',' ')+']']:
            self.assertEqual(m.identity(raw),NAME)
    def test_identity_rejects_foreign_prefix_or_substring(self):
        for raw in ['Other/'+NAME,NAME+'Extra',None,[], 'x'*513]:self.assertIsNone(m.identity(raw))
    def test_known_assertion_categories(self):
        for token,expected in m.ASSERTIONS.items():self.assertEqual(m.category(token+' failed PRIVATE [1,2,3]'),expected)
    def test_async_and_unwaited_categories(self):
        self.assertEqual(m.category('Asynchronous wait failed: PRIVATE'),'async_wait_failure')
        self.assertEqual(m.category('Failed due to unwaited expectation PRIVATE'),'unwaited_expectation')
    def test_unknown_text_is_category_only(self):
        self.assertEqual(m.category('PRIVATE [1,2,3] secret'),'other_failure')
    def test_message_bound_and_missing(self):
        self.assertEqual(m.category('x'*4097),'oversize_message');self.assertEqual(m.category(None),'unavailable')
    def test_summary_failure_records_not_case_count(self):
        rows=[{'testIdentifier':NAME,'failureText':'XCTAssertEqual failed PRIVATE'}]*2
        result=m.summary_failures({'testFailures':rows})
        self.assertEqual(len(result['records']),2);self.assertNotIn('PRIVATE',str(result))
        self.assertEqual(result['countMeaning'],'failure_records_not_failed_test_cases')
    def test_summary_message_and_objc_testname(self):
        result=m.summary_failures({'testFailures':[{'testName':'-['+NAME.replace('/',' ')+']','message':'XCTUnwrap failed'}]})
        self.assertEqual(result['records'][0],{'identifier':NAME,'category':'unwrap'})
    def test_unknown_summary_is_not_zero_assertions(self):
        for value in [None,[],{}, {'testFailures':None}]:self.assertFalse(m.summary_failures(value)['schemaAvailable'])
    def test_explicit_empty_summary_known_zero_records(self):
        self.assertTrue(m.summary_failures({'testFailures':[]})['schemaAvailable'])
    def test_unknown_failure_identity_counted_not_exported(self):
        result=m.summary_failures({'testFailures':[{'testIdentifier':'Private/test','message':'PRIVATE'},'PRIVATE']})
        self.assertEqual(result['unrecognizedRecords'],2);self.assertNotIn('PRIVATE',str(result))
    def test_conflicting_known_failure_identity_rejected(self):
        result=m.summary_failures({'testFailures':[{'testIdentifier':NAME,'testName':m.EXPECTED[1],'message':'XCTAssertTrue failed'}]})
        self.assertEqual(result['unrecognizedRecords'],1);self.assertEqual(result['records'],[])
    def test_summary_failure_cap(self):
        result=m.summary_failures({'testFailures':[{'testIdentifier':NAME,'message':'failed'}]*129})
        self.assertEqual(len(result['records']),128);self.assertEqual(result['recordsOmitted'],1)

class LogTests(unittest.TestCase):
    def project(self,text):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'log';p.write_bytes(text if isinstance(text,bytes) else text.encode());return m.log_failures(p)
    def test_exact_case_category_line_only(self):
        result=self.project(assertion())
        self.assertEqual(result['records'],[{'identifier':NAME,'line':123,'category':'assert_true'}])
        self.assertNotIn('/private',str(result))
    def test_collision_class_supported(self):
        name=m.EXPECTED[-1];self.assertEqual(self.project(assertion(name))['records'][0]['identifier'],name)
    def test_wrong_filename_rejected(self):
        self.assertEqual(self.project(assertion(filename='Other'))['records'],[])
    def test_wrong_class_to_filename_rejected(self):
        self.assertEqual(self.project(assertion(filename='SeatedCollisionBridgeTests'))['records'],[])
    def test_unknown_test_rejected(self):
        self.assertEqual(self.project(assertion('SeatedMeshProjectionTests/testPrivate'))['records'],[])
    def test_long_line_tail_not_reinterpreted(self):
        result=self.project('x'*4097+assertion()+assertion())
        self.assertEqual(result['oversizeLinesSkipped'],1);self.assertEqual(len(result['records']),1)
    def test_binary_text_not_exported(self):
        self.assertEqual(self.project(b'\xff\xfe PRIVATE\n')['records'],[])
    def test_record_cap(self):
        result=self.project(assertion()*129);self.assertEqual(len(result['records']),128);self.assertEqual(result['recordsOmitted'],1)
    def test_total_log_budget(self):
        with patch.object(m,'LOG_LIMIT',20),self.assertRaises(ValueError):self.project(assertion())
    def test_other_app_output_not_exported(self):
        result=self.project('APP PRIVATE geometry [1,2,3]\n');self.assertNotIn('PRIVATE',str(result));self.assertEqual(result['records'],[])
    def test_symlink_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'file';p.write_text(assertion());link=Path(d)/'link';link.symlink_to(p)
            with self.assertRaises(ValueError):m.log_failures(link)

class CollectTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.out=Path(self.temp.name);self.cases=[dict(row) for row in CASES]
        self.cases[0]['result']='Failed';self.summary=summary(self.cases)
        self.summary['testFailures']=[{'testIdentifier':NAME,'failureText':'XCTAssertTrue failed PRIVATE'}]
        (self.out/'diagnostics-unit.log').write_text(assertion())
        (self.out/'diagnostics-unit-exit.json').write_text('{"exit_code":65}')
        self.before={'actual_head':'a'*40};self.after=self.before
        self.hashes={p:'b'*64 for p in m.FIXTURES}
    def run_export(self,source_error=False,case_error=False,summary_error=False):
        def query(args,seconds):
            self.assertEqual(seconds,20)
            kind=args[4]
            if kind=='tests':
                if case_error:raise ValueError('PRIVATE')
                return json.dumps({'testNodes':[{'nodeType':'Test Case','nodeIdentifier':r['identifier'],'result':r['result']} for r in self.cases]}).encode()
            if summary_error:raise ValueError('PRIVATE')
            return json.dumps(self.summary).encode()
        with patch.object(m.native,'provenance',side_effect=ValueError('PRIVATE') if source_error else [self.before,self.after]),patch.object(m,'fixture_source',return_value=self.hashes),patch.object(m.native,'query',side_effect=query),patch.dict(m.os.environ,{'GITHUB_SHA':'a'*40,'GITHUB_STEP_SUMMARY':str(self.out/'summary')},clear=True),contextlib.redirect_stdout(io.StringIO()) as stream:
            self.assertEqual(m.collect(self.out),0)
        result=json.loads((self.out/'seated-case-diagnostics.json').read_text())
        self.assertIn('SEATED_CASE_DIAGNOSTICS=',stream.getvalue());self.assertNotIn('PRIVATE',stream.getvalue())
        return result
    def test_failed_case_and_original_exit_retained(self):
        result=self.run_export();self.assertEqual(result['commandExit'],65);self.assertEqual(result['cases'][0]['result'],'Failed');self.assertEqual(result['counts']['Failed'],1)
    def test_assertions_not_combined_across_origins(self):
        result=self.run_export();self.assertFalse(result['assertionOriginsCombined'])
        self.assertEqual(len(result['summaryFailureCategories']['records']),1);self.assertEqual(len(result['logFailureCategories']['records']),1)
    def test_summary_written_on_failed_test(self):
        self.run_export();self.assertIn('SEATED_CASE_DIAGNOSTICS=',(self.out/'summary').read_text())
    def test_strict_failure_not_reclassified_pass(self):
        result=self.run_export();self.assertEqual(result['status'],'diagnostic-only');self.assertEqual(result['acceptance'],'not_inferred_strict_collector_unchanged')
    def test_summary_count_mismatch_keeps_case_rows(self):
        self.summary['totalTestCount']=999;result=self.run_export()
        self.assertFalse(result['aggregateCountsMatch']);self.assertEqual(len(result['cases']),21)
    def test_missing_summary_keeps_cases_and_log_categories(self):
        result=self.run_export(summary_error=True);self.assertEqual(len(result['cases']),21);self.assertIn('logFailureCategories',result)
    def test_missing_cases_keeps_summary_categories(self):
        result=self.run_export(case_error=True);self.assertNotIn('cases',result);self.assertIn('summaryFailureCategories',result)
    def test_unknown_summary_schema_explicit(self):
        self.summary={};result=self.run_export();self.assertFalse(result['summaryFailureCategories']['schemaAvailable'])
    def test_empty_result_never_becomes_zero_pass(self):
        self.cases=[];self.summary=summary([]);result=self.run_export()
        self.assertNotIn('cases',result);self.assertIn('tests-metadata-unavailable',result['errors'])
    def test_source_error_withholds_all_case_assertion_metadata(self):
        result=self.run_export(source_error=True);self.assertFalse(result['sourceVerified']);self.assertNotIn('cases',result);self.assertNotIn('logFailureCategories',result);self.assertEqual(result['commandExit'],65)
    def test_source_change_withholds_metadata(self):
        self.after={'actual_head':'c'*40};result=self.run_export();self.assertNotIn('cases',result);self.assertFalse(result['sourceVerified'])
    def test_missing_command_does_not_lose_failed_cases(self):
        (self.out/'diagnostics-unit-exit.json').unlink();result=self.run_export();self.assertIsNone(result['commandExit']);self.assertEqual(result['cases'][0]['result'],'Failed')
    def test_boolean_exit_not_integer(self):
        (self.out/'diagnostics-unit-exit.json').write_text('{"exit_code":false}');self.assertIsNone(self.run_export()['commandExit'])
    def test_large_command_rejected(self):
        (self.out/'diagnostics-unit-exit.json').write_text(' '*4097);result=self.run_export();self.assertIsNone(result['commandExit']);self.assertIn('cases',result)
    def test_output_budget_is_enforced(self):
        with patch.object(m,'OUTPUT_LIMIT',10),self.assertRaises(ValueError):self.run_export()

class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        for path,names,cls in [(m.FIXTURES[0],m.strict.PROJECTION_EXPECTED,'SeatedMeshProjectionTests'),
                               (m.FIXTURES[1],m.strict.COLLISION_EXPECTED,'SeatedCollisionBridgeTests')]:
            file=self.root/path;file.parent.mkdir(parents=True,exist_ok=True)
            file.write_text('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\nfinal class '+cls+': XCTestCase {\n'+
                            ''.join('func '+name.split('/')[1]+'() {}\n' for name in names)+'}\n#endif\n')
    def inspect(self):
        with patch.object(m,'ROOT',self.root):return m.fixture_source()
    def test_exact_fixture_hashes_recorded(self):
        hashes=self.inspect();self.assertEqual(set(hashes),set(m.FIXTURES));self.assertTrue(all(len(x)==64 for x in hashes.values()))
    def test_missing_flag_fails_closed(self):
        file=self.root/m.FIXTURES[0];file.write_text(file.read_text().replace('DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS','DEBUG'))
        with self.assertRaises(ValueError):self.inspect()
    def test_missing_original_case_fails_closed(self):
        file=self.root/m.FIXTURES[0];file.write_text(file.read_text().replace(NAME.split('/')[1],'otherMethod'))
        with self.assertRaises(ValueError):self.inspect()
    def test_unexpected_extra_case_fails_closed(self):
        file=self.root/m.FIXTURES[1];file.write_text(file.read_text()+'\nfunc testExtra() {}\n')
        with self.assertRaises(ValueError):self.inspect()
    def test_fixture_read_is_bounded(self):
        file=self.root/m.FIXTURES[0];file.write_bytes(b'x'*(2*1024*1024+1))
        with self.assertRaises(ValueError):self.inspect()
    def test_strict_collector_still_rejects_original_failed_command(self):
        source=(self.root/m.FIXTURES[0]).read_text();collision=(self.root/m.FIXTURES[1]).read_text()
        with self.assertRaises(ValueError):m.strict.collect(CASES,summary(CASES),'',{'exit_code':65},source,collision)


class MappedDiagnosticControls(unittest.TestCase):
    def test_same_closed_allowlist_as_strict_collector(self):
        self.assertEqual(list(m.EXPECTED),m.strict.EXPECTED)
        self.assertEqual(m.EXPECTED[14:17],tuple(MAPPED))
        self.assertEqual(len(m.EXPECTED),21)
    def test_all_original_eighteen_retained(self):
        original=list(m.EXPECTED[:14])+list(m.EXPECTED[17:])
        self.assertEqual(len(original),18)
        result=m.project_cases([{'identifier':x,'result':'Failed'} for x in original])
        self.assertEqual([x['identifier'] for x in result['cases']],original)
    def test_each_mapped_failed_skipped_and_expected_failure_retained(self):
        for name in MAPPED:
            for status in ['Failed','Skipped','Expected Failure']:
                with self.subTest(name=name,status=status):
                    self.assertEqual(m.project_cases([{'identifier':name,'result':status}])['cases'],[{'identifier':name,'result':status}])
    def test_each_mapped_summary_category_retained_without_message(self):
        for name in MAPPED:
            result=m.summary_failures({'testFailures':[{'testIdentifier':name,'message':'XCTAssertEqual failed PRIVATE'}]})
            with self.subTest(name=name):
                self.assertEqual(result['records'],[{'identifier':name,'category':'assert_equal'}]);self.assertNotIn('PRIVATE',str(result))
    def test_each_mapped_fixed_log_category_retained(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'log'
            for name in MAPPED:
                path.write_text(assertion(name))
                with self.subTest(name=name):self.assertEqual(m.log_failures(path)['records'][0]['identifier'],name)
    def test_similar_mapped_name_withheld(self):
        for name in MAPPED:self.assertIsNone(m.identity(name+'Extra'))

if __name__=='__main__':unittest.main()
