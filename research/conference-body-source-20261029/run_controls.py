#!/usr/bin/env python3
"""Prepared original sweep/all-hit controls + three floor-preservation controls."""
import argparse, hashlib, json, os, pathlib, sys, unittest
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
ap=argparse.ArgumentParser();ap.add_argument('--pins',type=pathlib.Path,required=True)
ap.add_argument('--pins-sha256',required=True);a=ap.parse_args()
def sha(p):
    with pathlib.Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
if sha(a.pins)!=a.pins_sha256:raise ValueError('manifest SHA mismatch')
pins=json.loads(a.pins.read_text())
for name,digest in pins['inputs'].items():
    path=name.replace('@WORKSPACE@',str(W)).replace('@REPO@',str(R))
    if not path.startswith('/'):path=str(R/path)
    if sha(path)!=digest:raise ValueError('source/input changed: '+name)
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'):os.environ[key]='1'
sys.dont_write_bytecode=True
up=R/'research/coffee-room-journey-recovery-20261029/collision-protocol/upstream'
for p in (up/'blind-split-candidate-game-03/source',up/'blind-split-candidate-game-03/ground-follow-v2',
          up/'blind-opus-reference-scoring-audit-02/source',up/'blind-koivu-reference-comparison-06'):
    sys.path.insert(0,str(p))
suite=unittest.TestSuite()
for name in ('test_oriented_container','test_oriented_ground_container','test_raw_floor'):
    suite.addTests(unittest.defaultTestLoader.loadTestsFromName(name))
result=unittest.TextTestRunner(verbosity=2).run(suite)
if result.skipped:raise RuntimeError('skipped control not admitted')
sys.exit(0 if result.wasSuccessful() else 2)
