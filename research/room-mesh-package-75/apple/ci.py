#!/usr/bin/env python3
"""Isolated SwiftPM/public API proof. No app, signing, deployment or sensor input."""
import gzip,hashlib,json,os,platform,resource,signal,subprocess,time
from pathlib import Path
H=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
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
 root=Path(os.environ['GITHUB_WORKSPACE']);package=H/'BlindRoomMesh'
 assert platform.system()=='Darwin' and os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind'
 assert output(['xcodebuild','-version']).splitlines()[0]=='Xcode 27.0'
 assert output(['xcrun','--sdk','iphonesimulator','--show-sdk-version'])=='27.0'
 pins=json.loads((H/'APPLE_SOURCE_PINS.json').read_text())
 for name,digest in pins.items():assert sha(H/name)==digest,name
 assert sha(root/'.github/workflows/native-room-mesh-package.yml')==sha(H/'apple/native-room-mesh-package.yml')
 fixture=root/'research/apple-candidate-ci-71/fixture/room.json.gz'
 assert sha(fixture)=='6ae71b8660d7ae617eee274d0bae07eccb2fa983b382dd741f18596cbe596bc1'
 with gzip.open(fixture,'rb')as f:data=f.read((8<<20)+1)
 assert len(data)<=8<<20 and hashlib.sha256(data).hexdigest()=='6cd1b3317d13c98551335b12f24ca6899553dd8bfb291f62b0d2187aa364bfdb'
 out=Path(os.environ['RUNNER_TEMP'])/'blind-room-mesh-75';out.mkdir(exist_ok=False);(out/'INPUT.json').write_bytes(data)
 receipts=[];toolchain=output(['xcrun','swiftc','--version'])
 for sdk,triple,stem in [('macosx','arm64-apple-macosx14.0','host'),('iphonesimulator','arm64-apple-ios17.0-simulator','simulator')]:
  sdkpath=output(['xcrun','--sdk',sdk,'--show-sdk-path'])
  build=['xcrun','--sdk',sdk,'swift','build','--package-path',str(package),'--scratch-path',str(out/stem),'--configuration','release','--jobs','1','--triple',triple,'--sdk',sdkpath,'-Xswiftc','-enable-testing','-Xcc','-O1','-Xcxx','-O1']
  receipts.append(run(build,stem+'-package',out,300))
  bindir=Path(output(build+['--show-bin-path']))
  objects=sorted((bindir/'CDetour.build').rglob('*.o'))+sorted((bindir/'BlindRoomMesh.build').glob('*.o'))
  assert len(objects)>=25 and len(objects)<=64,'unexpected package object set'
  common=['xcrun','--sdk',sdk,'swiftc','-target',triple,'-sdk',sdkpath,'-module-cache-path',str(out/(stem+'-client-cache')),'-I',str(bindir/'Modules'),'-I',str(package/'Sources/CDetour/include'),*map(str,objects),'-lc++']
  executable=out/(stem+'-public-client')
  receipts.append(run(common+[str(H/'apple/public-client.swift'),'-o',str(executable)],stem+'-public-client-link',out))
  if stem=='host':
   receipts.append(run([str(executable)],'host-public-client-run',out,60))
   # @testable internal assertions are separate from the ordinary imported client.
   tests=out/'main.swift';tests.write_text('@testable import BlindRoomMesh\n'+(H/'tests/main.swift').read_text())
   replay=out/'host-fixtures'
   receipts.append(run(common+[str(tests),'-o',str(replay)],'host-fixtures-link',out))
   receipts.append(run([str(replay),str(out/'INPUT.json'),str(out/'RESULT.json')],'host-fixtures-run',out,120))
   a=json.loads((out/'RESULT.json').read_text());b=json.loads((out/'RUNTIME_RESULT.json').read_text())
   assert a['passed'] and len(a['checks'])==55 and a['markedSpans']==636
   assert b['passed'] and len(b['checks'])==32
  # Simulator client is compile/link only, never launched or installed.
 summary=dict(sourceCommit=os.environ.get('GITHUB_SHA'),toolchain=toolchain,macOSSwiftPMPackageBuilt=True,publicImportedClientExecuted=True,legacyChecks=55,runtimeChecks=32,iOSSimulatorPackageAndClientLinked=True,iOSSimulatorExecuted=False,appProjectBuilt=False,ARKitExecuted=False,physicalAuthority=False,publicExclusionUpdatesImplemented=False,receipts=receipts)
 (out/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items()if k!='receipts'}))
if __name__=='__main__':main()
