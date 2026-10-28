"""Six fixed points, serial depth projection only; no reconstruction or ray casting."""
from pathlib import Path
import json,hashlib,os
import numpy as np
from PIL import Image
from scipy.ndimage import label
R=Path(__file__).resolve().parent; F=R.parent/'fresh-run'; B=F/'inputs/room_datasets/koivu/iphone/long_capture'
frames=json.loads((B/'transformations.json').read_text())['frames']; by={Path(f['file_path']).stem:f for f in frames}
protocol=json.loads((F/'FUSION_FROZEN.json').read_text()); train=[r['frameID'] for r in protocol['trainingFrames']]
assert len(train)==265 and not set(train)&set(protocol['excludedTestIDs'])
points=[]
for name in ['frame_00228','frame_00197']:
 with np.load(F/'evaluation/tsdf'/f'{name}.npz') as a: row=a['row'];col=a['column'];td=a['axialMetres']
 with np.load(F/'evaluation/faro'/f'{name}.npz') as a: fd=a['axialMetres']
 if name=='frame_00228':
  lab,n=label((np.isfinite(td)&np.isfinite(fd)&(abs(td-fd)>.5)).reshape(249,185)); c=np.bincount(lab.ravel());c[0]=0; ix=np.flatnonzero(lab.ravel()==c.argmax());assert len(ix)==4166
 else: ix=np.flatnonzero((col>=160)&(col<=600)&(row>=780)&(row<=970)&np.isfinite(td)&np.isfinite(fd));assert len(ix)==5328
 f=by[name];pose=np.array(f['transform_matrix']);
 for q in [.25,.5,.75]:
  i=int(ix[int(q*(len(ix)-1))]);z=float(td[i]);u=int(col[i]);v=int(row[i]);cam=np.array([(u-f['cx'])/f['fl_x']*z,-(v-f['cy'])/f['fl_y']*z,-z,1]); world=pose@cam
  rec={'id':f'{name}_q{q}','sourceFrame':name,'quantile':q,'pixel':[u,v],'tsdfAxialMetres':z,'faroAxialMetres':float(fd[i]),'worldPoint':world[:3].tolist(),'observations':[]};points.append(rec)
  inv=np.linalg.inv(pose);back=inv@world;assert abs(-back[2]-z)<1e-12
hashes={}
for name in train:
 f=by[name]; p=B/f['depth_file_path']; raw=p.read_bytes();hashes[name]=hashlib.sha256(raw).hexdigest()
 with Image.open(p) as im:d=np.asarray(im)
 assert d.shape==(994,738)
 inv=np.linalg.inv(np.array(f['transform_matrix']))
 for point in points:
  c=inv@np.r_[point['worldPoint'],1];z=float(-c[2]);o={'frame':name,'pointAxialMetres':z}
  if z<=0:o['status']='behind_camera'
  else:
   u=f['fl_x']*c[0]/z+f['cx'];v=-f['fl_y']*c[1]/z+f['cy'];o['projectedPixel']=[float(u),float(v)]
   # Nearest integer with half-up tie, then explicit raster bounds.
   x=int(np.floor(u+.5));y=int(np.floor(v+.5))
   if not(0<=x<f['w'] and 0<=y<f['h']):o['status']='outside_raster'
   else:
    depth=float(d[y,x])/1000;o.update(samplePixel=[x,y],sensorAxialMetres=depth)
    if depth==0:o['status']='zero_depth'
    elif depth>=4:o['status']='depth_truncated_at_4m'
    else:
     residual=depth-z;o.update(status='admitted_depth',depthMinusPointMetres=residual)
  point['observations'].append(o)
def stat(a):
 return None if not a else {'count':len(a),'min':min(a),'p05':float(np.quantile(a,.05)),'median':float(np.median(a)),'p95':float(np.quantile(a,.95)),'max':max(a)}
for point in points:
 obs=point['observations'];valid=[o['depthMinusPointMetres'] for o in obs if o['status']=='admitted_depth']
 point['summary']={'statusCounts':{k:sum(o['status']==k for o in obs) for k in sorted({o['status'] for o in obs})},'admittedDepthMinusPoint':stat(valid),'positiveResidualCount':sum(x>0 for x in valid),'negativeResidualCount':sum(x<0 for x in valid),'withinOriginal20cmTruncationAxially':sum(abs(x)<=.2 for x in valid)}
out={'scope':'Post-hoc six-point projection diagnostic, not actual TSDF contribution provenance or physical free-space evidence','sampling':'row-major component/rectangle indices floor(q*(n-1)), q=.25,.5,.75; nearest integer pixel floor(coord+.5); no interpolation','coordinates':'original OpenGL C2W; same integer pixel/no half offset as evaluator; inverse training pose projects world point','residualSign':'positive=recorded surface farther than test point, negative=recorded surface nearer (potential occlusion); uncertainty unmeasured','threshold':'20cm is existing fusion sdf_trunc; axial compatibility count only, not exact Euclidean TSDF weighting/contribution','confidence':'unavailable','points':points,'trainingDepthHashes':hashes}
(R/'TRAINING_TRACE.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps([{k:p[k] for k in ['id','pixel','tsdfAxialMetres','summary']} for p in points],indent=2))
