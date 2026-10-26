"""Read-only original-PLY face and shared-edge/vertex neighbors; no model edits."""
from pathlib import Path
import json,sys,time,resource
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent
sys.path.insert(0,str(WS/'blind-opus-reference-scoring-audit-02/source'))
from score_reference import transform
p=WS/'blind-koivu-faro-acquisition-04/selected-reference/gt_mesh.ply'
start=time.monotonic()
with p.open('rb')as f:
 header=b''
 while not header.endswith(b'end_header\n'):header+=f.readline()
lines=header.decode().splitlines();nv=int(next(x.split()[2]for x in lines if x.startswith('element vertex')));nf=int(next(x.split()[2]for x in lines if x.startswith('element face')))
v=np.memmap(p,dtype='<f8',mode='r',offset=len(header),shape=(nv,6))
faces=np.memmap(p,dtype=np.dtype([('count','u1'),('ids','<u4',(3,))]),mode='r',offset=len(header)+nv*48,shape=(nf,))
face_id=int(sys.argv[1]);ids=faces[face_id]['ids'].copy();assert faces[face_id]['count']==3
with np.load(ROOT/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as a:level={'R':a['R'],'t':a['t']}
A=np.asarray(json.loads((WS/'blind-koivu-faro-acquisition-04/selected-reference/icp_iphone.json').read_text())['gt_transformation']);inverse=np.linalg.inv(transform(level,A))
neighbors=[]
for lo in range(0,nf,100000):
 a=faces[lo:lo+100000]['ids'];n=np.isin(a,ids).sum(1)
 hit=np.flatnonzero(n>0)
 neighbors.extend((int(lo+i),int(n[i]))for i in hit)
rows=[]
for i,common in neighbors:
 xyz=np.asarray(v[faces[i]['ids'],:3]);q=xyz@inverse[:3,:3].T+inverse[:3,3];normal=np.cross(q[1]-q[0],q[2]-q[0]);normal/=np.linalg.norm(normal);tilt=float(np.degrees(np.arccos(np.clip(abs(normal[1]),0,1))))
 rows.append({'cellID':i,'sharedVertices':common,'sharedEdge':common>=2,'pointIDs':faces[i]['ids'].tolist(),'modelPoints':q.tolist(),'modelHeightRange':[float(q[:,1].min()),float(q[:,1].max())],'normal':normal.tolist(),'tiltDegrees':tilt})
result={'faceID':face_id,'target':next(r for r in rows if r['cellID']==face_id),'neighbors':rows,'recordedScoringOrModelChanged':False,'wallSeconds':time.monotonic()-start,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
out=Path(sys.argv[2]);out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['target']));print('neighbors',len(rows))
