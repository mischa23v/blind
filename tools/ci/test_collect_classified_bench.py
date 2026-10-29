"""Synthetic parser tests for exact reviewed34-case two-class current contract, not native execution."""
import importlib.util,json,unittest
from pathlib import Path
P=Path(__file__).parent
s=importlib.util.spec_from_file_location('collector',P/'collect-classified-bench.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
ROOT=P.parents[1]
SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/LiveMeshBenchIngressTests.swift').read_text()
SNAPSHOT_SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/SourceGeometrySnapshotTests.swift').read_text()
CLS='LiveMeshClassifiedBenchTests.LiveMeshBenchIngressTests'
OUTER=['All tests','LiveMeshClassifiedBenchPackageTests.xctest']
lines=[f"Test Suite '{s}' started at synthetic." for s in OUTER]
for cls,names in [(CLS,m.EXPECTED_CASES),('LiveMeshClassifiedBenchTests.SourceGeometrySnapshotTests',m.SNAPSHOT_CASES)]:
 suite=cls.split('.')[-1];lines.append(f"Test Suite '{suite}' started at synthetic.")
 for name in names:lines += [f"Test Case '-[{cls} {name}]' started.",f"Test Case '-[{cls} {name}]' passed (0.001 seconds)."]
 lines += [f"Test Suite '{suite}' passed at synthetic.",f'Executed {len(names)} tests, with 0 failures (0 unexpected)']
for suite in reversed(OUTER):lines += [f"Test Suite '{suite}' passed at synthetic.",'Executed 34 tests, with 0 failures (0 unexpected)']
LOG='\n'.join(lines)+'\n'
COMMAND={'swift_test_exit_code':0,'log_writer_exit_code':0}
class CollectorTests(unittest.TestCase):
 def reject(self,log=LOG,source=SOURCE,command=COMMAND,before='',after='',snapshot_source=SNAPSHOT_SOURCE):
  with self.assertRaises(ValueError):m.collect(source,log,command,before,after,snapshot_source)
 def test_exact_synthetic34_passes(self):self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','',SNAPSHOT_SOURCE)['executed'],34)
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
 def test_wrong_34_total(self):self.reject(LOG.replace('Executed 34 tests','Executed 33 tests'))
 def test_missing_snapshot_suite(self):self.reject('\n'.join(l for l in LOG.splitlines() if "Test Suite 'SourceGeometrySnapshotTests'" not in l))
 def test_swapped_class_totals(self):self.reject(LOG.replace('Executed 18 tests','Executed XX tests').replace('Executed 16 tests','Executed 18 tests').replace('Executed XX tests','Executed 16 tests'))
 def test_duplicate_snapshot_pass(self):self.reject(LOG+next(l for l in LOG.splitlines() if m.SNAPSHOT_CASES[0] in l and 'passed' in l)+'\n')
if __name__=='__main__':unittest.main()
