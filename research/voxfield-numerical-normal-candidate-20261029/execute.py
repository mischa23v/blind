# SOURCE PREPARATION: requires separately reviewed final freeze and root admission.
from pathlib import Path
import os,json,hashlib,subprocess,sys,time
H=Path(__file__).resolve().parent;W=Path('<WORKSPACE_ROOT>');F=H.parent;R=H/'run';R.mkdir(exist_ok=False);P=F/'zero-direction-candidate';B=P/'run/build';S=W/'coordination/remaining-mapping-baselines';D=S/'stage-b/prefix';E=W/'research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix'
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});env=os.environ.copy();env['LD_LIBRARY_PATH']=str(B)+':'+str(D/'usr/lib/x86_64-linux-gnu')+':'+str(E/'usr/lib/x86_64-linux-gnu');env['ASAN_OPTIONS']='detect_leaks=0:halt_on_error=1';env['UBSAN_OPTIONS']='halt_on_error=1:print_stacktrace=1'
f=json.loads((H/'EXECUTION_FREEZE.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==s for p,s in f['files'].items())
def run(label,args):
 t=time.monotonic()
 with (R/(label+'.log')).open('x')as out:c=subprocess.run(args,env=env,cwd=R,stdout=out,stderr=subprocess.STDOUT)
 (R/(label+'.json')).write_text(json.dumps({'argv':args,'cwd':str(R),'exitCode':c.returncode,'wallSeconds':time.monotonic()-t},indent=2)+'\n')
 if c.returncode:sys.exit(c.returncode)
inc=['-I'+str(p) for p in [H,F/'build-gate',P/'source/voxblox/include',S/'stage-a/minkindr-564f12639a8447d4d3e5e7707851424302941056/minkindr/include',E/'usr/include/eigen3',D/'usr/include',B/'generated']]
run('compile_provider',['/usr/bin/c++','-std=c++14','-O0','-g','-fsanitize=address,undefined','-fno-omit-frame-pointer',str(H/'n2_provider_fixtures.cpp'),'-o',str(R/'provider')]+inc)
pld=subprocess.check_output(['ldd',str(R/'provider')],env=env,text=True)
assert 'libasan' in pld and 'libubsan' in pld and 'not found' not in pld and 'libvoxfield_' not in pld
(R/'PROVIDER_ELF.json').write_text(json.dumps({'ldd':pld,'sha256':hashlib.sha256((R/'provider').read_bytes()).hexdigest(),'ASAN_OPTIONS':env['ASAN_OPTIONS'],'UBSAN_OPTIONS':env['UBSAN_OPTIONS'],'leakChecking':'UNAVAILABLE_previous_ptrace_environment_fatal'},indent=2)+'\n')
run('provider',[str(R/'provider')])
run('compile_native',['/usr/bin/c++','-std=c++14','-O0',str(H/'n2_native_fixtures.cpp'),'-o',str(R/'native')]+inc+[str(B/'libvoxfield_rayguard.so'),str(D/'usr/lib/x86_64-linux-gnu/libglog.so'),str(D/'usr/lib/x86_64-linux-gnu/libprotobuf.so'),'-pthread'])
ld=subprocess.check_output(['ldd',str(R/'native')],env=env,text=True);rd=subprocess.check_output(['readelf','-d',str(R/'native')],env=env,text=True)
assert str(B/'libvoxfield_rayguard.so') in ld and 'libvoxfield_native' not in ld and 'not found' not in ld
(R/'ELF.json').write_text(json.dumps({'ldd':ld,'dynamic':rd,'clientSHA256':hashlib.sha256((R/'native').read_bytes()).hexdigest(),'coreSHA256':hashlib.sha256((B/'libvoxfield_rayguard.so').read_bytes()).hexdigest()},indent=2)+'\n')
run('native',[str(R/'native')])
