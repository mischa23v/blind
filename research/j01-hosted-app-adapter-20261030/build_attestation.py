#!/usr/bin/env python3
"""Source/selected-binary identity, NOT a self-authenticating build certificate."""
import contextvars
import argparse,hashlib,importlib.util,json,os,pathlib,plistlib,re,stat,sys,time
HELPER='tools/ci/export-native-unit-statuses.py'
HELPER_SHA='75b18b4b00b02b7da42453a4decec7ec043fb9672f66f463b5a0f5778f1dedfe'
LOCK='research/indoor-io-buffered-diagnostic/resolution.py'
LOCK_SHA='6590d0a2c60c3675cb131c4f8be2766c51147f0f3f009f40b41bc5db4801a740'
MAX_FILE=256*1024*1024;MAX_TOTAL=2*1024*1024*1024;MAX_FILES=8192
CASE='HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney'
DEADLINE=contextvars.ContextVar('hash_deadline',default=float('inf'))
def within_budget():require(time.monotonic()<DEADLINE.get(),'artifact observation time budget')
def require(ok,message):
 if not ok:raise ValueError(message)
def canonical(x):return json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False).encode()
def no_links(path):
 raw=pathlib.Path(path);require('..' not in raw.parts,'parent traversal refused')
 p=raw.absolute()
 for parent in [p,*p.parents]:require(not parent.is_symlink(),'symlink component refused')
 return p.resolve(strict=True)
def digest(path,cap=MAX_FILE):
 p=no_links(path);pre=p.lstat();require(stat.S_ISREG(pre.st_mode) and pre.st_size<=cap,'regular bounded file required before open')
 fd=os.open(p,os.O_RDONLY|getattr(os,'O_NOFOLLOW',0)|getattr(os,'O_NONBLOCK',0))
 try:
  a=os.fstat(fd);require(stat.S_ISREG(a.st_mode) and a.st_size<=cap,'regular bounded file required')
  h=hashlib.sha256();n=0
  while True:
   within_budget()
   chunk=os.read(fd,min(1024*1024,cap+1-n))
   if not chunk:break
   n+=len(chunk);require(n<=cap,'file grew beyond cap');h.update(chunk)
  b=os.fstat(fd);after=p.lstat()
  key=lambda s:(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_mode)
  require(key(a)==key(b)==key(after) and n==a.st_size,'file changed during hashing')
  return {'sha256':h.hexdigest(),'bytes':n,'executable':bool(a.st_mode&0o111)}
 finally:os.close(fd)
def stable_bytes(path,cap):
 expected=digest(path,cap);fd=os.open(no_links(path),os.O_RDONLY|getattr(os,'O_NOFOLLOW',0)|getattr(os,'O_NONBLOCK',0))
 try:
  info=os.fstat(fd);require(stat.S_ISREG(info.st_mode) and info.st_size<=cap,'regular bounded descriptor required')
  chunks=[];size=0
  while True:
   within_budget()
   b=os.read(fd,min(1024*1024,cap+1-size))
   if not b:break
   size+=len(b);require(size<=cap,'read budget');chunks.append(b)
  data=b''.join(chunks)
  require(len(data)==expected['bytes'] and hashlib.sha256(data).hexdigest()==expected['sha256'],'bytes changed between identity and read')
  return data
 finally:os.close(fd)
def read_json(path,cap=8*1024*1024):
 def unique(pairs):
  d={}
  for k,v in pairs:require(k not in d,'duplicate JSON key');d[k]=v
  return d
 return json.loads(stable_bytes(path,cap),object_pairs_hook=unique)
def relpath(value):
 require(isinstance(value,str) and 0<len(value)<=512 and '\\' not in value,'relative path shape')
 p=pathlib.PurePosixPath(value);require(not p.is_absolute() and all(x not in ('','.','..') for x in p.parts) and str(p)==value,'unsafe relative path')
 return p
def tree(root):
 root=no_links(root);require(root.is_dir(),'bundle directory required');files=[];total=0;directories=0
 for base,dirs,names in os.walk(root,followlinks=False):
  within_budget()
  directories+=1;require(directories<=MAX_FILES,'directory count budget')
  require(len(dirs)+len(names)<=MAX_FILES,'directory width budget')
  for name in dirs:require(not (pathlib.Path(base)/name).is_symlink(),'bundle directory symlink')
  for name in sorted(names):
   path=pathlib.Path(base)/name;relative=str(path.relative_to(root));relpath(relative)
   require(len(files)<MAX_FILES,'bundle file-count budget');item=digest(path);total+=item['bytes'];require(total<=MAX_TOTAL,'bundle byte budget')
   files.append(dict(path=relative,**item))
 files.sort(key=lambda x:x['path']);require(files,'empty bundle')
 return {'files':files,'bytes':total,'treeSHA256':hashlib.sha256(canonical(files)).hexdigest()}
