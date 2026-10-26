import hashlib,json,pathlib,stat,tempfile,unittest,zipfile
from checkpoint import verify
class Test(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=pathlib.Path(self.t.name);self.ws=self.root/'ws';self.ws.mkdir()
 def archive(self, files=None, manifest=None, extra=None):
  files={'room/a.txt':b'hello'} if files is None else files
  rows=[dict(path=k,bytes=len(v),sha256=hashlib.sha256(v).hexdigest()) for k,v in files.items()]
  p=self.root/'a.zip'
  with zipfile.ZipFile(p,'w') as z:
   z.writestr('MANIFEST.json',json.dumps({'files':rows} if manifest is None else manifest))
   for k,v in files.items():z.writestr(k,v)
   if extra: extra(z)
  return p,{'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 def test_dry_restore_idempotent(self):
  p,e=self.archive();r=verify(p,e,self.ws);self.assertFalse(list(self.ws.iterdir()));self.assertEqual(r['filesVerified'],1)
  verify(p,e,self.ws,True);self.assertEqual((self.ws/'room/a.txt').read_bytes(),b'hello');self.assertFalse((self.ws/'MANIFEST.json').exists());self.assertEqual(verify(p,e,self.ws)['alreadyIdentical'],1)
 def test_archivehash(self):
  p,e=self.archive();e['sha256']='0'*64
  with self.assertRaises(ValueError):verify(p,e,self.ws,True)
 def test_memberhash(self):
  p,e=self.archive(manifest={'files':[dict(path='room/a.txt',bytes=5,sha256='0'*64)]})
  with self.assertRaises(ValueError):verify(p,e,self.ws,True)
 def test_unsafe_paths(self):
  for k in ['../bad','/bad','a/../bad','a\\bad','C:/bad','a//bad']:
   p,e=self.archive({k:b'x'})
   with self.assertRaises(ValueError):verify(p,e,self.ws,True)
 def test_duplicate_zip(self):
  p,e=self.archive(extra=lambda z:z.writestr('room/a.txt',b'hello'))
  with self.assertRaises(ValueError):verify(p,e,self.ws)
 def test_duplicate_manifest(self):
  row=dict(path='room/a.txt',bytes=5,sha256=hashlib.sha256(b'hello').hexdigest());p,e=self.archive(manifest={'files':[row,row]})
  with self.assertRaises(ValueError):verify(p,e,self.ws)
 def test_unlisted_missing(self):
  p,e=self.archive(extra=lambda z:z.writestr('surprise',b'x'))
  with self.assertRaises(ValueError):verify(p,e,self.ws)
  p,e=self.archive({}, {'files':[dict(path='absent',bytes=0,sha256=hashlib.sha256(b'').hexdigest())]})
  with self.assertRaises(ValueError):verify(p,e,self.ws)
 def test_symlink_zip(self):
  def add(z):
   i=zipfile.ZipInfo('link');i.create_system=3;i.external_attr=(stat.S_IFLNK|0o777)<<16;z.writestr(i,b'/tmp')
  p,e=self.archive(extra=add)
  with self.assertRaises(ValueError):verify(p,e,self.ws)
 def test_symlink_destination(self):
  p,e=self.archive();(self.ws/'room').symlink_to(self.root,target_is_directory=True)
  with self.assertRaises(ValueError):verify(p,e,self.ws,True)
 def test_divergence_preflight(self):
  p,e=self.archive({'first/missing':b'x','last/existing':b'x'});(self.ws/'last').mkdir();(self.ws/'last/existing').write_bytes(b'different')
  with self.assertRaises(ValueError):verify(p,e,self.ws,True)
  self.assertFalse((self.ws/'first').exists())
 def test_prefix_conflict(self):
  p,e=self.archive({'a':b'x','a/b':b'y'})
  with self.assertRaises(ValueError):verify(p,e,self.ws,True)
  self.assertFalse(list(self.ws.iterdir()))
 def test_parts_and_dependencies(self):
  frozen=json.dumps({'files':{'raw/not-in-packet':hashlib.sha256(b'raw').hexdigest()}}).encode();rows=[dict(path='room/FROZEN.json',bytes=len(frozen),sha256=hashlib.sha256(frozen).hexdigest(),group='one'),dict(path='other',bytes=0,sha256=hashlib.sha256(b'').hexdigest(),group='two')]
  p,e=self.archive({'room/FROZEN.json':frozen},{'files':rows});e['group']='one';r=verify(p,e,self.ws);self.assertEqual(r['missingPinnedDependencies'],['raw/not-in-packet']);self.assertFalse(r['standaloneCompletenessClaimed'])
if __name__=='__main__':unittest.main(verbosity=2)
