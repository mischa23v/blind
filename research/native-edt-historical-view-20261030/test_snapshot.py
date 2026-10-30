#!/usr/bin/env python3
"""Portable source-only controls. No native/compiler/CI subprocesses."""
import importlib.util,json,pathlib,tempfile,unittest
SPEC=importlib.util.spec_from_file_location('snapshot',pathlib.Path(__file__).with_name('run_snapshot.py'))
m=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(m)
class Tests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=pathlib.Path(self.tmp.name)
  self.env={'GITHUB_REPOSITORY':'mischa23v/blind','GITHUB_REF':'refs/heads/master','GITHUB_SHA':'a'*40}
 def tearDown(self): self.tmp.cleanup()
 def git(self,args): return 'a'*40 if args==['rev-parse','HEAD'] else ''
 def test_actual_checkout(self): self.assertEqual(m.authorize_checkout(self.root,self.env,self.git),'a'*40)
 def test_wrong_head(self):
  with self.assertRaises(ValueError): m.authorize_checkout(self.root,{**self.env,'GITHUB_SHA':'b'*40},self.git)
 def test_wrong_repository(self):
  with self.assertRaises(ValueError): m.authorize_checkout(self.root,{**self.env,'GITHUB_REPOSITORY':'other/blind'},self.git)
 def test_wrong_ref(self):
  with self.assertRaises(ValueError): m.authorize_checkout(self.root,{**self.env,'GITHUB_REF':'refs/pull/1/merge'},self.git)
 def view(self):
  pins={'source.txt':m.digest(b'exact')};(self.root/'source.txt').write_bytes(b'exact')
  dest=self.root/m.LANE/'NATIVE_SOURCE_PINS.json';dest.parent.mkdir(parents=True);dest.write_bytes((m.HERE/'baseline/NATIVE_SOURCE_PINS.json').read_bytes());return pins
 def test_exact_view(self): m.verify_view(self.root,self.view())
 def test_altered_view(self):
  pins=self.view();(self.root/'source.txt').write_bytes(b'changed')
  with self.assertRaises(ValueError): m.verify_view(self.root,pins)
 def test_missing_view(self):
  pins=self.view();(self.root/'source.txt').unlink()
  with self.assertRaises(ValueError): m.verify_view(self.root,pins)
 def test_extra_header_rejected(self):
  pins=self.view();(self.root/'optional_veto.h').write_text('new algorithm')
  with self.assertRaises(ValueError): m.verify_view(self.root,pins)
 def test_symlink_rejected(self):
  pins=self.view();(self.root/'source.txt').unlink();(self.root/'source.txt').symlink_to('/dev/null')
  with self.assertRaises(ValueError): m.verify_view(self.root,pins)
 def test_path_escape(self):
  with self.assertRaises(ValueError): m.safe_file(self.root,'../outside')
 def test_manifest_and_overrides(self):
  _,pins=m.load_pins();self.assertEqual(len(pins),58)
  overrides=json.loads((m.HERE/'OVERRIDES.json').read_text());self.assertEqual(len(overrides),3)
  for name,o in overrides.items(): self.assertEqual(m.digest((m.HERE/o['file']).read_bytes()),pins[name])
 def test_exact_runner_transform(self):
  original=(m.HERE/'baseline/run_native.py.txt').read_bytes();text,replacements=m.transform_runner(original)
  for old,new in reversed(replacements): text=text.replace(new,old,1)
  self.assertEqual(text.encode(),original)
  adapted,_=m.transform_runner(original)
  self.assertIn('cwd=_workflow_checkout',adapted);self.assertNotIn('cwd=ROOT',adapted)
  for marker in ["assert head==receipt['sourceCommit']","assert data['candidateRequests']==(25 if data['candidateExecuted'] else 0)","assert data['candidateExecuted']==data['all50OriginalControlsReproduced']","resource.RLIMIT_CPU,(120,120)","128*1024**2","DEADLINE=START+300","assert path.is_file() and sha(path)==digest"]: self.assertIn(marker,adapted)
 def test_changed_runner_rejected(self):
  with self.assertRaises(ValueError): m.transform_runner(b'new runner')
if __name__=='__main__': unittest.main()
