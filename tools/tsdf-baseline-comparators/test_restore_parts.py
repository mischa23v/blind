"""Small byte fixtures only; no native imports, reconstruction, or recorded data."""
import copy,hashlib,json,tempfile,unittest
from pathlib import Path
import restore_parts as r
class RestoreTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.root=Path(self.t.name);self.out=self.root/'out';self.out.mkdir();self.parts=self.root/'parts';self.parts.mkdir();self.data=b'byte-exact\x00\xffpayload';self.base={'format':'ordered-byte-parts-v1','assets':{'fixture':{'filename':'sample.ply','bytes':len(self.data),'sha256':r.sha(self.data),'parts':[]}}}
  for i,b in enumerate([self.data[:6],self.data[6:]]):
   p=self.parts/str(i);p.write_bytes(b);self.base['assets']['fixture']['parts'].append({'index':i,'path':f'parts/{i}','bytes':len(b),'sha256':r.sha(b)})
 def tearDown(self):self.t.cleanup()
 def run_case(self,d=None,expected_sha=None):
  p=self.root/'manifest.json';p.write_text(json.dumps(d or self.base));return r.restore(p,expected_sha or r.sha(p.read_bytes()),'fixture',self.out)
 def test_restore_exact(self):self.run_case();self.assertEqual((self.out/'sample.ply').read_bytes(),self.data)
 def test_no_overwrite(self):
  (self.out/'sample.ply').write_bytes(b'existing')
  with self.assertRaises(FileExistsError):self.run_case()
  self.assertEqual((self.out/'sample.ply').read_bytes(),b'existing')
 def test_no_partial_overwrite(self):
  (self.out/'sample.ply.partial').write_bytes(b'partial')
  with self.assertRaises(FileExistsError):self.run_case()
 def test_bad_manifest_hash(self):
  with self.assertRaises(ValueError):self.run_case(expected_sha='0'*64)
 def test_bad_part_hash(self):
  (self.parts/'0').write_bytes(b'broken')
  with self.assertRaises(ValueError):self.run_case()
  self.assertFalse((self.out/'sample.ply').exists());self.assertFalse((self.out/'sample.ply.partial').exists())
 def test_bad_final_hash(self):
  d=copy.deepcopy(self.base);d['assets']['fixture']['sha256']='0'*64
  with self.assertRaises(ValueError):self.run_case(d)
 def test_traversal(self):
  for name in ['../escape','/absolute','parts/../0','parts//0','parts\\0']:
   d=copy.deepcopy(self.base);d['assets']['fixture']['parts'][0]['path']=name
   with self.subTest(name=name),self.assertRaises(ValueError):self.run_case(d)
 def test_bad_output_name(self):
  d=copy.deepcopy(self.base);d['assets']['fixture']['filename']='../bad'
  with self.assertRaises(ValueError):self.run_case(d)
 def test_duplicate_part(self):
  d=copy.deepcopy(self.base);d['assets']['fixture']['parts'][1]['path']='parts/0'
  with self.assertRaises(ValueError):self.run_case(d)
 def test_part_symlink(self):
  (self.parts/'0').unlink();(self.parts/'0').symlink_to(self.parts/'1')
  with self.assertRaises(ValueError):self.run_case()
 def test_output_symlink(self):
  q=self.root/'alias';q.symlink_to(self.out,target_is_directory=True);self.out=q
  with self.assertRaises(ValueError):self.run_case()
 def test_wrong_sequence(self):
  d=copy.deepcopy(self.base);d['assets']['fixture']['parts'].reverse()
  with self.assertRaises(ValueError):self.run_case(d)
 def test_size_cap(self):
  d=copy.deepcopy(self.base);d['assets']['fixture']['parts'][0]['bytes']=r.MAX_PART+1
  with self.assertRaises(ValueError):self.run_case(d)
if __name__=='__main__':unittest.main(verbosity=2)
