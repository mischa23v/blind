from pathlib import Path
from collections import deque
import json,hashlib,numpy as np
from PIL import Image
H=Path(__file__).resolve().parent;D=H.parent/'error-tail-diagnostic';F=H.parent/'fresh-run';B=F/'inputs/room_datasets/koivu/iphone/long_capture';trace=json.loads((D/'TRAINING_TRACE.json').read_text());freeze=json.loads((F/'FUSION_FROZEN.json').read_text());frames={Path(f['file_path']).stem:f for f in json.loads((B/'transformations.json').read_text())['frames']};train=[x['frameID']for x in freeze['trainingFrames']];checks=0;maxdiff=0.
def ck(x):
 global checks
 assert x;checks+=1
def eq(a,b):
 global maxdiff
 if isinstance(b,dict):
  ck(set(a)==set(b))
  for k in b:eq(a[k],b[k])
 elif isinstance(b,list):
  ck(len(a)==len(b))
  for x,y in zip(a,b):eq(x,y)
 elif isinstance(b,float):
  delta=abs(a-b);maxdiff=max(maxdiff,delta);ck(delta<1e-9+1e-12*abs(b))
 else:ck(a==b)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
flip=np.diag([1,-1,-1,1]);world=[]
for name in ['frame_00228','frame_00197']:
 a=np.load(F/'evaluation/tsdf'/(name+'.npz'));b=np.load(F/'evaluation/faro'/(name+'.npz'));rr=a['row'];cc=a['column'];td=a['axialMetres'];fd=b['axialMetres'];paired=np.isfinite(td)&np.isfinite(fd)
 if name.endswith('228'):
  pending=set(map(int,np.flatnonzero(paired&(abs(td-fd)>.5))));groups=[]
  while pending:
   i=min(pending);pending.remove(i);todo=[i];group=[]
   while todo:
    i=todo.pop();group.append(i);r,c=divmod(i,185)
    for nr,nc in [(r-1,c),(r+1,c),(r,c-1),(r,c+1)]:
     j=nr*185+nc
     if 0<=nr<249 and 0<=nc<185 and j in pending:pending.remove(j);todo.append(j)
   groups.append(group)
  ix=np.array(sorted(max(groups,key=len)));ck(len(ix)==4166)
 else:ix=np.flatnonzero(paired&(cc>=160)&(cc<=600)&(rr>=780)&(rr<=970));ck(len(ix)==5328)
 f=frames[name];C=np.array(f['transform_matrix'])@flip
 for q in [.25,.5,.75]:
  rec=next(p for p in trace['points']if p['sourceFrame']==name and p['quantile']==q);i=ix[int(q*(len(ix)-1))];eq([int(cc[i]),int(rr[i])],rec['pixel']);eq(float(td[i]),rec['tsdfAxialMetres']);eq(float(fd[i]),rec['faroAxialMetres']);point=C@np.array([(cc[i]-f['cx'])*td[i]/f['fl_x'],(rr[i]-f['cy'])*td[i]/f['fl_y'],td[i],1]);eq(point[:3].tolist(),rec['worldPoint']);world.append(point)
world=np.array(world);obs=[[]for _ in world]
for k,name in enumerate(train):
 f=frames[name];p=B/f['depth_file_path'];ck(sha(p)==trace['trainingDepthHashes'][name]);raw=np.asarray(Image.open(p));cam=(np.linalg.inv(np.array(f['transform_matrix'])@flip)@world.T).T
 for j,xyz in enumerate(cam):
  z=float(xyz[2]);o={'frame':name,'pointAxialMetres':z}
  if z<=0:o['status']='behind_camera'
  else:
   u=float(f['fl_x']*xyz[0]/z+f['cx']);v=float(f['fl_y']*xyz[1]/z+f['cy']);o['projectedPixel']=[u,v];x=int(np.floor(u+.5));y=int(np.floor(v+.5))
   if x<0 or y<0 or x>=f['w'] or y>=f['h']:o['status']='outside_raster'
   else:
    depth=float(raw[y,x])/1000;o.update(samplePixel=[x,y],sensorAxialMetres=depth)
    if depth<=0:o['status']='zero_depth'
    elif depth>=4:o['status']='depth_truncated_at_4m'
    else:o.update(status='admitted_depth',depthMinusPointMetres=depth-z)
  eq(o,trace['points'][j]['observations'][k]);obs[j].append(o)
rows=[]
for p,seq in zip(trace['points'],obs):
 compatible=[{'frame':o['frame'],'pixel':o['samplePixel'],'axialResidualMetres':o['depthMinusPointMetres']}for o in seq if o['status']=='admitted_depth' and abs(o['depthMinusPointMetres'])<=.2];eq(len(compatible),p['summary']['withinOriginal20cmTruncationAxially']);rows.append({'id':p['id'],'compatible':compatible})
result={'status':'passed','checks':checks,'maximumFloatingDifference':maxdiff,'comparisonTolerance':'absolute1e-9 plus relative1e-12, for near-camera-plane projected coordinates; integer sample pixels and statuses exact','scriptSHA256':sha(D/'trace_training.py'),'traceSHA256':sha(D/'TRAINING_TRACE.json'),'observationsRecomputed':1590,'trainingDepthHashesVerified':265,'points':rows,'scope':'Independent optical-coordinate projection and nearest-pixel sampling, original GL poses converted with flip. Independently selected row-major component/rectangle quantiles. No TSDF contribution instrumentation, new raycast or reconstruction.','interpretation':'These are six post-hoc surface-point projection checks, not proof that frame74 caused the reconstructed surface or that other images provided clear-space evidence. Axial20cm compatibility is not the exact TSDF integration support/weight.'}
(H/'TRACE_REVIEW.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
