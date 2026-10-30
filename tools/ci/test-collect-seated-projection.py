"""Synthetic strict receipt parser regressions only; not Apple execution."""
from pathlib import Path
import importlib.util,unittest,json,os,tempfile,contextlib,io
from unittest.mock import patch
P=Path(__file__).parent;s=importlib.util.spec_from_file_location('seated',P/'collect-seated-projection.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
SOURCE=(P.parents[1]/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift').read_text()
COLLISION_SOURCE=(P.parents[1]/'ios/BlindAssistTests/SeatedCollisionBridgeTests.swift').read_text()
NORMAL_SOURCE=(P.parents[1]/'ios/BlindAssistTests/NormalOwnerMeshConnectionTests.swift').read_text()
def collect(cases,summary,log,command,source,collision_source,normal_source=NORMAL_SOURCE):
 return m.collect(cases,summary,log,command,source,collision_source,normal_source)
CASES=[{'identifier':x+'()','result':'Passed'} for x in m.EXPECTED]
SUMMARY={'result':'Passed','totalTestCount':26,'passedTests':26,'failedTests':0,'skippedTests':0,'expectedFailures':0}
LOG='\n'.join(f"Test Case '-[BlindAssistTests.{x.split('/')[0]} {x.split('/')[1]}]' "+('started.' if event=='started' else 'passed (0.001 seconds).') for x in m.EXPECTED for event in ['started','passed'])+'\n'
MAPPED=['SeatedMeshProjectionTests/testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt', 'SeatedMeshProjectionTests/testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation', 'SeatedMeshProjectionTests/testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges']
class Tests(unittest.TestCase):
 def reject(self,cases=CASES,summary=SUMMARY,log=LOG,command={'exit_code':0},source=SOURCE,collision_source=COLLISION_SOURCE,normal_source=NORMAL_SOURCE):
  with self.assertRaises((ValueError,KeyError)):collect(cases,summary,log,command,source,collision_source,normal_source)
 def test_exact26(self):self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE,COLLISION_SOURCE)['executed'],26)
 def test_missing_case(self):self.reject(cases=CASES[:-1])
 def test_duplicate_case(self):self.reject(cases=CASES[:-1]+CASES[:1])
 def test_failed_case(self):self.reject(cases=[dict(CASES[0],result='Failed')]+CASES[1:])
 def test_skipped_case(self):self.reject(cases=[dict(CASES[0],result='Skipped')]+CASES[1:])
 def test_other_class(self):self.reject(cases=[dict(CASES[0],identifier='Other/testX()')]+CASES[1:])
 def test_nonzero_exit(self):self.reject(command={'exit_code':65})
 def test_bool_exit_rejected(self):self.reject(command={'exit_code':False})
 def test_missing_exit(self):self.reject(command={})
 def test_bad_summary(self):self.reject(summary=dict(SUMMARY,totalTestCount=9))
 def test_missing_log_pair_is_explicit_secondary_evidence(self):
  result=collect(CASES,SUMMARY,'\n'.join(LOG.splitlines()[2:]),{'exit_code':0},SOURCE,COLLISION_SOURCE)
  self.assertEqual(result['consoleEvidence']['missing'],[m.EXPECTED[0]])
  self.assertEqual(result['consoleEvidence']['status'],'incomplete')
 def test_failed_log(self):self.reject(log=LOG.replace('passed','failed',1))
 def test_skipped_log(self):self.reject(log=LOG.replace('passed','skipped',1))
 def test_duplicate_log(self):self.reject(log=LOG+LOG.splitlines()[0]+'\n')
 def test_other_log_class(self):self.reject(log=LOG.replace('BlindAssistTests.SeatedMeshProjectionTests','Other.SeatedMeshProjectionTests',1))
 def test_other_log_case(self):self.reject(log=LOG.replace(m.EXPECTED[0].split('/')[1],'testUnexpected',1))
 def test_source_rename(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[0].split('/')[1]+'(', 'func testUnexpected('))
 def test_source_flag_removal(self):self.reject(source=SOURCE.replace('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n','',1))
 def test_empty_log_cannot_hide_missing_structured_evidence(self):
  result=collect(CASES,SUMMARY,'',{'exit_code':0},SOURCE,COLLISION_SOURCE)
  self.assertEqual(result['consoleEvidence']['status'],'not_observed')
  self.assertEqual(result['consoleEvidence']['missing'],m.EXPECTED)
  self.reject(log='',cases=[])
  self.reject(log='',command={'exit_code':65})
 def test_unqualified_hosted_class(self):self.assertEqual(collect(CASES,SUMMARY,LOG.replace('BlindAssistTests.',''),{'exit_code':0},SOURCE,COLLISION_SOURCE)['executed'],26)
 def test_original10_alone_rejected(self):self.reject(cases=CASES[:10],summary=dict(SUMMARY,totalTestCount=10,passedTests=10),log='\n'.join(LOG.splitlines()[:20])+'\n')
 def test_original10_still_required(self):self.assertEqual(len(m.EXPECTED[:10]),10);self.reject(cases=CASES[1:])
 def test_new_case_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[11].split('/')[1]+'(', 'func helper('))
 def test_new_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:11]+[dict(CASES[11],result='Failed')]+CASES[12:],summary=dict(SUMMARY,passedTests=25,failedTests=1))
 def test_new_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:11]+[dict(CASES[11],result='Skipped')]+CASES[12:],summary=dict(SUMMARY,passedTests=25,skippedTests=1))
 def test_class_renamed(self):self.reject(source=SOURCE.replace('class SeatedMeshProjectionTests:', 'class OtherTests:'))
 def test_multiline_declarations(self):
  source=SOURCE.replace('final class SeatedMeshProjectionTests: XCTestCase {','final class\nSeatedMeshProjectionTests:\nXCTestCase\n{').replace('func '+m.EXPECTED[11].split('/')[1]+'(', 'func\n'+m.EXPECTED[11].split('/')[1]+'\n(')
  self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],26)
 def test_original12_alone_rejected(self):self.reject(cases=CASES[:12],summary=dict(SUMMARY,totalTestCount=12,passedTests=12),log='\n'.join(LOG.splitlines()[:24])+'\n')
 def test_original12_prefix_and_readiness_identity(self):
  self.assertEqual(len(m.EXPECTED[:12]),12)
  self.assertEqual(m.EXPECTED[12:13],['SeatedMeshProjectionTests/testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld'])
 def test_readiness_case_missing(self):self.reject(cases=CASES[:12]+CASES[13:],summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
 def test_readiness_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:12]+[dict(CASES[12],result='Failed')]+CASES[13:],summary=dict(SUMMARY,passedTests=25,failedTests=1))
 def test_readiness_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:12]+[dict(CASES[12],result='Skipped')]+CASES[13:],summary=dict(SUMMARY,passedTests=25,skippedTests=1))
 def test_readiness_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[12].split('/')[1]+'(', 'func helper('))
 def test_readiness_source_multiline_declaration(self):
  source=SOURCE.replace('func '+m.EXPECTED[12].split('/')[1]+'(', 'func\n'+m.EXPECTED[12].split('/')[1]+'\n(')
  self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],26)
 def test_readiness_duplicate_log_rejected(self):self.reject(log=LOG+'\n'.join(LOG.splitlines()[24:26])+'\n')
 def test_exact17_projection_plus4_collision_split(self):
  self.assertEqual(len(m.PROJECTION_EXPECTED),17);self.assertEqual(len(m.COLLISION_EXPECTED),4)
  self.assertEqual(m.EXPECTED[:17],m.PROJECTION_EXPECTED)
  self.assertEqual(m.EXPECTED[17:21],m.COLLISION_EXPECTED)
 def test_collision_case_missing(self):
  for index in range(17,21):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+CASES[index+1:],summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
 def test_each_collision_failed_with_consistent_counts(self):
  for index in range(17,21):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Failed')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=25,failedTests=1))
 def test_each_collision_skipped_with_consistent_counts(self):
  for index in range(17,21):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Skipped')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=25,skippedTests=1))
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
  self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},SOURCE,source)['executed'],26)
 def test_original_classes_cannot_swap_sources(self):self.reject(source=COLLISION_SOURCE,collision_source=SOURCE)
 def test_original13_alone_rejected(self):self.reject(cases=CASES[:13],summary=dict(SUMMARY,totalTestCount=13,passedTests=13),log='\n'.join(LOG.splitlines()[:26])+'\n')
 def test_actual_audit_case_failed_with_consistent_counts(self):self.reject(cases=CASES[:13]+[dict(CASES[13],result='Failed')]+CASES[14:],summary=dict(SUMMARY,passedTests=25,failedTests=1))
 def test_actual_audit_case_skipped_with_consistent_counts(self):self.reject(cases=CASES[:13]+[dict(CASES[13],result='Skipped')]+CASES[14:],summary=dict(SUMMARY,passedTests=25,skippedTests=1))
 def test_actual_audit_source_missing(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED[13].split('/')[1]+'(', 'func helper('))
 def test_actual_audit_source_multiline_declaration(self):
  source=SOURCE.replace('func '+m.EXPECTED[13].split('/')[1]+'(', 'func\n'+m.EXPECTED[13].split('/')[1]+'\n(')
  self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],26)
 def test_original18_identities_still_required(self):
  self.assertEqual(len(m.PROJECTION_EXPECTED[:14]+m.COLLISION_EXPECTED),18)
  for name in m.PROJECTION_EXPECTED[:14]+m.COLLISION_EXPECTED:
   cases=[x for x in CASES if x['identifier'].removesuffix('()')!=name]
   with self.subTest(name=name):self.reject(cases=cases,summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
 def test_original18_without_new_mapped_cases_rejected(self):
  names=set(m.PROJECTION_EXPECTED[:14]+m.COLLISION_EXPECTED)
  cases=[x for x in CASES if x['identifier'].removesuffix('()') in names]
  self.reject(cases=cases,summary=dict(SUMMARY,totalTestCount=18,passedTests=18))
 def test_exact_mapped_identities(self):
  self.assertEqual(m.PROJECTION_EXPECTED[14:],MAPPED)
 def test_each_mapped_missing(self):
  for index in range(14,17):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+CASES[index+1:],summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
 def test_each_mapped_failed_with_consistent_counts(self):
  for index in range(14,17):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Failed')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=25,failedTests=1))
 def test_each_mapped_skipped_with_consistent_counts(self):
  for index in range(14,17):
   with self.subTest(index=index):self.reject(cases=CASES[:index]+[dict(CASES[index],result='Skipped')]+CASES[index+1:],summary=dict(SUMMARY,passedTests=25,skippedTests=1))
 def test_each_mapped_source_required(self):
  for name in MAPPED:
   with self.subTest(name=name):self.reject(source=SOURCE.replace('func '+name.split('/')[1]+'(', 'func helper('))
 def test_each_mapped_multiline_source_accepted(self):
  for name in MAPPED:
   source=SOURCE.replace('func '+name.split('/')[1]+'(', 'func\n'+name.split('/')[1]+'\n(')
   with self.subTest(name=name):self.assertEqual(collect(CASES,SUMMARY,LOG,{'exit_code':0},source,COLLISION_SOURCE)['executed'],26)
 def test_each_mapped_failed_log_rejected_missing_log_recorded(self):
  for name in MAPPED:
   cls,method=name.split('/');line=f"Test Case '-[BlindAssistTests.{cls} {method}]' passed (0.001 seconds)."
   with self.subTest(name=name):
    self.reject(log=LOG.replace(line,line.replace('passed','failed')))
    result=collect(CASES,SUMMARY,LOG.replace(line+'\n',''),{'exit_code':0},SOURCE,COLLISION_SOURCE)
    self.assertEqual(result['consoleEvidence']['partial'],[name])
    self.assertEqual(result['consoleEvidence']['status'],'incomplete')
 def test_all_pass_records_without_start_are_partial_not_fabricated_pairs(self):
  log='\n'.join(line for line in LOG.splitlines() if " passed " in line)
  result=collect(CASES,SUMMARY,log,{'exit_code':0},SOURCE,COLLISION_SOURCE)
  self.assertEqual(result['consoleEvidence']['partial'],m.EXPECTED)
  self.assertTrue(all(events==['passed'] for events in result['logWitnesses'].values()))
 def test_799_shaped_suite_only_console_uses_exact_structured_cases(self):
  log="Test Suite 'SeatedMeshProjectionTests' passed at synthetic.\nExecuted 26 tests, with 0 failures (0 unexpected)\n** TEST SUCCEEDED **\n"
  result=collect(CASES,SUMMARY,log,{'exit_code':0},SOURCE,COLLISION_SOURCE)
  self.assertEqual(result['executed'],26)
  self.assertEqual(result['consoleEvidence']['status'],'not_observed')
  self.assertEqual(result['evidenceAuthority'],'exact-source-xcresult-tests-and-summary-with-command-exit')
  self.reject(cases=CASES[:18],summary=dict(SUMMARY,totalTestCount=18,passedTests=18),log=log)
 def test_structured_summary_missing_pass_or_failed_stays_rejected(self):
  for value in [None,'Failed','Skipped','Unknown',True]:
   with self.subTest(value=value):self.reject(summary=dict(SUMMARY,result=value),log='')
 def test_structured_summary_failure_rows_contradict_zero_counts(self):
  self.reject(summary=dict(SUMMARY,testFailures=[{'failureText':'not emitted'}]),log='')
 def test_clean_structured_summary_empty_failure_list_accepted(self):
  self.assertEqual(collect(CASES,dict(SUMMARY,testFailures=[]),'',{'exit_code':0},SOURCE,COLLISION_SOURCE)['executed'],26)
 def test_expected_failure_with_consistent_counts_stays_rejected_without_log(self):
  self.reject(cases=[dict(CASES[0],result='Expected Failure')]+CASES[1:],summary=dict(SUMMARY,passedTests=25,expectedFailures=1),log='')
 def test_console_failed_skip_duplicate_still_veto_structured_pass(self):
  for status in ['failed','skipped']:
   with self.subTest(status=status):self.reject(log=LOG.replace('passed',status,1))
  self.reject(log=LOG+LOG.splitlines()[1]+'\n')
 def test_console_reversed_sequence_rejected(self):
  lines=LOG.splitlines();lines[0],lines[1]=lines[1],lines[0]
  self.reject(log='\n'.join(lines))
 def test_console_metadata_does_not_emit_unknown_identity_or_raw_error(self):
  log="Test Case '-[PrivateClass privatePayload]' failed (1.0 seconds).\nsecret capture contents\n"
  metadata=m.console_evidence(log)
  self.assertEqual(metadata['violations'],{'unrecognized_case_record':1})
  self.assertNotIn('PrivateClass',str(metadata));self.assertNotIn('secret',str(metadata))
  self.reject(log=log)
 def test_console_per_identity_record_cap_is_bounded_and_rejected(self):
  log=(LOG.splitlines()[0]+'\n')*1000
  metadata=m.console_evidence(log)
  self.assertEqual(len(metadata['events'][m.EXPECTED[0]]),3)
  self.assertEqual(metadata['violations']['excess_case_records'],997)
  self.reject(log=log)
 def test_console_oversize_case_record_is_not_echoed(self):
  metadata=m.console_evidence("Test Case "+"x"*4096)
  self.assertEqual(metadata['violations'],{'oversize_case_record':1})
  self.assertNotIn('x'*100,str(metadata))
 def test_known_unexpected_case_is_count_only_and_rejected(self):
  log="Test Case '-[SeatedMeshProjectionTests testUnexpected]' passed (0.001 seconds)."
  metadata=m.console_evidence(log)
  self.assertEqual(metadata['violations'],{'unexpected_case_identity':1})
  self.assertNotIn('testUnexpected',str(metadata));self.reject(log=log)
 def test_main_keeps_before_after_provenance_query_and_fixture_hashes(self):
  source=(P/'collect-seated-projection.py').read_text()
  self.assertEqual(source.count("native.provenance(ROOT,os.environ.get('GITHUB_SHA'))"),2)
  self.assertIn("require(before==after,'source identity changed during collection')",source)
  self.assertIn('summarySHA256=hashlib.sha256(summary_raw).hexdigest()',source)
  self.assertIn('collisionFixtureSHA256=hashlib.sha256(collision_source.read_bytes()).hexdigest()',source)
  self.assertLess(source.index("result['consoleEvidence']=console_evidence(log_text)"),source.index('result.update(collect('))
class MainAuthorityTests(unittest.TestCase):
 def run_main(self, provenance=None, command=0, summary=None, cases=None):
  good={'actual_head':'a'*40,'tracked_source_clean':True}
  tree={'testNodes':[{'nodeType':'Test Case','nodeIdentifier':case['identifier'],'result':case['result']} for case in (CASES if cases is None else cases)]}
  raw=json.dumps(tree).encode();summary_raw=json.dumps(SUMMARY if summary is None else summary).encode()
  with tempfile.TemporaryDirectory() as directory:
   out=Path(directory);(out/'diagnostics-unit.log').write_text('** TEST SUCCEEDED **\n')
   (out/'diagnostics-unit-exit.json').write_text(json.dumps({'exit_code':command}))
   with patch.object(m.native,'provenance',side_effect=[good,good] if provenance is None else provenance),patch.object(m.native,'query',side_effect=[raw,summary_raw]),patch('sys.argv',['collector',str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),contextlib.redirect_stdout(io.StringIO()):
    code=m.main()
   return code,json.loads((out/'seated-projection-results.json').read_text())
 def test_main_structured_complete_source_verified_without_console_pairs(self):
  code,result=self.run_main()
  self.assertEqual(code,0);self.assertTrue(result['complete']);self.assertTrue(result['source_verified'])
  self.assertEqual(result['source_commit'],'a'*40)
  self.assertEqual(result['consoleEvidence']['status'],'not_observed')
  self.assertEqual(len(result['querySHA256']),64);self.assertEqual(len(result['summarySHA256']),64)
 def test_main_dirty_or_wrong_source_never_reaches_acceptance(self):
  code,result=self.run_main(provenance=[ValueError('synthetic source mismatch')])
  self.assertEqual(code,1);self.assertFalse(result['complete']);self.assertFalse(result['source_verified'])
 def test_main_changed_after_query_source_cannot_pass(self):
  code,result=self.run_main(provenance=[{'actual_head':'a'*40},{'actual_head':'b'*40}])
  self.assertEqual(code,1);self.assertFalse(result['complete']);self.assertFalse(result['source_verified'])
  self.assertEqual(result['status'],'unavailable')
 def test_main_native_command_failure_cannot_borrow_complete_structured_pass(self):
  code,result=self.run_main(command=65)
  self.assertEqual(code,1);self.assertFalse(result['complete'])
 def test_main_exact_case_set_still_required_without_stdout(self):
  code,result=self.run_main(cases=CASES[:-1],summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
  self.assertEqual(code,1);self.assertFalse(result['complete'])

class NormalOwnerControls(unittest.TestCase):
 reject=Tests.reject
 def test_original21_prefix_retained_and_exact_five_append(self):
  self.assertEqual(m.EXPECTED[:21],m.PROJECTION_EXPECTED+m.COLLISION_EXPECTED)
  self.assertEqual(m.EXPECTED[21:],['NormalOwnerMeshConnectionTests/testIncompleteInventoryAndAggregateBoundsNeverBecomeEmptyClearSource', 'NormalOwnerMeshConnectionTests/testReorderedFutureWrongSessionAndExpiredFrameCannotIssueQuery', 'NormalOwnerMeshConnectionTests/testActualFullSourceStrictQueryAndAuditKeepFrozenRequestAcrossOrdinaryFrames', 'NormalOwnerMeshConnectionTests/testThirtyTwoSequentialAnchorCopiesPreserveHistoricalAgeAndFreshFrameLease', 'NormalOwnerMeshConnectionTests/testActualAuditGoalRetirementAndStopWaitForOperationDisposal'])
 def test_original21_without_new_class_rejected(self):self.reject(cases=CASES[:21],summary=dict(SUMMARY,totalTestCount=21,passedTests=21))
 def test_each_normal_case_missing_failed_skipped_duplicate(self):
  for i in range(21,26):
   with self.subTest(i=i):
    self.reject(cases=CASES[:i]+CASES[i+1:],summary=dict(SUMMARY,totalTestCount=25,passedTests=25))
    for status,key in [('Failed','failedTests'),('Skipped','skippedTests')]:self.reject(cases=CASES[:i]+[dict(CASES[i],result=status)]+CASES[i+1:],summary=dict(SUMMARY,passedTests=25,**{key:1}))
    self.reject(cases=CASES[:i]+CASES[i+1:]+[CASES[0]])
 def test_normal_source_flags_class_names_and_extra_refused(self):
  for value in ['',NORMAL_SOURCE.replace('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n','',1),NORMAL_SOURCE.replace('class NormalOwnerMeshConnectionTests:', 'class OtherTests:'),NORMAL_SOURCE+'\nfunc testUnexpected() {}\n']:
   self.reject(normal_source=value)
  for name in m.NORMAL_OWNER_EXPECTED:self.reject(normal_source=NORMAL_SOURCE.replace('func '+name.split('/')[1]+'(', 'func helper('))
 def test_normal_multiline_declarations_accepted(self):
  value=NORMAL_SOURCE.replace('final class NormalOwnerMeshConnectionTests: XCTestCase {','final class\nNormalOwnerMeshConnectionTests:\nXCTestCase\n{')
  for name in m.NORMAL_OWNER_EXPECTED:value=value.replace('func '+name.split('/')[1]+'(', 'func\n'+name.split('/')[1]+'\n(')
  self.assertEqual(collect(CASES,SUMMARY,'',{'exit_code':0},SOURCE,COLLISION_SOURCE,value)['executed'],26)
 def test_normal_failed_or_wrong_class_log_veto_and_missing_secondary(self):
  for name in m.NORMAL_OWNER_EXPECTED:
   cls,method=name.split('/');line=f"Test Case '-[BlindAssistTests.{cls} {method}]' passed (0.001 seconds)."
   self.reject(log=LOG.replace(line,line.replace('passed','failed')))
   self.reject(log=LOG.replace(line,line.replace(cls,'SeatedMeshProjectionTests')))
   result=collect(CASES,SUMMARY,LOG.replace(line+'\n',''),{'exit_code':0},SOURCE,COLLISION_SOURCE)
   self.assertEqual(result['consoleEvidence']['partial'],[name])
 def test_normal_source_hash_and_selection_remain_required(self):
  source=(P/'collect-seated-projection.py').read_text();self.assertIn('normalOwnerFixtureSHA256=hashlib.sha256(normal_source.read_bytes()).hexdigest()',source)
  helper=(P/'native-apple.sh').read_text();self.assertEqual(helper.count("'-only-testing:BlindAssistTests/NormalOwnerMeshConnectionTests'"),1)

if __name__=='__main__':unittest.main()
