"""Small NPY serialization equivalence controls; no OctoMap or dataset access."""
import os
os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1'
import importlib.util,pathlib,unittest,io,hashlib
import numpy as np
p=pathlib.Path(__file__).with_name('evaluate.py');s=importlib.util.spec_from_file_location('ablation',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class StreamHashTests(unittest.TestCase):
 def compare(self,a):
  b=io.BytesIO();np.lib.format.write_array(b,a,allow_pickle=False);raw=b.getvalue();self.assertEqual(m.canonical_array_digest(np,a),{'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)})
 def test_float64_leaf_matrix(self):self.compare(np.arange(150,dtype=np.float64).reshape(30,5))
 def test_float32_log_odds(self):self.compare(np.linspace(-3,3,101,dtype=np.float32))
 def test_uint32_votes(self):self.compare(np.arange(101,dtype=np.uint32))
 def test_empty(self):self.compare(np.empty((0,5),np.float64))
 def test_fortran_and_noncontiguous(self):
  self.compare(np.asfortranarray(np.arange(60).reshape(12,5)));self.compare(np.arange(60).reshape(12,5)[::2])
 def test_no_data_retention(self):
  w=m.HashWriter();self.assertEqual(w.write(b'abc'),3);self.assertEqual(w.bytes,3);self.assertEqual(set(w.__dict__),{'digest','bytes'})
if __name__=='__main__':unittest.main(verbosity=2)
