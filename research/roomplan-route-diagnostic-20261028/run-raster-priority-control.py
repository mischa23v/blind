#!/usr/bin/env python3
"""Authorized bounded serial upstream-raster micro-control, not Apple/nav proof."""
import hashlib,json,os,resource,signal,subprocess,tempfile,time
from pathlib import Path

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent
RECAST=ROOT/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/upstream/Recast'
SOURCE=HERE/'raster-priority-control.cpp'
ADAPTER=ROOT/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/blind_detour_exclusion.cpp'
FILES=[SOURCE]+[RECAST/'Source'/name for name in ['Recast.cpp','RecastRasterization.cpp','RecastAlloc.cpp','RecastAssert.cpp']]
HEADERS=sorted((RECAST/'Include').glob('*.h'))
UPSTREAM_MANIFEST=ROOT/'tools/navigation-recast/UPSTREAM_MANIFEST.json'
LIMITS=dict(addressSpaceBytes=256<<20,cpuSeconds=20,wallSeconds=30,fileBytes=8<<20)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def limits():
    resource.setrlimit(resource.RLIMIT_AS,(LIMITS['addressSpaceBytes'],)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(LIMITS['cpuSeconds'],)*2)
    resource.setrlimit(resource.RLIMIT_FSIZE,(LIMITS['fileBytes'],)*2)

def run(command,label):
    start=time.monotonic()
    log=HERE/(label+'.log')
    receipt=dict(command=list(map(str,command)),log=log.name)
    try:
        with log.open('w') as f:
            process=subprocess.Popen(command,stdout=f,stderr=subprocess.STDOUT,preexec_fn=limits,start_new_session=True)
            try:receipt['exitCode']=process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid,signal.SIGKILL)
                receipt['exitCode']=process.wait();receipt['timedOut']=True
    except OSError as exc:
        receipt['exitCode']=None;receipt['processError']=str(exc)
    receipt['wallSeconds']=time.monotonic()-start
    receipt['logSHA256']=sha(log)
    return receipt

def main():
    upstream=json.loads(UPSTREAM_MANIFEST.read_text())
    assert upstream['revision']=='9f4ce64458dfae86e1239c525ddc219c4e9e06f1'
    pinned={f['path']:f['sha256'] for f in upstream['files']}
    for path in FILES[1:]+HEADERS:
        assert sha(path)==pinned['Recast/'+str(path.relative_to(RECAST))],str(path)
    receipt=dict(scope='Actual pinned upstream raster only; authored synthetic controls',upstreamRevision='9f4ce64458dfae86e1239c525ddc219c4e9e06f1',limits=LIMITS,
        upstreamAcquisitionPinsVerified=True,
        sourceSHA256={str(p.relative_to(ROOT)):sha(p) for p in FILES+HEADERS+[ADAPTER,Path(__file__),UPSTREAM_MANIFEST]},
        appleExecuted=False,fullPathExecuted=False,realRoomExecuted=False,physicalAuthority=False)
    before=resource.getrusage(resource.RUSAGE_CHILDREN)
    with tempfile.TemporaryDirectory(prefix='blind-raster-priority-') as scratch:
        binary=Path(scratch)/'control'
        command=['g++','-std=c++11','-O0','-ffp-contract=off','-fno-rtti','-fno-exceptions','-I',str(RECAST/'Include'),*map(str,FILES),'-o',str(binary)]
        receipt['compile']=run(command,'raster-priority-compile')
        if receipt['compile'].get('exitCode')==0:
            receipt['run']=run([str(binary)],'raster-priority-run')
            lines=(HERE/'raster-priority-run.log').read_text().splitlines()
            try:
                observations=[json.loads(line) for line in lines]
                receipt['observations']=observations
                receipt['summary']=observations[-1] if observations else None
            except json.JSONDecodeError as exc:
                receipt['parseError']=str(exc)
    after=resource.getrusage(resource.RUSAGE_CHILDREN)
    receipt['childCPUSeconds']=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime
    receipt['maximumChildRSSKiB']=after.ru_maxrss
    receipt['passed']=receipt['compile'].get('exitCode')==0 and receipt.get('run',{}).get('exitCode')==0 and receipt.get('summary',{}).get('passed') is True
    (HERE/'RASTER_PRIORITY_RESULT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:receipt[k] for k in ['passed','childCPUSeconds','maximumChildRSSKiB','appleExecuted','fullPathExecuted','realRoomExecuted','physicalAuthority']}))
    if not receipt['passed']:
        for label in ['raster-priority-compile','raster-priority-run']:
            log=HERE/(label+'.log')
            if log.exists():print(log.read_text()[-4000:])
        raise SystemExit(1)

if __name__=='__main__':main()
