#!/usr/bin/env python3
"""Explicit prebuilt simulator XCTest bridge. No build/download; authorized execution deploys only to the declared test simulator."""
import hashlib,json,os,pathlib,plistlib,re,signal,subprocess,sys,time
import build_attestation as attestation
HERE=pathlib.Path(__file__).resolve().parent
CASE='BlindAssistTests/HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney'
def require(ok,msg):
 if not ok:raise ValueError(msg)
def read(p,cap):
 p=pathlib.Path(p);require(p.is_file() and not p.is_symlink(),'regular file required')
 with p.open('rb') as f:b=f.read(cap+1)
 require(len(b)<=cap,'input budget');return b
def canonical(x):return json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False)
def validate(request,config):
 require(request.get('schema')=='instrumented-app-jsonl-v1','schema')
 require(re.fullmatch('[0-9a-f]{40}',config.get('source_commit','')) is not None,'commit')
 require(request.get('source_commit')==config['source_commit'],'source mismatch')
 supported=json.loads(read(HERE/'SUPPORTED.json',65536))
 require(request.get('scenario_id') in supported,'unsupported scenario')
 require(canonical(request.get('events'))==canonical(supported[request['scenario_id']]),'exact authored script required')
 require(canonical(request.get('constraints'))==canonical(dict(physical_actions=False,network=False,paid_services=False)),'constraints')
 require(config.get('ephemeral_simulator_no_accounts') is True,'dedicated empty simulator acknowledgment')
 require(re.fullmatch('[A-Fa-f0-9-]{36}',config.get('simulator_udid','')) is not None,'simulator UUID')
def prepare_xctestrun(data,root,request_path,response_path,commit):
 obj=plistlib.loads(data);require(type(obj) is dict and type(obj.get('TestConfigurations')) is list,'v2 xctestrun required')
 selected=[]
 for conf in obj['TestConfigurations']:
  for target in conf.get('TestTargets',[]):
   if target.get('BlueprintName')=='BlindAssistTests':selected.append((conf,target))
 require(len(selected)==1,'one exact hosted target required')
 conf,target=selected[0]
 target['OnlyTestIdentifiers']=['HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney']
 target['SkipTestIdentifiers']=[]
 env=target.setdefault('EnvironmentVariables',{})
 env.update(BLIND_J01_HOSTED='1',BLIND_J01_EPHEMERAL_SIMULATOR='1',BLIND_J01_REQUEST=str(request_path),BLIND_J01_RESPONSE=str(response_path),BLIND_J01_SOURCE_COMMIT=commit)
 conf['TestTargets']=[target];obj['TestConfigurations']=[conf]
 # Preserve the original build root when putting the run descriptor in scratch.
 def relocate(x):
  if isinstance(x,str):return x.replace('__TESTROOT__',str(root))
  if isinstance(x,list):return [relocate(v) for v in x]
  if isinstance(x,dict):return {k:relocate(v) for k,v in x.items()}
  return x
 return plistlib.dumps(relocate(obj))
def owned_parent_group():
 # Only the fixed same-job runner selects this mode. The wrapper is the leader
 # of its own new session/group; xcodebuild stays inside that owned group so the
 # parent can contain it even if this wrapper is killed before its finally.
 marker=os.environ.get('BLIND_J01_OWNED_PARENT_PID')
 if marker is None:return False
 require(re.fullmatch('[1-9][0-9]{0,19}',marker) is not None,'owned parent PID shape')
 require(int(marker)==os.getppid() and os.getpgrp()==os.getpid() and os.getsid(0)==os.getpid(),'exclusive parent-owned wrapper group required')
 return True

