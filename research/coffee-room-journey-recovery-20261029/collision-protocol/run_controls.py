#!/usr/bin/env python3
"""Prepared, NOT RUN. Existing authored suites, isolated from historical controller."""
import pathlib,sys,unittest,hashlib,json,os
ROOT=pathlib.Path(__file__).resolve().parent
for key in ('OPENBLAS_NUM_THREADS','OMP_NUM_THREADS','MKL_NUM_THREADS'):os.environ[key]='1'
sys.dont_write_bytecode=True
if len(sys.argv)!=2:raise RuntimeError('supply externally reviewed SOURCE_PINS.json SHA256')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if sha(ROOT/'SOURCE_PINS.json')!=sys.argv[1]:raise RuntimeError('manifest mismatch')
for p,h in json.loads((ROOT/'SOURCE_PINS.json').read_text())['files'].items():
 if sha(ROOT/p)!=h:raise RuntimeError('source mismatch '+p)
UP=ROOT/'upstream'
for p in [UP/'blind-split-candidate-game-03/source',UP/'blind-split-candidate-game-03/ground-follow-v2',UP/'blind-opus-reference-scoring-audit-02/source',UP/'blind-koivu-reference-comparison-06']:
 sys.path.insert(0,str(p))
import support_functions
# Exact extracted functions satisfy the test module import; never import old controller/main.
sys.modules['run_ground_pilot']=support_functions
suite=unittest.TestSuite()
for module in ('test_oriented_container','test_ground_support','test_ground_physics','test_oriented_ground_container','test_coffee_frame_controls'):
 suite.addTests(unittest.defaultTestLoader.loadTestsFromName(module))
result=unittest.TextTestRunner(verbosity=2).run(suite)
sys.exit(0 if result.wasSuccessful() else 2)
