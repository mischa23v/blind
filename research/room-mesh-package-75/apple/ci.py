#!/usr/bin/env python3
"""Isolated SwiftPM/public API proof. No app, signing, deployment or sensor input."""
import gzip,hashlib,json,os,platform,resource,signal,stat,subprocess,time
from pathlib import Path
H=Path(__file__).resolve().parent.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
# Controlled compatibility variant; not a pass of the default SwiftBuild backend.
BUILD_SYSTEM='native'
FILE_CAP=128<<20
SCRATCH_CAP=512<<20

def scratch_diagnostics(out):
 # Metadata only, no symlink traversal or file contents; bounded work and output.
 total=0;largest=[];seen=0;complete=True;pending=[out]
 while pending and complete:
  directory=pending.pop()
  try:
   with os.scandir(directory) as entries:
    for entry in entries:
     seen+=1
     if seen>20000:complete=False;break
     info=entry.stat(follow_symlinks=False)
     if stat.S_ISDIR(info.st_mode):pending.append(Path(entry.path))
     elif stat.S_ISREG(info.st_mode):
      total+=info.st_size
      largest.append((info.st_size,str(Path(entry.path).relative_to(out))[:256]))
      largest=sorted(largest,reverse=True)[:8]
  except OSError:complete=False
 return dict(scratchBytesAfterCommand=total,scratchCapExceeded=total>SCRATCH_CAP,
             scratchScanComplete=complete,scratchEntriesScanned=min(seen,20000),
             largestScratchFiles=[dict(path=name,bytes=size) for size,name in largest])

def log_tail(log):
 with log.open('rb') as f:
  f.seek(0,2);f.seek(max(0,f.tell()-8192))
  return '\n'.join(f.read(8192).decode('utf-8',errors='replace').splitlines()[-35:])

def build_cache_options(out,stem):
 return ['--cache-path',str(out/'swiftpm-cache'),'--manifest-cache','local',
         '-Xswiftc','-module-cache-path','-Xswiftc',str(out/(stem+'-module-cache')),
         '-Xcc','-fmodules-cache-path='+str(out/(stem+'-clang-cache'))]

def package_build_command(package,out,stem,triple,target_sdk):
 # SwiftPM/Package.swift execute on macOS even when products target iOS Simulator.
 return ['xcrun','--sdk','macosx','swift','build','--build-system',BUILD_SYSTEM,
         '--package-path',str(package),'--scratch-path',str(out/stem),
         '--configuration','release','--jobs','1','--triple',triple,'--sdk',target_sdk,
         '-Xswiftc','-enable-testing','-Xcc','-O1','-Xcxx','-O1']+build_cache_options(out,stem)

def package_environment(host_sdk,out):
 return dict(os.environ,SDKROOT=host_sdk,TMPDIR=str(out/'tmp')+'/')

