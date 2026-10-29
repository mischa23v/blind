#!/usr/bin/env python3
"""Tiny serial already-vendored C++ check. No installs, Swift or Apple claims."""
import hashlib,json,pathlib,resource,shutil,subprocess,tempfile,time
resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
resource.setrlimit(resource.RLIMIT_CPU,(120,120))
HERE=pathlib.Path(__file__).resolve().parent;ROOT=HERE.parents[2]
C=ROOT/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour'
START=time.monotonic();WORK=pathlib.Path(tempfile.mkdtemp(prefix='blind-strict-cabi-'))
ROWS=[];RECEIPT={'schema':1,'scope':'Linux C++ ABI only; not Swift, Apple physics, iOS or physical clearance',
                'physicalAuthority':False,'commands':ROWS,'status':'started'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args):
    before=time.monotonic()
    p=subprocess.run([str(v) for v in args],capture_output=True,text=True,timeout=max(1,180-(time.monotonic()-START)))
    row={'command':[str(v) for v in args],'exitCode':p.returncode,'wallSeconds':time.monotonic()-before,
         'stdout':p.stdout,'stderr':p.stderr};ROWS.append(row)
    if p.returncode:raise RuntimeError(row)
    return p.stdout
try:
    common=['c++','-std=c++14','-O1','-ffp-contract=off','-fno-rtti','-fno-exceptions','-I'+str(C),'-I'+str(C/'include')]
    common+=['-I'+str(C/'upstream'/name/'Include') for name in ['Recast','Detour','DetourCrowd']]
    objects=[]
    for name in ['Recast','Detour','DetourCrowd']:
        for source in sorted((C/'upstream'/name/'Source').glob('*.cpp')):
            obj=WORK/(name+'-'+source.stem+'.o');run(common+['-c',source,'-o',obj]);objects.append(obj)
    source=WORK/'adapter.cpp';source.write_text((C/'blind_detour_exclusion.cpp').read_text()+'\n'+(HERE/'association_appendix.cpp').read_text())
    obj=WORK/'adapter.o';run(common+['-c',source,'-o',obj]);objects.append(obj)
    binary=WORK/'strict-cabi';run(common+[HERE/'cabi_tests.cpp',*objects,'-o',binary])
    RECEIPT['cabiResult']=json.loads(run([binary]));RECEIPT['status']='passed';RECEIPT['generatedAdapterSHA256']=sha(source)
except Exception as error:
    RECEIPT['status']='failed';RECEIPT['error']=str(error)[:2000]
finally:
    RECEIPT.update(wallSeconds=time.monotonic()-START,maxChildRSSKiB=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                   cabiTestSHA256=sha(HERE/'cabi_tests.cpp'),wrapperSHA256=sha(C/'blind_detour_exclusion.cpp'))
    (HERE/'LINUX_CABI_RESULT.json').write_text(json.dumps(RECEIPT,indent=2)+'\n');shutil.rmtree(WORK)
print(json.dumps({k:v for k,v in RECEIPT.items() if k!='commands'},indent=2))
if RECEIPT['status']!='passed':raise SystemExit(1)
