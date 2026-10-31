from pathlib import Path
import os,json,hashlib,subprocess,sys,time
H=Path(__file__).resolve().parent;W=Path('<WORKSPACE_ROOT>');F=H.parent;R=H/'run';R.mkdir(exist_ok=False);B=R/'build';S=W/'coordination/remaining-mapping-baselines';D=S/'stage-b/prefix';E=W/'research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix';O=F/'build-gate/run/build'
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});env=os.environ.copy();env['LD_LIBRARY_PATH']=str(D/'usr/lib/x86_64-linux-gnu')+':'+str(E/'usr/lib/x86_64-linux-gnu')
f=json.loads((H/'EXECUTION_FREEZE.json').read_text());assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==s for p,s in f['files'].items())
def run(label,args):
 t=time.monotonic()
 with (R/(label+'.log')).open('x')as out:c=subprocess.run(args,env=env,stdout=out,stderr=subprocess.STDOUT)
 (R/(label+'.json')).write_text(json.dumps({'argv':args,'exitCode':c.returncode,'wallSeconds':time.monotonic()-t},indent=2)+'\n')
 if c.returncode:sys.exit(c.returncode)
cm=str(E/'usr/bin/cmake')
args=[cm,'-S',str(H),'-B',str(B),'-DCMAKE_BUILD_TYPE=Release','-DVOXBLOX_ROOT='+str(H/'source'),'-DORIGINAL_ROOT='+str(F/'voxfield-78ee6403720e0aed87f4720c04c813bb38a3b260'),'-DORIGINAL_BUILD='+str(O),'-DMINKINDR_ROOT='+str(S/'stage-a/minkindr-564f12639a8447d4d3e5e7707851424302941056'),'-DEIGENCHECKS_ROOT='+str(S/'stage-a/eigen_checks-22a6247a3df11bc285d43d1a030f4e874a413997'),'-DREUSE_PREFIX='+str(E),'-DDEPS_PREFIX='+str(D)]
run('configure',args);run('build',[cm,'--build',str(B),'--parallel','1','--target','candidate_client','original_client'])
elf={}
for name,own,forbidden in [('original_client',str(O/'libvoxfield_native.so'),'libvoxfield_rayguard'),('candidate_client',str(B/'libvoxfield_rayguard.so'),'libvoxfield_native')]:
 p=B/name;ld=subprocess.check_output(['ldd',str(p)],env=env,text=True);rd=subprocess.check_output(['readelf','-d',str(p)],env=env,text=True)
 assert own in ld and forbidden not in ld and 'not found' not in ld,(name,ld)
 elf[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'ldd':ld,'dynamic':rd,'coreSHA256':hashlib.sha256(Path(own).read_bytes()).hexdigest()}
(R/'ELF.json').write_text(json.dumps(elf,indent=2)+'\n')
run('original',[str(B/'original_client'),'original']);run('candidate',[str(B/'candidate_client'),'candidate'])
