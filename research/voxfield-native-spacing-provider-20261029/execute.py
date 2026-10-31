from pathlib import Path
import subprocess,os,json,hashlib,struct
H=Path(__file__).resolve().parent
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
os.environ.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1')
frozen=json.loads((H/'EXECUTION_FREEZE.json').read_text())['files']
for p,s in frozen.items():
 assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==s,p
R=H/'run';R.mkdir(exist_ok=False)
os.chdir(R)
for name in ['fixtures','recorded_distribution']:
 with (R/(name+'_compile.log')).open('w') as log:
  subprocess.run(['/usr/bin/g++','-O1','-std=c++14','-I','<WORKSPACE_ROOT>/research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix/usr/include/eigen3','-I',str(H),'-I',str(H.parent/'n2-normal-candidate'),str(H/(name+'.cpp')),'-o',str(R/name)],stdout=log,stderr=subprocess.STDOUT,check=True)
# No recorded normal computation until synthetic contracts pass; raw SHA verification precedes compile.
with (R/'fixtures.jsonl').open('w') as log:
 subprocess.run([str(R/'fixtures')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (R/'recorded_distribution.txt').open('w') as log:
 subprocess.run([str(R/'recorded_distribution'),str(H.parent/'prefix3-d1-n2/frames3.txt')],stdout=log,stderr=subprocess.STDOUT,check=True)
