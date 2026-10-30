"""Synthetic parser tests for exact reviewed71-case six-class current contract, not native execution."""
import importlib.util,json,unittest
from pathlib import Path
P=Path(__file__).parent
s=importlib.util.spec_from_file_location('collector',P/'collect-classified-bench.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
ROOT=P.parents[1]
SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/LiveMeshBenchIngressTests.swift').read_text()
SNAPSHOT_SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/SourceGeometrySnapshotTests.swift').read_text()
RECOVERY_SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/AnchorDeliveryRecoveryTests.swift').read_text()
HELPER_SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/MeshBenchHelperTests.swift').read_text()
CLS='LiveMeshClassifiedBenchTests.LiveMeshBenchIngressTests'
OUTER=['All tests','LiveMeshClassifiedBenchPackageTests.xctest']
lines=[f"Test Suite '{s}' started at synthetic." for s in OUTER]
for cls,names in [(CLS,m.EXPECTED_CASES),('LiveMeshClassifiedBenchTests.SourceGeometrySnapshotTests',m.SNAPSHOT_CASES),('LiveMeshClassifiedBenchTests.AnchorDeliveryRecoveryTests',m.RECOVERY_CASES),('LiveMeshClassifiedBenchTests.MeshBenchHelperTests',m.HELPER_CASES),('LiveMeshClassifiedBenchTests.MeshBenchCameraSnapshotTests',m.CAMERA_CASES),('LiveMeshClassifiedBenchTests.MeshBenchExpectedSourceTests',m.EXPECTED_SOURCE_CASES)]:
 suite=cls.split('.')[-1];lines.append(f"Test Suite '{suite}' started at synthetic.")
 for name in names:lines += [f"Test Case '-[{cls} {name}]' started.",f"Test Case '-[{cls} {name}]' passed (0.001 seconds)."]
 lines += [f"Test Suite '{suite}' passed at synthetic.",f'Executed {len(names)} tests, with 0 failures (0 unexpected)']
for suite in reversed(OUTER):lines += [f"Test Suite '{suite}' passed at synthetic.",'Executed 71 tests, with 0 failures (0 unexpected)']
LOG='\n'.join(lines)+'\n'
COMMAND={'swift_test_exit_code':0,'log_writer_exit_code':0}
class CollectorTests(unittest.TestCase):
 def reject(self,log=LOG,source=SOURCE,command=COMMAND,before='',after='',snapshot_source=SNAPSHOT_SOURCE,recovery_source=RECOVERY_SOURCE,helper_source=HELPER_SOURCE):
  with self.assertRaises(ValueError):m.collect(source,log,command,before,after,snapshot_source,recovery_source,helper_source)
 def test_exact_synthetic71_passes(self):self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','',SNAPSHOT_SOURCE,RECOVERY_SOURCE,HELPER_SOURCE)['executed'],71)
 def test_missing_case(self):self.reject('\n'.join(l for l in LOG.splitlines() if m.EXPECTED_CASES[0] not in l))
 def test_failed_case(self):self.reject(LOG.replace(m.EXPECTED_CASES[0]+"]' passed",m.EXPECTED_CASES[0]+"]' failed"))
 def test_duplicate_case(self):self.reject(LOG+next(l for l in LOG.splitlines() if m.EXPECTED_CASES[0] in l and 'passed' in l)+'\n')
 def test_zero_xml_not_evidence(self):self.reject('<testsuite tests="0" failures="0"/>')
 def test_nonzero_exit(self):self.reject(command=dict(COMMAND,swift_test_exit_code=1))
 def test_log_writer_failed(self):self.reject(command=dict(COMMAND,log_writer_exit_code=1))
 def test_changed_source(self):self.reject(after=' M file')
 def test_dirty_baseline(self):self.reject(before=' M file',after=' M file')
 def test_extra_case(self):self.reject(LOG+f"Test Case '-[{CLS} testExtra]' passed (0.001 seconds).\n")
 def test_extra_other_class(self):self.reject(LOG+"Test Case '-[Other.OtherTests testExtra]' started.\nTest Case '-[Other.OtherTests testExtra]' passed (0.001 seconds).\n")
 def test_contradictory_failed_suite(self):self.reject(LOG+"Test Suite 'LiveMeshBenchIngressTests' failed at synthetic.\n")
 def test_renamed_source_case(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED_CASES[0]+'(', 'func testReplacement('))
 def test_missing_new_case_source(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED_CASES[-1]+'(', 'func helper('))
 def test_old15_totals_rejected(self):self.reject(LOG.replace('Executed 18 tests','Executed 15 tests'))
 def test_all_new_cases_missing(self):self.reject('\n'.join(l for l in LOG.splitlines() if not any(n in l for n in m.EXPECTED_CASES[-3:])))
 def test_missing_snapshot_case(self):self.reject('\n'.join(l for l in LOG.splitlines() if m.SNAPSHOT_CASES[0] not in l))
 def test_renamed_snapshot_source(self):self.reject(snapshot_source=SNAPSHOT_SOURCE.replace('func '+m.SNAPSHOT_CASES[0]+'(', 'func testOther('))
 def test_snapshot_class_spoof(self):self.reject(LOG.replace('LiveMeshClassifiedBenchTests.SourceGeometrySnapshotTests','LiveMeshClassifiedBenchTests.LiveMeshBenchIngressTests'))
 def test_skipped_snapshot_case(self):self.reject(LOG.replace(m.SNAPSHOT_CASES[0]+"]' passed",m.SNAPSHOT_CASES[0]+"]' skipped"))
 def test_wrong_71_total(self):self.reject(LOG.replace('Executed 71 tests','Executed 33 tests'))
 def test_missing_snapshot_suite(self):self.reject('\n'.join(l for l in LOG.splitlines() if "Test Suite 'SourceGeometrySnapshotTests'" not in l))
 def test_swapped_class_totals(self):self.reject(LOG.replace('Executed 18 tests','Executed XX tests').replace('Executed 16 tests','Executed 18 tests').replace('Executed XX tests','Executed 16 tests'))
 def test_duplicate_snapshot_pass(self):self.reject(LOG+next(l for l in LOG.splitlines() if m.SNAPSHOT_CASES[0] in l and 'passed' in l)+'\n')
 def test_old34_total_rejected(self):self.reject(LOG.replace('Executed 71 tests','Executed 34 tests'))
 def test_missing_recovery_case(self):self.reject('\n'.join(l for l in LOG.splitlines() if m.RECOVERY_CASES[0] not in l))
 def test_renamed_recovery_source(self):self.reject(recovery_source=RECOVERY_SOURCE.replace('func '+m.RECOVERY_CASES[0]+'(', 'func testOther('))
 def test_recovery_class_spoof(self):self.reject(LOG.replace('LiveMeshClassifiedBenchTests.AnchorDeliveryRecoveryTests','LiveMeshClassifiedBenchTests.SourceGeometrySnapshotTests'))
 def test_skipped_recovery_case(self):self.reject(LOG.replace(m.RECOVERY_CASES[0]+"]' passed",m.RECOVERY_CASES[0]+"]' skipped"))
 def test_missing_recovery_suite(self):self.reject('\n'.join(l for l in LOG.splitlines() if "Test Suite 'AnchorDeliveryRecoveryTests'" not in l))
 def test_duplicate_recovery_pass(self):self.reject(LOG+next(l for l in LOG.splitlines() if m.RECOVERY_CASES[0] in l and 'passed' in l)+'\n')
 def test_swapped_recovery_totals(self):self.reject(LOG.replace('Executed 14 tests','Executed XX tests').replace('Executed 16 tests','Executed 14 tests').replace('Executed XX tests','Executed 16 tests'))
 def test_old48_total_rejected(self):self.reject(LOG.replace('Executed 71 tests','Executed 48 tests'))
 def test_missing_helper_case(self):self.reject('\n'.join(l for l in LOG.splitlines() if m.HELPER_CASES[0] not in l))
 def test_renamed_helper_source(self):self.reject(helper_source=HELPER_SOURCE.replace('func '+m.HELPER_CASES[0]+'(', 'func testOther('))
 def test_helper_class_spoof(self):self.reject(LOG.replace('LiveMeshClassifiedBenchTests.MeshBenchHelperTests','LiveMeshClassifiedBenchTests.AnchorDeliveryRecoveryTests'))
 def test_skipped_helper_case(self):self.reject(LOG.replace(m.HELPER_CASES[0]+"]' passed",m.HELPER_CASES[0]+"]' skipped"))
 def test_missing_helper_suite(self):self.reject('\n'.join(l for l in LOG.splitlines() if "Test Suite 'MeshBenchHelperTests'" not in l))
 def test_duplicate_helper_pass(self):self.reject(LOG+next(l for l in LOG.splitlines() if m.HELPER_CASES[0] in l and 'passed' in l)+'\n')
 def test_wrong_helper_suite_total(self):self.reject(LOG.replace("Test Suite 'MeshBenchHelperTests' passed at synthetic.\nExecuted 14", "Test Suite 'MeshBenchHelperTests' passed at synthetic.\nExecuted 16"))
 def test_old62_total_rejected(self):self.reject(LOG.replace('Executed 71 tests','Executed 62 tests'))
 def test_missing_camera_case(self):self.reject('\n'.join(l for l in LOG.splitlines() if m.CAMERA_CASES[0] not in l))
 def test_failed_camera_case(self):self.reject(LOG.replace(m.CAMERA_CASES[0]+"]' passed",m.CAMERA_CASES[0]+"]' failed"))
 def test_skipped_expected_source_case(self):self.reject(LOG.replace(m.EXPECTED_SOURCE_CASES[0]+"]' passed",m.EXPECTED_SOURCE_CASES[0]+"]' skipped"))
 def test_missing_expected_source_class(self):self.reject(LOG.replace('LiveMeshClassifiedBenchTests.MeshBenchExpectedSourceTests','LiveMeshClassifiedBenchTests.MeshBenchCameraSnapshotTests'))
 def test_new_case_source_removed(self):self.reject(helper_source=HELPER_SOURCE.replace('func '+m.CAMERA_CASES[0]+'(', 'func helper('))
 def test_new_case_source_wrong_class(self):self.reject(helper_source=HELPER_SOURCE.replace('class MeshBenchCameraSnapshotTests:', 'class WrongCameraTests:'))
 def test_duplicate_source_class(self):self.reject(helper_source=HELPER_SOURCE+'\nfinal class MeshBenchCameraSnapshotTests: XCTestCase {}\n')
 def test_original62_contract_retained(self):
  self.assertEqual(len(m.EXPECTED_CASES)+len(m.SNAPSHOT_CASES)+len(m.RECOVERY_CASES)+len(m.HELPER_CASES),62)
 def test_multiline_declarations_accepted(self):
  source=HELPER_SOURCE.replace('final class MeshBenchCameraSnapshotTests: XCTestCase {','final class\nMeshBenchCameraSnapshotTests:\nXCTestCase\n{').replace('func '+m.CAMERA_CASES[0]+'(', 'func\n'+m.CAMERA_CASES[0]+'\n(')
  self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','',SNAPSHOT_SOURCE,RECOVERY_SOURCE,source)['executed'],71)
 def test_original65_exact_class_and_case_identities_preserved(self):
  import hashlib
  identities=[(cls,case) for cls,names in [('LiveMeshBenchIngressTests',m.EXPECTED_CASES),('SourceGeometrySnapshotTests',m.SNAPSHOT_CASES),('AnchorDeliveryRecoveryTests',m.RECOVERY_CASES),('MeshBenchHelperTests',m.HELPER_CASES),('MeshBenchCameraSnapshotTests',m.CAMERA_CASES),('MeshBenchExpectedSourceTests',m.EXPECTED_SOURCE_CASES[:1])] for case in names]
  self.assertEqual(len(identities),65)
  self.assertEqual(hashlib.sha256(json.dumps(identities,separators=(',',':')).encode()).hexdigest(),'d55a01d5b5c126a0051481ed1bd0471ef5df4adae2819e8b264b6e8180a49790')
 def test_new_six_exact_identities_and_class_membership(self):
  self.assertEqual(m.EXPECTED_SOURCE_CASES[1:],['testSavedWorldRecoveryRequiresRelocalizingThenDistinctNormalFrames', 'testSavedWorldRecoveryBindsExactCaptureAndSession', 'testSavedWorldRecoveryMaintainsEpochWithoutRebindingOldCapture', 'testSavedWorldRecoveryRetirementAndRestartDoNotRestoreAssociation', 'testSavedWorldRecoveryRejectsOriginLossMappingLossAndStaleFrames', 'testSavedWorldRecoveryWrongDescriptorAndNonfiniteClockStayUnknown'])
  classes=m.helper_classes(HELPER_SOURCE)
  self.assertEqual(classes['MeshBenchExpectedSourceTests'],m.EXPECTED_SOURCE_CASES)
  self.assertEqual(len(classes['MeshBenchHelperTests']),14)
  self.assertEqual(len(classes['MeshBenchCameraSnapshotTests']),2)
 def test_each_new_recovery_case_must_be_present(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   with self.subTest(case=name):self.reject('\n'.join(line for line in LOG.splitlines() if name not in line))
 def test_each_new_recovery_failure_is_rejected(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   with self.subTest(case=name):self.reject(LOG.replace(name+"]' passed",name+"]' failed"))
 def test_each_new_recovery_skip_is_rejected(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   with self.subTest(case=name):self.reject(LOG.replace(name+"]' passed",name+"]' skipped"))
 def test_each_new_recovery_duplicate_is_rejected(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   with self.subTest(case=name):self.reject(LOG+next(line for line in LOG.splitlines() if name in line and 'passed' in line)+'\n')
 def test_each_new_recovery_source_method_required(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   with self.subTest(case=name):self.reject(helper_source=HELPER_SOURCE.replace('func '+name+'(', 'func helper('))
 def test_new_recovery_wrong_log_class_rejected(self):
  for name in m.EXPECTED_SOURCE_CASES[1:]:
   old='LiveMeshClassifiedBenchTests.MeshBenchExpectedSourceTests '+name
   with self.subTest(case=name):self.reject(LOG.replace(old,'LiveMeshClassifiedBenchTests.MeshBenchHelperTests '+name))
 def test_original65_total_cannot_certify_new71(self):self.reject(LOG.replace('Executed 71 tests','Executed 65 tests'))
 def test_expected_source_suite_must_have_seven_not_one(self):
  self.reject(LOG.replace("Test Suite 'MeshBenchExpectedSourceTests' passed at synthetic.\nExecuted 7", "Test Suite 'MeshBenchExpectedSourceTests' passed at synthetic.\nExecuted 1"))
 def test_new_source_multiline_declarations_accepted(self):
  source=HELPER_SOURCE.replace('final class MeshBenchExpectedSourceTests: XCTestCase {','final class\nMeshBenchExpectedSourceTests:\nXCTestCase\n{')
  for name in m.EXPECTED_SOURCE_CASES[1:]:source=source.replace('func '+name+'(', 'func\n'+name+'\n(')
  self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','',SNAPSHOT_SOURCE,RECOVERY_SOURCE,source)['executed'],71)
 def test_receipt_preserves_nonphysical_scope_and_ios_exclusions(self):
  result=m.collect(SOURCE,LOG,COMMAND,'','',SNAPSHOT_SOURCE,RECOVERY_SOURCE,HELPER_SOURCE)
  self.assertEqual((result['executed'],result['passed'],result['failed']),(71,71,0))
  self.assertEqual(result['ios_session_fixtures_excluded'],5)
  self.assertTrue(result['source_clean_before_and_after'])
  self.assertTrue(result['swift_testing_zero_suite_not_counted'])
  self.assertIn('not live sensing',result['scope'])
  self.assertEqual(len(result['cases']),71)
if __name__=='__main__':unittest.main()
