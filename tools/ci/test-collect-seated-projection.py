"""Synthetic strict receipt parser regressions only; not Apple execution."""
from pathlib import Path
import importlib.util,unittest
P=Path(__file__).parent;s=importlib.util.spec_from_file_location('seated',P/'collect-seated-projection.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
SOURCE=(P.parents[1]/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift').read_text()
COLLISION_SOURCE=(P.parents[1]/'ios/BlindAssistTests/SeatedCollisionBridgeTests.swift').read_text()
CASES=[{'identifier':x+'()','result':'Passed'} for x in m.EXPECTED]
SUMMARY={'totalTestCount':18,'passedTests':18,'failedTests':0,'skippedTests':0,'expectedFailures':0}
LOG='\n'.join(f"Test Case '-[BlindAssistTests.{x.split('/')[0]} {x.split('/')[1]}]' "+('started.' if event=='started' else 'passed (0.001 seconds).') for x in m.EXPECTED for event in ['started','passed'])+'\n'
class Tests(unittest.TestCase):
 def reject(self,cases=CASES,summary=SUMMARY,log=LOG,command={'exit_code':0},source=SOURCE,collision_source=COLLISION_SOURCE):
  with self.assertRaises((ValueError,KeyError)):m.collect(cases,summary,log,command,source,collision_source)
 def test_exact18(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE,COLLISION_SOURCE)['executed'],18)
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
 def test_unqualified_hosted_class(self):self.assertEqual(m.collect(CASES,SUMMARY,LOG.replace('BlindAssistTests.',''),{'exit_code':0},SOURCE,COLLISION_SOURCE)['executed'],18)
 def test_original10_alone_rejected(self):self.reject(cases=CASES[:10],summary=dict(SUMMARY,totalTestCount=10,passedTests=10),log='\n'.join(LOG.splitlines()[:20])+'\n')
 def test_original10_still_required(self):self.assertEqual(len(m.EXPECTED[:10]),10);self.reject(cases=CASES[1:])
 def test_new_case_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[11].split('/')[1]+'(', 'func helper('))
 def test_new_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:11]+[dict(CASES[11],result='Failed')]+CASES[12:],summary=dict(SUMMARY,passedTests=17,failedTests=1))
 def test_new_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:11]+[dict(CASES[11],result='Skipped')]+CASES[12:],summary=dict(SUMMARY,passedTests=17,skippedTests=1))
 def test_class_renamed(self):self.reject(source=SOURCE.replace('class SeatedMeshProjectionTests:', 'class OtherTests:'))
 def test_multiline_declarations(self):
  source=SOURCE.replace('final class SeatedMeshProjectionTests: XCTestCase {','final class\nSeatedMeshProjectionTests:\nXCTestCase\n{').replace('func '+m.EXPECTED[11].split('/')[1]+'(', 'func\n'+m.EXPECTED[11].split('/')[1]+'\n(')
  self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],18)
 def test_original12_alone_rejected(self):self.reject(cases=CASES[:12],summary=dict(SUMMARY,totalTestCount=12,passedTests=12),log='\n'.join(LOG.splitlines()[:24])+'\n')
 def test_original12_prefix_and_readiness_identity(self):
  self.assertEqual(len(m.EXPECTED[:12]),12)
  self.assertEqual(m.EXPECTED[12:13],['SeatedMeshProjectionTests/testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld'])
 def test_readiness_case_missing(self):self.reject(cases=CASES[:12]+CASES[13:],summary=dict(SUMMARY,totalTestCount=17,passedTests=17))
 def test_readiness_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:12]+[dict(CASES[12],result='Failed')]+CASES[13:],summary=dict(SUMMARY,passedTests=17,failedTests=1))
 def test_readiness_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:12]+[dict(CASES[12],result='Skipped')]+CASES[13:],summary=dict(SUMMARY,passedTests=17,skippedTests=1))
 def test_readiness_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[12].split('/')[1]+'(', 'func helper('))
 def test_readiness_source_multiline_declaration(self):
  source=SOURCE.replace('func '+m.EXPECTED[12].split('/')[1]+'(', 'func\n'+m.EXPECTED[12].split('/')[1]+'\n(')
  self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],18)
 def test_readiness_duplicate_log_rejected(self):self.reject(log=LOG+'\n'.join(LOG.splitlines()[24:26])+'\n')
 def test_exact14_projection_plus4_collision_split(self):
  self.assertEqual(len(m.PROJECTION_EXPECTED),14);self.assertEqual(len(m.COLLISION_EXPECTED),4)
  self.assertEqual(m.EXPECTED[:14],m.PROJECTION_EXPECTED)
  self.assertEqual(m.EXPECTED[14:],m.COLLISION_EXPECTED)
 def test_collision_case_missing(self):
  for index in range(14,18):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+CASES[index+1:],summary=dict(SUMMARY,totalTestCount=17,passedTests=17))
 def test_each_collision_failed_with_consistent_counts(self):
  for index in range(14,18):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Failed')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=17,failedTests=1))
 def test_each_collision_skipped_with_consistent_counts(self):
  for index in range(14,18):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Skipped')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=17,skippedTests=1))
 def test_collision_source_missing(self):self.reject(collision_source='')
 def test_collision_source_flag_removal(self):self.reject(collision_source=COLLISION_SOURCE.replace('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n','',1))
 def test_collision_source_class_renamed(self):self.reject(collision_source=COLLISION_SOURCE.replace('class SeatedCollisionBridgeTests:', 'class OtherTests:'))
 def test_each_collision_source_name_required(self):
  for name in m.COLLISION_EXPECTED:
   with self.subTest(name=name):self.reject(collision_source=COLLISION_SOURCE.replace('func '+name.split('/')[1]+'(', 'func helper('))
 def test_collision_wrong_log_class(self):self.reject(log=LOG.replace('SeatedCollisionBridgeTests','SeatedMeshProjectionTests'))
 def test_collision_source_extra_test_rejected(self):self.reject(collision_source=COLLISION_SOURCE+'\nfunc testUnexpected() {}\n')
 def test_collision_source_duplicate_class_rejected(self):self.reject(collision_source=COLLISION_SOURCE+'\nfinal class SeatedCollisionBridgeTests: XCTestCase {}\n')
 def test_collision_source_multiline_declarations(self):
  source=COLLISION_SOURCE.replace('final class SeatedCollisionBridgeTests: XCTestCase {','final class\nSeatedCollisionBridgeTests:\nXCTestCase\n{').replace('func '+m.COLLISION_EXPECTED[-1].split('/')[1]+'(', 'func\n'+m.COLLISION_EXPECTED[-1].split('/')[1]+'\n(')
  self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE,source)['executed'],18)
 def test_original_classes_cannot_swap_sources(self):self.reject(source=COLLISION_SOURCE,collision_source=SOURCE)
 def test_original13_alone_rejected(self):self.reject(cases=CASES[:13],summary=dict(SUMMARY,totalTestCount=13,passedTests=13),log='\n'.join(LOG.splitlines()[:26])+'\n')
 def test_actual_audit_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:13]+[dict(CASES[13],result='Failed')]+CASES[14:],summary=dict(SUMMARY,passedTests=17,failedTests=1))
 def test_actual_audit_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:13]+[dict(CASES[13],result='Skipped')]+CASES[14:],summary=dict(SUMMARY,passedTests=17,skippedTests=1))
 def test_actual_audit_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[13].split('/')[1]+'(', 'func helper('))
 def test_actual_audit_source_multiline_declaration(self):
  source=SOURCE.replace('func '+m.EXPECTED[13].split('/')[1]+'(', 'func\n'+m.EXPECTED[13].split('/')[1]+'\n(')
  self.assertEqual(m.collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],18)
if __name__=='__main__':unittest.main()
