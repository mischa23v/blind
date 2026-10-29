from pathlib import Path
import os,json,hashlib,subprocess,sys,time
H=Path(__file__).resolve().parent;W=Path('<WORKSPACE_ROOT>');P=H.parent;F=P.parent;R=H/'run';R.mkdir(exist_ok=False);B=P/'run/build';S=W/'coordination/remaining-mapping-baselines';D=S/'stage-b/prefix';E=W/'research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix'
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});env=os.environ.copy();env['LD_LIBRARY_PATH']=str(B)+':'+str(D/'usr/lib/x86_64-linux-gnu')+':'+str(E/'usr/lib/x86_64-linux-gnu')
f=json.loads((H/'EXECUTION_FREEZE.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==s for p,s in f['files'].items())
def run(label,args):
 t=time.monotonic()
 with (R/(label+'.log')).open('x')as out:c=subprocess.run(args,env=env,stdout=out,stderr=subprocess.STDOUT)
 (R/(label+'.json')).write_text(json.dumps({'argv':args,'exitCode':c.returncode,'wallSeconds':time.monotonic()-t},indent=2)+'\n')
 if c.returncode:sys.exit(c.returncode)
args=['/usr/bin/c++','-std=c++14','-O0',str(F/'build-gate/np_fixtures.cpp'),'-o',str(R/'np_fixtures')]+['-I'+str(p) for p in [P/'source/voxblox/include',S/'stage-a/minkindr-564f12639a8447d4d3e5e7707851424302941056/minkindr/include',E/'usr/include/eigen3',D/'usr/include',B/'generated']]+[str(B/'libvoxfield_rayguard.so'),str(D/'usr/lib/x86_64-linux-gnu/libglog.so'),str(D/'usr/lib/x86_64-linux-gnu/libprotobuf.so'),'-pthread']
run('compile',args)
ld=subprocess.check_output(['ldd',str(R/'np_fixtures')],env=env,text=True);rd=subprocess.check_output(['readelf','-d',str(R/'np_fixtures')],env=env,text=True)
assert str(B/'libvoxfield_rayguard.so') in ld and 'libvoxfield_native' not in ld and 'not found' not in ld
(R/'ELF.json').write_text(json.dumps({'ldd':ld,'dynamic':rd,'clientSHA256':hashlib.sha256((R/'np_fixtures').read_bytes()).hexdigest(),'coreSHA256':hashlib.sha256((B/'libvoxfield_rayguard.so').read_bytes()).hexdigest()},indent=2)+'\n')
run('fixtures',[str(R/'np_fixtures')])