def run(cmd,label,out,timeout=300,env=None):
 start=time.monotonic();log=out/(label+'.log');code=None;timed_out=False;exception_type=None
 # Keep subprocess temporaries inside the measured scratch tree.
 temporary=out/'tmp';temporary.mkdir(exist_ok=True)
 env=dict(os.environ if env is None else env);env['TMPDIR']=str(temporary)+'/'
 def limits():
  os.setsid();resource.setrlimit(resource.RLIMIT_CPU,(300,300));resource.setrlimit(resource.RLIMIT_FSIZE,(FILE_CAP,FILE_CAP))
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
 receipt.update(scratch_diagnostics(out))
 receipt.update(fileCapBytes=FILE_CAP,scratchCapBytes=SCRATCH_CAP,cpuCapSeconds=300,wallTimeoutSeconds=timeout,
                scratchAccounting='stage-end only; scoped tree; not a live disk quota',
                terminationSignal=signal.Signals(-code).name if code is not None and code<0 else None,
                fileSizeLimitSignal=code==-signal.SIGXFSZ)
 if log.exists():receipt['logTail']=log_tail(log)
 (out/(label+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n')
 if code!=0 or timed_out or exception_type or receipt['scratchCapExceeded'] or not receipt['scratchScanComplete']:
  # Public source-only compiler diagnostics, bounded; never environment dump.
  print(json.dumps({k:receipt[k] for k in ['terminationSignal','fileSizeLimitSignal','largestScratchFiles','scratchScanComplete']}))
  if log.exists():print(receipt['logTail'])
  raise RuntimeError(label+' failed; inspect bounded receipt')
 return receipt


def output(cmd,env=None):return subprocess.check_output(cmd,text=True,timeout=30,env=env).strip()
def main():
 root=Path(os.environ['GITHUB_WORKSPACE']);package=H/'BlindRoomMesh'
 assert platform.system()=='Darwin' and os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind'
 assert output(['xcodebuild','-version']).splitlines()[0]=='Xcode 27.0'
 assert output(['xcrun','--sdk','iphonesimulator','--show-sdk-version'])=='27.0'
 current=json.loads((H/'APPLE_CURRENT_SOURCE_PINS.json').read_text())
 assert current['schema']==1 and sha(H/'APPLE_SOURCE_PINS.json')==current['historical_manifest_sha256'], 'historical stage75 pin manifest changed'
 for name,digest in current['files'].items():assert sha(H/name)==digest,name
 assert sha(root/'.github/workflows/native-room-mesh-package.yml')==sha(H/'apple/native-room-mesh-package.yml')
 fixture=root/'research/apple-candidate-ci-71/fixture/room.json.gz'
 assert sha(fixture)=='6ae71b8660d7ae617eee274d0bae07eccb2fa983b382dd741f18596cbe596bc1'
 with gzip.open(fixture,'rb')as f:data=f.read((8<<20)+1)
 assert len(data)<=8<<20 and hashlib.sha256(data).hexdigest()=='6cd1b3317d13c98551335b12f24ca6899553dd8bfb291f62b0d2187aa364bfdb'
 out=Path(os.environ['RUNNER_TEMP'])/'blind-room-mesh-75';out.mkdir(exist_ok=False);(out/'INPUT.json').write_bytes(data)
 receipts=[];toolchain=output(['xcrun','swiftc','--version'])
 # Verify advertised SwiftPM options on the pinned Apple toolchain before use.
 host_sdk=output(['xcrun','--sdk','macosx','--show-sdk-path'])
 (out/'tmp').mkdir(exist_ok=True)
 package_env=package_environment(host_sdk,out)
 help_text=output(['xcrun','--sdk','macosx','swift','build','--build-system',BUILD_SYSTEM,'--help'],env=package_env)
 assert all(flag in help_text for flag in ['--cache-path','--manifest-cache','--scratch-path','--build-system']), 'required SwiftPM cache options unavailable'
 for sdk,triple,stem in [('macosx','arm64-apple-macosx14.0','host'),('iphonesimulator','arm64-apple-ios17.0-simulator','simulator')]:
  sdkpath=output(['xcrun','--sdk',sdk,'--show-sdk-path'])
  build=package_build_command(package,out,stem,triple,sdkpath)
  receipts.append(run(build,stem+'-package',out,300,env=package_env))
  # Bin-path lookup must use the identical host environment and target options.
  bindir=Path(output(build+['--show-bin-path'],env=package_env))
  earcut_objects=sorted((bindir/'CEarcut.build').rglob('*.o'))
  assert earcut_objects, 'missing reviewed CEarcut objects'
  earcut_modulemap=bindir/'CEarcut.build/module.modulemap'
  assert earcut_modulemap.is_file(), 'missing SwiftPM CEarcut module map'
  objects=sorted((bindir/'CDetour.build').rglob('*.o'))+earcut_objects+sorted((bindir/'BlindRoomMesh.build').glob('*.o'))
  assert len(objects)>=25 and len(objects)<=64,'unexpected package object set'
  common=['xcrun','--sdk',sdk,'swiftc','-target',triple,'-sdk',sdkpath,'-module-cache-path',str(out/(stem+'-client-cache')),'-I',str(bindir/'Modules'),'-I',str(package/'Sources/CDetour/include'),'-I',str(package/'Sources/CEarcut/include'),'-Xcc','-fmodule-map-file='+str(earcut_modulemap),*map(str,objects),'-lc++']
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
   assert len(b['failureCommitChecks'])==5 and all(b['failureCommitChecks'].values())
   assert len(b['discardChecks'])==19 and all(b['discardChecks'].values())
  # Simulator client is compile/link only, never launched or installed.
 summary=dict(sourceCommit=os.environ.get('GITHUB_SHA'),toolchain=toolchain,swiftPMBuildSystem=BUILD_SYSTEM,defaultSwiftBuildBackendPassed=False,macOSSwiftPMPackageBuilt=True,publicImportedClientExecuted=True,legacyChecks=55,runtimeChecks=32,failureCommitChecks=5,discardChecks=19,iOSSimulatorPackageAndClientLinked=True,iOSSimulatorExecuted=False,appProjectBuilt=False,ARKitExecuted=False,physicalAuthority=False,publicExclusionUpdatesImplemented=False,receipts=receipts)
 (out/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items()if k!='receipts'}))
if __name__=='__main__':main()