def source_provenance(repo,expected):
 repo=no_links(repo)
 require(digest(repo/HELPER,1024*1024)['sha256']==HELPER_SHA,'reviewed provenance helper changed')
 require(digest(repo/LOCK,1024*1024)['sha256']==LOCK_SHA,'reviewed dependency lock parser changed')
 spec=importlib.util.spec_from_file_location('j01_existing_ci_provenance',repo/HELPER);module=importlib.util.module_from_spec(spec)
 old=sys.dont_write_bytecode
 try:sys.dont_write_bytecode=True;spec.loader.exec_module(module);return module.provenance(repo,expected)
 finally:sys.dont_write_bytecode=old
def ci_context(env):
 require(env.get('GITHUB_ACTIONS')=='true' and env.get('GITHUB_REPOSITORY')=='mischa23v/blind','reviewed CI context required')
 d={k:env.get(k,'') for k in ['GITHUB_REPOSITORY','GITHUB_SHA','GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB','GITHUB_WORKFLOW_REF']}
 require(re.fullmatch('[0-9a-f]{40}',d['GITHUB_SHA']) is not None,'workflow SHA')
 require(all(re.fullmatch('[1-9][0-9]{0,19}',d[k]) for k in ['GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT']),'CI run identity')
 require(re.fullmatch('[A-Za-z0-9_-]{1,100}',d['GITHUB_JOB']) is not None,'job identity')
 require(d['GITHUB_WORKFLOW_REF'].startswith('mischa23v/blind/.github/workflows/') and len(d['GITHUB_WORKFLOW_REF'])<=300,'workflow identity')
 return d
