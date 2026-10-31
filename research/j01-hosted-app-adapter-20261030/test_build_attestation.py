"""Portable identity/tamper controls, not a native build or authenticated CI run."""
import copy,hashlib,importlib.util,json,os,pathlib,plistlib,subprocess,tempfile,unittest,time
P=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('a',P/'build_attestation.py');a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
class IdentityTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=pathlib.Path(self.temp.name).resolve(strict=True)
  app=self.root/'Product/App.app';bundle=app/'PlugIns/BlindAssistTests.xctest'
  for directory,name in [(app,'App'),(bundle,'Tests')]:
   directory.mkdir(parents=True);(directory/'Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable':name}))
   exe=directory/name;exe.write_bytes(b'\xcf\xfa\xed\xfe'+b'authored fixture NOT native code');exe.chmod(0o700)
  self.app=app;self.bundle=bundle
  self.run=self.root/'build.xctestrun';self.run.write_bytes(plistlib.dumps({'TestConfigurations':[{'TestTargets':[{'BlueprintName':'BlindAssistTests','TestHostPath':'__TESTROOT__/Product/App.app/App','TestBundlePath':'__TESTHOST__/PlugIns/BlindAssistTests.xctest'}]}]}))
  self.ci={'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':'mischa23v/blind','GITHUB_SHA':'a'*40,'GITHUB_RUN_ID':'1','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'fixture','GITHUB_WORKFLOW_REF':'mischa23v/blind/.github/workflows/native-apple.yml@refs/heads/main'}
  context=a.ci_context(self.ci);provenance={'actual_head':'a'*40,'tracked_source_clean':True}
  self.receipt={'schema':'j01-build-receipt-v1','sourceCommit':'a'*40,'ci':context,'before':{'schema':'j01-build-begin-v1','ci':context,'provenance':provenance},'after':provenance,'buildCommand':{'exit_code':0,'argv':['xcodebuild','build-for-testing']},'artifacts':a.selection(self.root,'build.xctestrun'),'provenanceHelperSHA256':a.HELPER_SHA,'lockParserSHA256':a.LOCK_SHA}
  self.file=self.root/'receipt.json';self.pin=self.save(self.receipt)
 def save(self,r):
  self.file.write_bytes(a.canonical(r));return hashlib.sha256(self.file.read_bytes()).hexdigest()
 def verify(self,pin=None):return a.verify(self.root,'build.xctestrun',self.file,pin or self.pin,'a'*40)
 def test_synthetic_identity_only(self):
  proof=self.verify();self.assertTrue(proof['verified']);self.assertFalse(proof['runtimeLoadedBinaryVerified']);self.assertIn('extern',proof['trustBasis'])
 def test_untrusted_or_wrong_receipt_digest(self):
  for pin in ['', 'b'*64]:
   with self.assertRaises(ValueError):a.verify(self.root,'build.xctestrun',self.file,pin,'a'*40)
 def test_executable_mutation(self):
  (self.app/'App').write_bytes(b'changed')
  with self.assertRaises(ValueError):self.verify()
 def test_test_executable_mutation(self):
  (self.bundle/'Tests').write_bytes(b'\xcf\xfa\xed\xfechanged')
  with self.assertRaises(ValueError):self.verify()
 def test_added_bundle_resource(self):
  (self.app/'extra').write_text('new')
  with self.assertRaises(ValueError):self.verify()
 def test_removed_resource(self):
  (self.bundle/'Info.plist').unlink()
  with self.assertRaises((ValueError,OSError)):self.verify()
 def test_symlink_bundle_file(self):
  (self.app/'link').symlink_to(self.file)
  with self.assertRaises(ValueError):self.verify()
 def test_symlink_directory(self):
  (self.app/'linkdir').symlink_to(self.root,target_is_directory=True)
  with self.assertRaises(ValueError):self.verify()
 def test_unsafe_relative_paths(self):
  for p in ['../escape','/absolute','a/../b','a\\b','a//b','']:
   with self.subTest(p=p),self.assertRaises(ValueError):a.relpath(p)
 def test_wrong_receipt_fields_even_reapproved_fixture(self):
  for key,val in [('sourceCommit','b'*40),('schema','other'),('lockParserSHA256','b'*64)]:
   r=copy.deepcopy(self.receipt);r[key]=val;pin=self.save(r)
   with self.assertRaises(ValueError):self.verify(pin)
 def test_command_failure(self):
  for code in [1,False]:
   r=copy.deepcopy(self.receipt);r['buildCommand']['exit_code']=code;pin=self.save(r)
   with self.assertRaises(ValueError):self.verify(pin)
 def test_wrong_command(self):
  for argv in [[],['true'],['xcodebuild','test']]:
   r=copy.deepcopy(self.receipt);r['buildCommand']['argv']=argv;pin=self.save(r)
   with self.assertRaises(ValueError):self.verify(pin)
 def test_before_after_mismatch(self):
  r=copy.deepcopy(self.receipt);r['after']['actual_head']='b'*40;pin=self.save(r)
  with self.assertRaises(ValueError):self.verify(pin)
 def test_duplicate_json_keys(self):
  self.file.write_text('{"a":1,"a":2}')
  with self.assertRaises(ValueError):a.read_json(self.file)
 def test_bounds(self):
  with self.assertRaises(ValueError):a.digest(self.app/'App',1)
 def test_escaping_host_and_test_bundle_paths(self):
  original=plistlib.loads(self.run.read_bytes())
  for key,value in [('TestHostPath','__TESTROOT__/../outside/App.app/App'),('TestBundlePath','__TESTROOT__/../outside/Tests.xctest')]:
   bad=copy.deepcopy(original);bad['TestConfigurations'][0]['TestTargets'][0][key]=value;self.run.write_bytes(plistlib.dumps(bad))
   with self.subTest(key=key),self.assertRaises(ValueError):a.selection(self.root,'build.xctestrun')
 def test_absolute_outside_artifact_rejected(self):
  original=plistlib.loads(self.run.read_bytes());original['TestConfigurations'][0]['TestTargets'][0]['TestHostPath']='/tmp/outside/App.app/App';self.run.write_bytes(plistlib.dumps(original))
  with self.assertRaises((ValueError,OSError)):a.selection(self.root,'build.xctestrun')
 def test_fifo_refused_before_open(self):
  from unittest.mock import patch
  fifo=self.root/'fifo';os.mkfifo(fifo)
  with patch.object(a.os,'open',side_effect=AssertionError('must reject FIFO before opening')):
   with self.assertRaises(ValueError):a.digest(fifo)
 def test_regular_open_is_nonblocking_and_nofollow(self):
  from unittest.mock import patch
  actual=os.open;flags=[]
  def recording(path,value):flags.append(value);return actual(path,value)
  with patch.object(a.os,'open',side_effect=recording):a.stable_bytes(self.app/'App',1024)
  self.assertTrue(flags)
  for flag in flags:self.assertTrue(flag & os.O_NONBLOCK);self.assertTrue(flag & os.O_NOFOLLOW)
 def test_expired_hash_budget(self):
  token=a.DEADLINE.set(time.monotonic()-1)
  try:
   with self.assertRaises(ValueError):a.digest(self.app/'App')
  finally:a.DEADLINE.reset(token)
  with self.assertRaises(ValueError):a.verify(self.root,'build.xctestrun',self.file,self.pin,'a'*40,max_seconds=0)
 def test_wrong_ci(self):
  for key,value in [('GITHUB_ACTIONS','false'),('GITHUB_REPOSITORY','other/repo'),('GITHUB_RUN_ID','no'),('GITHUB_SHA','no')]:
   with self.assertRaises(ValueError):a.ci_context(dict(self.ci,**{key:value}))
class TempRootTests(unittest.TestCase):
 def test_owned_temp_root_is_canonical_but_runtime_alias_stays_refused(self):
  from unittest.mock import patch
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp).resolve(strict=True);real=root/'real';real.mkdir()
   alias=root/'alias';alias.symlink_to(real,target_is_directory=True)
   with patch.object(tempfile,'tempdir',str(alias)):
    fixture=IdentityTests(methodName='test_synthetic_identity_only');fixture.setUp()
    try:
     self.assertTrue(fixture.root.is_relative_to(real));self.assertTrue(fixture.verify()['verified'])
     with self.assertRaises(ValueError):a.selection(alias/fixture.root.name,'build.xctestrun')
    finally:fixture.doCleanups()

