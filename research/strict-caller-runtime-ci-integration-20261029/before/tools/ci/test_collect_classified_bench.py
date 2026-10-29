import importlib.util,json,unittest
from pathlib import Path
P=Path(__file__).parent
s=importlib.util.spec_from_file_location('collector',P/'collect-classified-bench.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
ROOT=P.parents[1]/'blind'
SOURCE=(ROOT/'research/live-mesh-classified-bench-20261028/Tests/LiveMeshBenchIngressTests.swift').read_text()
LOG=(P/'classified-artifact/swift-test.log').read_text()
COMMAND=json.loads((P/'classified-artifact/result.json').read_text())
class CollectorTests(unittest.TestCase):
 def test_exact_real_log_passes(self): self.assertEqual(m.collect(SOURCE,LOG,COMMAND,'','')['executed'],15)
 def test_missing_case(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,'\n'.join(l for l in LOG.splitlines() if 'testForeignGenerationCannotInvokeBorrowedCapture' not in l),COMMAND,'','')
 def test_failed_case(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG.replace("testForeignGenerationCannotInvokeBorrowedCapture]' passed", "testForeignGenerationCannotInvokeBorrowedCapture]' failed"),COMMAND,'','')
 def test_duplicate_case(self):
  line=next(l for l in LOG.splitlines() if "testForeignGenerationCannotInvokeBorrowedCapture]' passed" in l)
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+line+'\n',COMMAND,'','')
 def test_zero_xml_is_not_xctest_evidence(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,(P/'classified-artifact/tests-swift-testing.xml').read_text(),COMMAND,'','')
 def test_nonzero_exit(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG,dict(COMMAND,swift_test_exit_code=1),'','')
 def test_changed_source(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG,COMMAND,'',' M file')
 def test_dirty_baseline(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG,COMMAND,' M file',' M file')
 def test_extra_case(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+"Test Case '-[LiveMeshClassifiedBenchTests.LiveMeshBenchIngressTests testExtra]' passed (0.001 seconds).\n",COMMAND,'','')
 def test_log_writer_failure(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG,dict(COMMAND,log_writer_exit_code=1),'','')
 def test_extra_other_class(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+"Test Case '-[Other.OtherTests testExtra]' started.\nTest Case '-[Other.OtherTests testExtra]' passed (0.001 seconds).\n",COMMAND,'','')
 def test_contradictory_failed_suite(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+"Test Suite 'LiveMeshBenchIngressTests' failed at 2026-10-28 20:40:21.000.\n",COMMAND,'','')
 def test_contradictory_totals(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+"Executed 16 tests, with 1 failure (1 unexpected)\n",COMMAND,'','')
 def test_malformed_case(self):
  with self.assertRaises(ValueError): m.collect(SOURCE,LOG+"Test Case malformed\n",COMMAND,'','')
if __name__=='__main__':unittest.main()
