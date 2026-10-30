"""Synthetic strict receipt parser regressions only; not Apple execution."""
from pathlib import Path
import importlib.util,unittest
P=Path(__file__).parent;s=importlib.util.spec_from_file_location('seated',P/'collect-seated-projection.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
SOURCE=(P.parents[1]/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift').read_text()
CASES=[{'identifier':x+'()','result':'Passed'} for x in m.EXPECTED]
SUMMARY={'totalTestCount':12,'passedTests':12,'failedTests':0,'skippedTests':0,'expectedFailures':0}
LOG='\n'.join(f"Test Case '-[BlindAssistTests.SeatedMeshProjectionTests {x.split('/')[1]}]' "+('started.' if event=='started' else 'passed (0.001 seconds).') for x in m.EXPECTED for event in ['started','passed'])+'\n'
class Tests(unittest.TestCase):
 def reject(self,cases=CASES,summary=SUMMARY,log=LOG,command={'exit_code':0},source=SOURCE):
  with self.assertRaises((ValueError,KeyError)):m.collect(cases,summary,log,command,source)
 def test_exact12(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE)['executed'],12)
 def test_missing_case(self):self.reject(cases=CASES[:-1])
 def test_duplicate_case(self):self.reject(cases=CASES[:-1]+CASES[:1])
 def test_failed_case(self):self.reject(cases=[dict(CASES[0],result='Failed')]+CASES[1:])
 def test_skipped_case(self):self.reject(cases=[dict(CASES[0],result='Skipped')]+CASES[1:])
 def test_other_class(self):self.reject(cases=[dict(CASES[0],identifier='Other/testX()')]+CASES[1:])
 def test_nonzero_exit(self):self.reject(command={'exit_code':65})
 def test_bool_exit_rejected(self):self.reject(command={'exit_code':False})
 def test_missing_exit(self):self.reject(command={})
 def test_bad_summary(self):self.reject(summary=dict(SUMMARY,totalTestCount=9))
 def test_missing_log_pair(self):self.reject(log='\n'.join(LOG.splitlines()[2:]))
 def test_failed_log(self):self.reject(log=LOG.replace('passed','failed',1))
 def test_skipped_log(self):self.reject(log=LOG.replace('passed','skipped',1))
 def test_duplicate_log(self):self.reject(log=LOG+LOG.splitlines()[0]+'\n')
 def test_other_log_class(self):self.reject(log=LOG.replace('BlindAssistTests.SeatedMeshProjectionTests','Other.SeatedMeshProjectionTests',1))
 def test_other_log_case(self):self.reject(log=LOG.replace(m.EXPECTED[0].split('/')[1],'testUnexpected',1))
 def test_source_rename(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[0].split('/')[1]+'(', 'func testUnexpected('))
 def test_source_flag_removal(self):self.reject(source=SOURCE.replace('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n','',1))
 def test_empty_log(self):self.reject(log='')
 def test_unqualified_hosted_class(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG.replace('BlindAssistTests.',''),{'exit_code':0},SOURCE)['executed'],12)
 def test_original10_alone_rejected(self):self.reject(cases=CASES[:10],summary=dict(SUMMARY,totalTestCount=10,passedTests=10),log='\n'.join(LOG.splitlines()[:20])+'\n')
 def test_original10_still_required(self):self.assertEqual(len(m.EXPECTED[:10]),10);self.reject(cases=CASES[1:])
 def test_new_case_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[-1].split('/')[1]+'(', 'func helper('))
 def test_new_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:-1]+[dict(CASES[-1],result='Failed')],summary=dict(SUMMARY,passedTests=11,failedTests=1))
 def test_new_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:-1]+[dict(CASES[-1],result='Skipped')],summary=dict(SUMMARY,passedTests=11,skippedTests=1))
 def test_class_renamed(self):self.reject(source=SOURCE.replace('class SeatedMeshProjectionTests:', 'class OtherTests:'))
 def test_multiline_declarations(self):
  source=SOURCE.replace('final class SeatedMeshProjectionTests: XCTestCase {','final class\nSeatedMeshProjectionTests:\nXCTestCase\n{').replace('func '+m.EXPECTED[-1].split('/')[1]+'(', 'func\n'+m.EXPECTED[-1].split('/')[1]+'\n(')
  self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},source)['executed'],12)
if __name__=='__main__':unittest.main()