class ActualProvenanceTests(unittest.TestCase):
 def test_existing_checker_real_clean_dirty_git(self):
  repo=pathlib.Path(os.environ.get('BLIND_SOURCE_REPO',pathlib.Path(__file__).resolve().parents[2]))
  with tempfile.TemporaryDirectory() as tmp:
   root=pathlib.Path(tmp).resolve(strict=True)
   for name in [a.HELPER,a.LOCK]:
    data=(repo/name).read_bytes() # actual-current bytes, never an old Git HEAD fallback
    self.assertEqual(hashlib.sha256(data).hexdigest(),{a.HELPER:a.HELPER_SHA,a.LOCK:a.LOCK_SHA}[name])
    path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
   # Use the EXACT reviewed helper, not a mock provenance return.
   for cmd in [['git','init','-q'],['git','add','.'],['git','-c','user.name=Fixture','-c','user.email=fixture@invalid.local','commit','-qm','authored checker fixture']]:subprocess.run(cmd,cwd=root,check=True,timeout=5,stdout=subprocess.DEVNULL)
   sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,timeout=5).decode().strip()
   self.assertTrue(a.source_provenance(root,sha)['tracked_source_clean'])
   env={'GITHUB_ACTIONS':'true','GITHUB_REPOSITORY':'mischa23v/blind','GITHUB_SHA':sha,'GITHUB_RUN_ID':'1','GITHUB_RUN_ATTEMPT':'1','GITHUB_JOB':'fixture','GITHUB_WORKFLOW_REF':'mischa23v/blind/.github/workflows/native-apple.yml@refs/heads/main'}
   before=a.begin(root,env)
   artifact=IdentityTests(methodName='test_synthetic_identity_only');artifact.setUp()
   try:
    # No actual build: this is explicitly an authored producer contract fixture.
    command={'exit_code':0,'argv':['xcodebuild','build-for-testing']}
    receipt=a.finish(root,env,before,command,artifact.root,'build.xctestrun')
    self.assertEqual(receipt['sourceCommit'],sha)
    self.assertIn('untrusted',receipt['producerTrust'])
    self.assertFalse(receipt['nativeTestExecutedByRecorder'])
    # Authored first-resolution transition: the unchanged exact public-pin
    # parser permits creation, but strict attestation forbids it AFTER begin.
    lock=root/'ios/BlindAssist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved'
    lock.parent.mkdir(parents=True,exist_ok=True)
    value={'version':3,'pins':[{'identity':'grdb.swift','kind':'remoteSourceControl','location':'https://github.com/groue/GRDB.swift.git','state':{'revision':'b83108d10f42680d78f23fe4d4d80fc88dab3212','version':'7.11.1'}}]}
    lock.write_text(json.dumps(value))
    with self.assertRaisesRegex(ValueError,'source changed across build'):a.finish(root,env,before,command,artifact.root,'build.xctestrun')
    resolved=a.begin(root,env)
    stable=a.finish(root,env,resolved,command,artifact.root,'build.xctestrun')
    self.assertEqual(stable['before']['provenance'],stable['after'])
    value['originHash']='a'*64;lock.write_text(json.dumps(value))
    with self.assertRaisesRegex(ValueError,'source changed across build'):a.finish(root,env,resolved,command,artifact.root,'build.xctestrun')
    value['pins'][0]['state']['revision']='0'*40;lock.write_text(json.dumps(value))
    with self.assertRaises(ValueError):a.begin(root,env)
    lock.unlink();lock.symlink_to(artifact.root/'build.xctestrun')
    with self.assertRaises(ValueError):a.begin(root,env)
    lock.unlink()
    for bad in [dict(command,exit_code=1),dict(command,exit_code=False),dict(command,argv=[])]:
     with self.assertRaises(ValueError):a.finish(root,env,before,bad,artifact.root,'build.xctestrun')
    stale=copy.deepcopy(before);stale['createdAt']=0
    with self.assertRaises(ValueError):a.finish(root,env,stale,command,artifact.root,'build.xctestrun')
   finally:artifact.doCleanups()

   with self.assertRaises(ValueError):a.source_provenance(root,'0'*40)
   (root/'ios').mkdir(exist_ok=True);(root/'ios/untracked.swift').write_text('// untracked')
   with self.assertRaises(ValueError):a.source_provenance(root,sha)
   (root/'ios/untracked.swift').unlink();(root/a.LOCK).write_text('changed')
   with self.assertRaises(ValueError):a.source_provenance(root,sha)
if __name__=='__main__':unittest.main()