def main():
 deadline=time.monotonic()+55
 require(os.environ.get('BLIND_J01_EXECUTE_PREBUILT')=='1','explicit execution disabled')
 require(sys.platform=='darwin','Apple simulator host required')
 config=json.loads(read(os.environ['BLIND_J01_CONFIG'],65536));raw=sys.stdin.buffer.read(65537);require(len(raw)<=65536,'request budget')
 request=json.loads(raw);validate(request,config)
 path=pathlib.Path(config['xctestrun_path']).resolve();data=read(path,4*1024*1024)
 require(hashlib.sha256(data).hexdigest()==config['xctestrun_sha256'],'prebuilt descriptor pin mismatch')
 build_root=pathlib.Path(config['build_root']).absolute()
 require(path.is_relative_to(build_root),'descriptor outside attested build root')
 descriptor=str(path.relative_to(build_root))
 proof=attestation.verify(build_root,descriptor,config['build_receipt_path'],config['trusted_build_receipt_sha256'],config['source_commit'],max_seconds=min(20,deadline-time.monotonic()))
 tmp=pathlib.Path(config['attempt_dir']);require(not tmp.exists(),'fresh retained attempt directory required');tmp.mkdir(mode=0o700,parents=False)
 input=tmp/'request.json';output=tmp/'response.json';run=tmp/'run.xctestrun';log=tmp/'native.log'
 input.write_text(canonical(request));run.write_bytes(prepare_xctestrun(data,path.parent,input,output,config['source_commit']))
 cmd=['/usr/bin/xcodebuild','test-without-building','-xctestrun',str(run),'-destination','platform=iOS Simulator,id='+config['simulator_udid'],'-parallel-testing-enabled','NO','-maximum-concurrent-test-simulator-destinations','1','-only-testing:'+CASE]
 # Descriptor pin identifies a selected build, not independent binary/source
 # attestation. Caller must preserve its reviewed build receipt separately.
 with log.open('wb') as f:
  # Recheck immediately before launch; bytes can change after descriptor preparation.
  require(attestation.verify(build_root,descriptor,config['build_receipt_path'],config['trusted_build_receipt_sha256'],config['source_commit'],max_seconds=min(20,deadline-time.monotonic()))==proof,'prelaunch identity changed')
  owned=owned_parent_group()
  p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,start_new_session=not owned)
  try:
   while p.poll() is None:
    require(time.monotonic()<deadline,'host timeout; native drain unknown, no automatic retry')
    require(log.stat().st_size<=8*1024*1024,'host log budget')
    time.sleep(.05)
   require(p.returncode==0,'hosted XCTest failed; no success receipt')
  finally:
   if owned:
    # The parent owns the whole group; do not SIGKILL this wrapper before it
    # records bounded status. Parent always kills that group on every exit.
    if p.poll() is None:p.kill()
   else:
    try:os.killpg(p.pid,signal.SIGKILL)
    except ProcessLookupError:pass
   p.wait(timeout=3)
   (tmp/'PROCESS.json').write_text(canonical({'exit_code':p.returncode,'log_bytes':log.stat().st_size,'native_drain_acknowledged':False,'fullJourneyComplete':False}))
 response=json.loads(read(output,1024*1024))
 require(response.get('scenario_id')==request['scenario_id'] and response.get('source_commit')==request['source_commit'],'output identity')
 require(response.get('fullJourneyComplete') is False and response.get('physical_actions_applied') is False,'output authority')
 require(response.get('claimedSourceCommit')==config['source_commit'] and response.get('sourceAttestation',{}).get('verified') is False,'source claim must remain unattested')
 require(attestation.verify(build_root,descriptor,config['build_receipt_path'],config['trusted_build_receipt_sha256'],config['source_commit'],max_seconds=min(20,deadline-time.monotonic()))==proof,'artifact identity changed during run')
 response['nativeReportedSourceAttestation']=response['sourceAttestation']
 response['sourceAttestation']=proof
 print(canonical(response))
if __name__=='__main__':
 try:main()
 except Exception as e:
  print('J01 adapter unavailable: '+str(e)[:240],file=sys.stderr);raise SystemExit(2)
