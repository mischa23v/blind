#!/usr/bin/env python3
"""No downloads or installs. Focused portable source build, not SwiftPM/iOS build."""
import argparse,hashlib,json,os,resource,subprocess,time
from pathlib import Path
H=Path(__file__).resolve().parent
ap=argparse.ArgumentParser();ap.add_argument('--swiftc',type=Path,required=True);ap.add_argument('--module-cache',type=Path,required=True);ap.add_argument('--native-library',type=Path,required=True);ap.add_argument('--fixture',type=Path,required=True);a=ap.parse_args()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
f=json.loads((H/'FROZEN.json').read_text())
for n,d in f['files'].items():assert sha(H/n)==d,n
assert sha(a.native_library)==f['nativeLibrarySHA256'];assert sha(a.fixture)==f['fixtureSHA256']
out=H/'build';out.mkdir(exist_ok=True)
cmd=[str(a.swiftc.absolute()),'-j','1','-module-cache-path',str(a.module_cache.resolve()),'-I',str(H/'BlindRoomMesh/Sources/CDetour/include'),'-L',str(a.native_library.resolve().parent),'-lblind_detour','-Xlinker','-rpath','-Xlinker',str(a.native_library.resolve().parent),*map(str,sorted((H/'BlindRoomMesh/Sources/BlindRoomMesh').glob('*.swift'))),str(H/'tests/main.swift'),'-o',str(out/'test')]
def limits():resource.setrlimit(resource.RLIMIT_CPU,(120,120));resource.setrlimit(resource.RLIMIT_FSIZE,(8<<20,8<<20))
start=time.monotonic()
with(out/'compile.log').open('w')as log:r=subprocess.run(cmd,stdout=log,stderr=log,timeout=180,preexec_fn=limits)
assert r.returncode==0,(out/'compile.log').read_text()
compileWall=time.monotonic()-start;start=time.monotonic()
env=dict(os.environ,LD_LIBRARY_PATH=str(a.native_library.resolve().parent))
with(out/'test.log').open('w')as log:r=subprocess.run([str(out/'test'),str(a.fixture.resolve()),str(H/'RESULT.json')],env=env,stdout=log,stderr=log,timeout=60,preexec_fn=limits)
assert r.returncode==0,(out/'test.log').read_text()
legacy=json.loads((H/'RESULT.json').read_text());runtime=json.loads((H/'RUNTIME_RESULT.json').read_text());assert legacy['passed'] and runtime['passed'];assert len(legacy['checks'])==55 and len(runtime['checks'])==32
receipt=dict(passed=True,compileCommand=cmd,compileWallSeconds=compileWall,replayWallSeconds=time.monotonic()-start,maximumChildRSSKiB=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,legacyChecks=55,runtimeChecks=32,nativeLibrarySHA256=sha(a.native_library),fixtureSHA256=sha(a.fixture),packageSwiftPMBuilt=False,iOSBuilt=False,ARKitExecuted=False,physicalAuthority=False)
(H/'PORTABLE_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
assert sum(p.stat().st_size for p in H.rglob('*')if p.is_file())<=8<<20
