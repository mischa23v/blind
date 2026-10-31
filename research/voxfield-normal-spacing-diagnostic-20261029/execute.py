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
headers=[]
base=Path('<WORKSPACE_ROOT>/research/open3d-same-data-benchmark-20261028/fresh-run/inputs/room_datasets/koivu/iphone/long_capture/depth')
for i in range(1,4):
 p=base/f'frame_{i:05d}.png';data=p.read_bytes()
 assert data[:8]==b'\x89PNG\r\n\x1a\n' and data[12:16]==b'IHDR'
 w,h,bit,color=struct.unpack('>IIBB',data[16:26]);assert (w,h,bit,color)==(738,994,16,0)
 headers.append(dict(frame=i,width=w,height=h,bitDepth=bit,colorType=color,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
(R/'PNG_HEADERS.json').write_text(json.dumps(headers,indent=2)+'\n')
with (R/'compile.log').open('w') as log:
 subprocess.run(['/usr/bin/g++','-O1','-std=c++14','-I<WORKSPACE_ROOT>/research/rtabmap-same-data-benchmark-20261028/fresh-run/prefix/usr/include/eigen3','-I',str(H.parent/'n2-normal-candidate'),str(H/'diagnostic.cpp'),'-o',str(R/'diagnostic')],stdout=log,stderr=subprocess.STDOUT,check=True)
with (R/'measurements.txt').open('w') as log:
 subprocess.run([str(R/'diagnostic'),str(H.parent/'prefix3-d1-n2/frames3.txt')],stdout=log,stderr=subprocess.STDOUT,check=True)
