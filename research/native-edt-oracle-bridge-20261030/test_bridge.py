#!/usr/bin/env python3
"""Pure stdlib controls: no native imports, subprocess, build, or CI execution."""
import importlib.util,pathlib,tempfile,unittest,sys
sys.dont_write_bytecode=True
H=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('bridge',H/'run_bridge.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
class Tests(unittest.TestCase):
 def setUp(self):
  self.old=(H/'baseline/SavedRoomRouteCollisionOracle.swift.txt').read_bytes()
  self.current=b.GUARD+self.old.replace(b.OLD_HEADER,b.NEW_HEADER,1)+b.TRAILER
  self.runner=(H/'baseline/run_native.py.txt').read_bytes()
 def test_exact_kernel_reversal(self):self.assertEqual(b.reverse_oracle(self.current),self.old)
 def test_algorithm_mutation_rejected(self):
  with self.assertRaises(ValueError):b.reverse_oracle(self.current.replace(b'collisionMargin: 0.0',b'collisionMargin: 0.1',1))
 def test_guard_mutation_rejected(self):
  with self.assertRaises(ValueError):b.reverse_oracle(self.current.replace(b'BLIND_COLLISION_ORACLE_TESTS',b'DEBUG',1))
 def test_header_mutation_rejected(self):
  with self.assertRaises(ValueError):b.reverse_oracle(self.current.replace(b'Shared independent',b'Other independent',1))
 def test_trailer_missing_rejected(self):
  with self.assertRaises(ValueError):b.reverse_oracle(self.current[:-1])
 def test_runner_mutation_rejected(self):
  with self.assertRaises(ValueError):b.transform_runner(self.runner.replace(b'DEADLINE=START+300',b'DEADLINE=START+301'))
 def test_exact_flag_and_controls(self):
  text=b.transform_runner(self.runner)
  self.assertEqual(text.count("'swiftc','-D','BLIND_COLLISION_ORACLE_TESTS'"),1)
  for line in self.runner.decode().splitlines():
   if any(s in line for s in ['all50OriginalControlsReproduced','candidateRequests','checks\':51','DEADLINE=START+300','resource.setrlimit','GITHUB_REPOSITORY','GITHUB_REF']):self.assertIn(line,text)
 def test_prepare_and_nonoracle_pin_mutation(self):
  with tempfile.TemporaryDirectory()as tmp:
   p=pathlib.Path(tmp);lane=p/b.LANE;lane.mkdir(parents=True);(lane/'run_native.py').write_bytes(self.runner);(lane/'NATIVE_SOURCE_PINS.json').write_bytes((H/'baseline/NATIVE_SOURCE_PINS.json').read_bytes());oracle=p/b.ORACLE;oracle.parent.mkdir(parents=True);oracle.write_bytes(self.current)
   original,text,receipt,pin=b.prepare(p);self.assertTrue(receipt['oracleKernelByteIdentical']);pin(oracle,b.OLD_ORACLE)
   f=p/'other';f.write_bytes(b'fixed');pin(f,b.digest(b'fixed'));f.write_bytes(b'changed')
   with self.assertRaises(ValueError):pin(f,b.digest(b'fixed'))
   oracle.write_bytes(self.current+b'\n')
   with self.assertRaises(ValueError):pin(oracle,b.OLD_ORACLE)
if __name__=='__main__':unittest.main()
