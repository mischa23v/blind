#!/usr/bin/env python3
"""SOURCE ONLY: unchanged original 47 + exact-XYZ 10 + native-policy 10 authored controls."""
import pathlib,sys,unittest,hashlib,json,os
CANDIDATE=pathlib.Path(__file__).resolve().parent
ROOT=CANDIDATE.parent
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/'exact-xyz-candidate'))
for key in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[key]='1'
sys.dont_write_bytecode=True
if len(sys.argv)!=5:raise RuntimeError('supply original/candidate pins SHA256, native library path and SHA256')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if sha(ROOT/'SOURCE_PINS.json')!=sys.argv[1]:raise RuntimeError('manifest mismatch')
for p,h in json.loads((ROOT/'SOURCE_PINS.json').read_text())['files'].items():
 if sha(ROOT/p)!=h:raise RuntimeError('source mismatch '+p)
if sha(CANDIDATE/'CANDIDATE_PINS.json')!=sys.argv[2]:raise RuntimeError('candidate manifest mismatch')
for p,h in json.loads((CANDIDATE/'CANDIDATE_PINS.json').read_text())['files'].items():
 if sha(CANDIDATE/p)!=h:raise RuntimeError('candidate source mismatch '+p)
UP=ROOT/'upstream'
for p in [UP/'blind-split-candidate-game-03/source',UP/'blind-split-candidate-game-03/ground-follow-v2',UP/'blind-opus-reference-scoring-audit-02/source',UP/'blind-koivu-reference-comparison-06']:
 sys.path.insert(0,str(p))
import support_functions
# Exact extracted functions satisfy the test module import; never import old controller/main.
sys.modules['run_ground_pilot']=support_functions
import test_native_planner_ground as native_tests
native_tests.NATIVE_LIBRARY_PATH=sys.argv[3];native_tests.NATIVE_LIBRARY_SHA256=sys.argv[4]
suite=unittest.TestSuite()
for module in ('test_oriented_container','test_ground_support','test_ground_physics','test_oriented_ground_container','test_coffee_frame_controls','test_exact_xyz_ground_support','test_native_planner_ground'):
 suite.addTests(unittest.defaultTestLoader.loadTestsFromName(module))
result=unittest.TextTestRunner(verbosity=2).run(suite)
sys.exit(0 if result.wasSuccessful() else 2)
