import copy,gzip,json,tempfile,unittest
from pathlib import Path
import restore_results as r
class T(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.p=Path(self.t.name);self.raw=b'{"unchanged":true}\n';self.gz=gzip.compress(self.raw,mtime=0);(self.p/'r.gz').write_bytes(self.gz);self.out=self.p/'RESULT.json';self.d={'format':'exact-original-gzip-v1','assets':[{'asset':'sample','storedPath':'r.gz','filename':'RESULT.json','originalBytes':len(self.raw),'originalSHA256':r.sha(self.raw),'gzipBytes':len(self.gz),'gzipSHA256':r.sha(self.gz)}]}
 def tearDown(self):self.t.cleanup()
 def go(self,expected=None):
  p=self.p/'manifest.json';p.write_text(json.dumps(self.d));return r.restore(p,expected or r.sha(p.read_bytes()),'sample',self.out)
 def test_exact(self):self.go();self.assertEqual(self.out.read_bytes(),self.raw)
 def test_no_overwrite(self):
  self.out.write_bytes(b'existing')
  with self.assertRaises(FileExistsError):self.go()
  self.assertEqual(self.out.read_bytes(),b'existing')
 def test_manifest_hash(self):
  with self.assertRaises(ValueError):self.go('0'*64)
 def test_wrong_original_hash(self):
  self.d['assets'][0]['originalSHA256']='0'*64
  with self.assertRaises(ValueError):self.go()
  self.assertFalse(self.out.exists());self.assertFalse(self.out.with_name('RESULT.json.partial').exists())
 def test_expanded_size(self):
  self.d['assets'][0]['originalBytes']=1
  with self.assertRaises(ValueError):self.go()
 def test_traversal(self):
  self.d['assets'][0]['storedPath']='../r.gz'
  with self.assertRaises(ValueError):self.go()
 def test_symlink(self):
  (self.p/'r.gz').unlink();(self.p/'r.gz').symlink_to(self.p/'manifest.json')
  with self.assertRaises(ValueError):self.go()
 def test_partial(self):
  self.out.with_name('RESULT.json.partial').write_bytes(b'preserve')
  with self.assertRaises(FileExistsError):self.go()
 def test_wrong_name(self):
  self.out=self.p/'renamed.json'
  with self.assertRaises(ValueError):self.go()
if __name__=='__main__':unittest.main(verbosity=2)
