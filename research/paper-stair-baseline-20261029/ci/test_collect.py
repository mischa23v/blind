"""Synthetic parser tests for exact reviewed17-case current contract, not native execution."""
import importlib.util,json,unittest
from pathlib import Path
P=Path(__file__).parent
s=importlib.util.spec_from_file_location('collector',P/'collect.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
ROOT=P.parent
SOURCE=(ROOT/'Tests/PaperStairReferenceTests/ReferenceTests.swift').read_text()
CLS='PaperStairReferenceTests.ReferenceTests'
SUITES=['All tests','PaperStairReferencePackageTests.xctest','ReferenceTests']
LOG='\n'.join([*(f"Test Suite '{s}' started at synthetic." for s in SUITES),*(line for name in m.EXPECTED_CASES for line in [f"Test Case '-[{CLS} {name}]' started.",f"Test Case '-[{CLS} {name}]' passed (0.001 seconds)."]),*(line for s in reversed(SUITES) for line in [f"Test Suite '{s}' passed at synthetic.",'Executed 17 tests, with 0 failures (0 unexpected)'])])+'\n'
COMMAND={'swift_test_exit_code':0,'log_writer_exit_code':0}
class CollectorTests(unittest.TestCase):
 def reject(self,log=LOG,source=SOURCE,command=COMMAND,before='',after=''):
  with self.assertRaises(ValueError):m.collect(source,log,command,before,after)
 def test_exact_synthetic17_passes(self):self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','')['executed'],17)
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
 def test_contradictory_failed_suite(self):self.reject(LOG+"Test Suite 'ReferenceTests' failed at synthetic.\n")
 def test_renamed_source_case(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED_CASES[0]+'(', 'func testReplacement('))
 def test_missing_new_case_source(self):self.reject(source=SOURCE.replace('func '+m.EXPECTED_CASES[-1]+'(', 'func helper('))
 def test_old15_totals_rejected(self):self.reject(LOG.replace('Executed 17 tests','Executed 15 tests'))
 def test_all_new_cases_missing(self):self.reject('\n'.join(l for l in LOG.splitlines() if not any(n in l for n in m.EXPECTED_CASES[-3:])))
if __name__=='__main__':unittest.main()
