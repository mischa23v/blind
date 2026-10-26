#!/usr/bin/env python3
"""Test-only Apple SDK build; no app project, signing, deployment or sensors."""
from pathlib import Path
import argparse,gzip,hashlib,json,os,platform,resource,signal,subprocess,tempfile,time
H=Path(__file__).resolve().parent

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def fixture_bytes():
 m=json.loads((H/'fixture/METADATA.json').read_text());p=H/'fixture/room.json.gz'
 assert p.stat().st_size==m['compressedBytes'] and sha(p)==m['compressedSHA256']
 with gzip.open(p,'rb')as f:data=f.read((8<<20)+1)
 assert len(data)<=8<<20 and len(data)==m['decodedBytes'] and hashlib.sha256(data).hexdigest()==m['decodedSHA256']
 return data

def validate(root,upstream=None):
 pins=json.loads((H/'SOURCE_PINS.json').read_text())
 for name,digest in pins['packageFiles'].items():assert sha(H/name)==digest,name
 U=upstream or root/'tools/navigation-recast/upstream'
 for name,digest in pins['upstreamFiles'].items():assert sha(U/name)==digest,name
 fixture=fixture_bytes();r=json.loads(fixture)
 assert len(r['vertices'])//3==18398 and len(r['triangles'])//3==29366 and len(r['packets'])==32
 assert r['expectedMarkedSpans']==636 and r['exclusion']['unknown'] and not r['exclusion']['authority']
 return U,fixture

def run(cmd,label,out,timeout=300,env=None):
 start=time.monotonic();log=out/(label+'.log');code=None;timed_out=False;exception_type=None
 def limits():
  os.setsid();resource.setrlimit(resource.RLIMIT_CPU,(300,300));resource.setrlimit(resource.RLIMIT_FSIZE,(128<<20,128<<20))
 try:
  with log.open('w')as f:
   p=subprocess.Popen(cmd,stdout=f,stderr=subprocess.STDOUT,env=env,preexec_fn=limits)
   try:code=p.wait(timeout=timeout)
   except subprocess.TimeoutExpired:
    timed_out=True
    try:os.killpg(p.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    code=p.wait()
 except Exception as exc:exception_type=type(exc).__name__
 receipt=dict(label=label,command=cmd,exitCode=code,timedOut=timed_out,exceptionType=exception_type,wallSeconds=time.monotonic()-start)
 scratch=sum(p.stat().st_size for p in out.rglob('*')if p.is_file());receipt['scratchBytesAfterCommand']=scratch
 receipt['scratchCapExceeded']=scratch>512<<20
 (out/(label+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n')
 if code!=0 or timed_out or exception_type or receipt['scratchCapExceeded']:
  # Public source-only compiler diagnostics, bounded; never environment dump.
  if log.exists():print('\n'.join(log.read_text(errors='replace').splitlines()[-35:]))
  raise RuntimeError(label+' failed; inspect bounded receipt')
 return receipt

def output(cmd):return subprocess.check_output(cmd,text=True,timeout=30).strip()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--validate-only',action='store_true');ap.add_argument('--repo-root',type=Path,default=Path(os.environ.get('GITHUB_WORKSPACE','.')).resolve());ap.add_argument('--upstream',type=Path);a=ap.parse_args()
 U,data=validate(a.repo_root,a.upstream)
 if a.validate_only:print('Pinned source and geometry fixture valid; no Apple build performed');return
 assert sha(a.repo_root/'.github/workflows/native-candidate-bridge.yml')==sha(H/'native-candidate-bridge.yml'),'workflow copy mismatch'
 assert platform.system()=='Darwin','Apple runner required'
 assert os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind'
 assert output(['xcodebuild','-version']).splitlines()[0]=='Xcode 27.0'
 assert output(['xcrun','--sdk','iphonesimulator','--show-sdk-version'])=='27.0'
 out=Path(os.environ['RUNNER_TEMP'])/'blind-candidate-bridge-71';out.mkdir(exist_ok=False)
 (out/'INPUT.json').write_bytes(data)
 sources=[]
 for family in ['Recast','Detour','DetourCrowd']:sources+=sorted((U/family/'Source').glob('*.cpp'))
 assert len(sources)==24,'unexpected native translation-unit set'
 includes=[f'-I{U/family}/Include'for family in ['Recast','Detour','DetourCrowd']]
 swift=[str(H/'source'/name)for name in ['Bridge.swift','Exclusion.swift','main.swift']]
 receipts=[];compiler=output(['xcrun','swiftc','--version'])
 for sdk,target,stem in [('macosx','arm64-apple-macosx14.0','macos'),('iphonesimulator','arm64-apple-ios17.0-simulator','simulator')]:
  sdkpath=output(['xcrun','--sdk',sdk,'--show-sdk-path']);dest=out/stem;dest.mkdir()
  lib=dest/'libblind_detour.dylib'
  native=['xcrun','--sdk',sdk,'clang++','-target',target,'-isysroot',sdkpath,'-std=c++11','-O1','-ffp-contract=off','-dynamiclib','-fPIC','-fno-rtti','-fno-exceptions',*includes,*map(str,sources),str(H/'native/clearance_adapter.cpp'),'-Wl,-install_name,@rpath/libblind_detour.dylib','-o',str(lib)]
  receipts.append(run(native,stem+'-native',out))
  cmd=['xcrun','--sdk',sdk,'swiftc','-target',target,'-sdk',sdkpath,'-j','1','-module-cache-path',str(dest/'cache'),'-I',str(H/'cmodule'),'-L',str(dest),'-lblind_detour','-Xlinker','-rpath','-Xlinker','@executable_path',*swift,'-o',str(dest/'replay')]
  receipts.append(run(cmd,stem+'-swift',out))
  if stem=='macos':
   receipts.append(run([str(dest/'replay'),str(out/'INPUT.json'),str(out/'RESULT.json')],'macos-replay',out,120))
   result=json.loads((out/'RESULT.json').read_text());assert result['passed'] and len(result['checks'])==55 and result['markedSpans']==636 and result['authorizesPhysicalGuidance'] is False
  # Simulator executable is compile/link only. Never boot/install/launch it.
 summary=dict(sourceCommit=os.environ.get('GITHUB_SHA'),toolchain=compiler,macOSReplayPassed=True,iOSSimulatorCompileLinkPassed=True,iOSSimulatorExecuted=False,appProjectBuilt=False,ARKitSensorTest=False,physicalAuthority=False,nativeDylibHashes={stem:sha(out/stem/'libblind_detour.dylib')for stem in ['macos','simulator']},executableHashes={stem:sha(out/stem/'replay')for stem in ['macos','simulator']},fixtureSHA256=hashlib.sha256(data).hexdigest(),receipts=receipts)
 (out/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items()if k not in ['receipts','toolchain']}))
if __name__=='__main__':main()