def _selection(root,descriptor):
 root=no_links(root);path=root/relpath(descriptor);raw=stable_bytes(path,4*1024*1024)
 obj=plistlib.loads(raw);targets=[t for c in obj.get('TestConfigurations',[]) for t in c.get('TestTargets',[]) if t.get('BlueprintName')=='BlindAssistTests'];require(len(targets)==1,'one hosted test target')
 t=targets[0]
 def resolve(v,host=None):
  require(isinstance(v,str),'artifact path')
  allowed={'__TESTROOT__'} | ({'__TESTHOST__'} if host is not None else set())
  require(set(re.findall(r'__[A-Z_]+__',v))<=allowed,'unsupported artifact placeholder')
  v=v.replace('__TESTROOT__',str(path.parent))
  if host is not None:v=v.replace('__TESTHOST__',str(host))
  p=no_links(v);require(p.is_relative_to(root),'artifact outside selected build root');return p
 host=resolve(t.get('TestHostPath'));app=host.parent;bundle=resolve(t.get('TestBundlePath'),app)
 require(app.suffix=='.app' and bundle.suffix=='.xctest','app/test bundle shapes')
 for directory,executable in [(app,host),(bundle,None)]:
  info=directory/'Info.plist';d=plistlib.loads(stable_bytes(info,1024*1024));name=d.get('CFBundleExecutable');require(isinstance(name,str) and '/' not in name and name not in ('','.','..'),'bundle executable name')
  selected=directory/name;require(executable is None or selected==executable,'host executable differs from Info.plist')
  identity=digest(selected);require(identity['executable'],'bundle executable mode')
  fd=os.open(no_links(selected),os.O_RDONLY|getattr(os,'O_NOFOLLOW',0)|getattr(os,'O_NONBLOCK',0))
  try:
   require(stat.S_ISREG(os.fstat(fd).st_mode),'regular executable descriptor required');magic=os.read(fd,4)
  finally:os.close(fd)
  require(magic in [b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca',b'\xca\xfe\xba\xbf',b'\xbf\xba\xfe\xca'],'Mach-O executable required')
 app_tree=tree(app);test_tree=tree(bundle);require(app_tree['bytes']+test_tree['bytes']<=MAX_TOTAL,'combined artifact byte budget')
 return {'descriptor':{'path':str(path.relative_to(root)),**digest(path,4*1024*1024)},'app':{'path':str(app.relative_to(root)),**app_tree},'tests':{'path':str(bundle.relative_to(root)),**test_tree}}
def selection(root,descriptor):
 token=DEADLINE.set(min(DEADLINE.get(),time.monotonic()+20))
 try:return _selection(root,descriptor)
 finally:DEADLINE.reset(token)
def begin(repo,env):
 context=ci_context(env);return {'schema':'j01-build-begin-v1','ci':context,'provenance':source_provenance(repo,context['GITHUB_SHA']),'createdAt':time.time()}
def finish(repo,env,before,command,root,descriptor):
 context=ci_context(env);require(before.get('schema')=='j01-build-begin-v1' and before.get('ci')==context,'build begin context mismatch')
 after=source_provenance(repo,context['GITHUB_SHA']);require(before.get('provenance')==after,'source changed across build')
 require(type(command.get('exit_code')) is int and command['exit_code']==0,'actual build command did not succeed')
 argv=command.get('argv');require(type(argv) is list and 1<=len(argv)<=128 and all(type(x) is str and len(x)<=4096 for x in argv),'command shape')
 require(pathlib.Path(argv[0]).name=='xcodebuild' and 'build-for-testing' in argv,'actual build-for-testing command required')
 require(0<=time.time()-before.get('createdAt',0)<=3600,'begin age')
 artifacts=selection(root,descriptor)
 require(source_provenance(repo,context['GITHUB_SHA'])==after,'source changed during artifact capture')
 return {'schema':'j01-build-receipt-v1','sourceCommit':context['GITHUB_SHA'],'ci':context,'before':before,'after':after,'buildCommand':command,'artifacts':artifacts,'producerTrust':'untrusted until independently authenticated build evidence and receipt digest approved','nativeTestExecutedByRecorder':False,'provenanceHelperSHA256':HELPER_SHA,'lockParserSHA256':LOCK_SHA}
def _verify(root,descriptor,receipt_path,trusted_sha,source):
 require(re.fullmatch('[0-9a-f]{64}',trusted_sha or '') is not None,'independently trusted receipt digest required')
 require(digest(receipt_path,8*1024*1024)['sha256']==trusted_sha,'receipt digest mismatch')
 receipt_bytes=stable_bytes(receipt_path,8*1024*1024);require(hashlib.sha256(receipt_bytes).hexdigest()==trusted_sha,'receipt changed after approved digest check')
 receipt=read_json(receipt_path);require(hashlib.sha256(canonical(receipt)).hexdigest()==hashlib.sha256(canonical(json.loads(receipt_bytes))).hexdigest(),'receipt content changed during parse');require(receipt.get('schema')=='j01-build-receipt-v1' and receipt.get('sourceCommit')==source,'receipt source mismatch')
 context=ci_context(dict(receipt['ci'],GITHUB_ACTIONS='true'))
 require(context['GITHUB_SHA']==source and receipt['before']['ci']==context and receipt['before']['provenance']==receipt['after'],'receipt provenance mismatch')
 require(receipt['after'].get('actual_head')==source and receipt['after'].get('tracked_source_clean') is True,'source clean proof missing')
 require(type(receipt['buildCommand'].get('exit_code')) is int and receipt['buildCommand']['exit_code']==0,'build failed')
 argv=receipt['buildCommand'].get('argv');require(type(argv) is list and 1<=len(argv)<=128 and all(type(x) is str and len(x)<=4096 for x in argv),'build command shape')
 require(pathlib.Path(argv[0]).name=='xcodebuild' and 'build-for-testing' in argv,'build command identity')
 require(receipt.get('provenanceHelperSHA256')==HELPER_SHA and receipt.get('lockParserSHA256')==LOCK_SHA,'provenance implementation pins')
 require(receipt['before'].get('schema')=='j01-build-begin-v1','begin schema')
 actual=selection(root,descriptor);require(actual==receipt['artifacts'],'selected descriptor/app/test bytes differ from trusted build')
 return {'verified':True,'scope':'selected prebuilt artifact bytes match independently trusted build receipt; runtime load not attested','sourceCommit':source,'receiptSHA256':trusted_sha,'trustBasis':'external reviewed CI receipt digest, not caller source echo','runtimeLoadedBinaryVerified':False}
def verify(root,descriptor,receipt_path,trusted_sha,source,*,max_seconds=20):
 require(type(max_seconds) in (int,float) and 0<max_seconds<=20,'bounded verification time required')
 token=DEADLINE.set(time.monotonic()+max_seconds)
 try:return _verify(root,descriptor,receipt_path,trusted_sha,source)
 finally:DEADLINE.reset(token)
def main():
 a=argparse.ArgumentParser();a.add_argument('action',choices=['begin','finish']);a.add_argument('--repo',type=pathlib.Path,required=True);a.add_argument('--out',type=pathlib.Path,required=True);a.add_argument('--before',type=pathlib.Path);a.add_argument('--command',type=pathlib.Path);a.add_argument('--build-root',type=pathlib.Path);a.add_argument('--descriptor');args=a.parse_args()
 require(not args.out.exists(),'fresh receipt output required')
 result=begin(args.repo,os.environ) if args.action=='begin' else finish(args.repo,os.environ,read_json(args.before),read_json(args.command),args.build_root,args.descriptor)
 with args.out.open('xb') as f:f.write(canonical(result)+b'\n')
if __name__=='__main__':main()
