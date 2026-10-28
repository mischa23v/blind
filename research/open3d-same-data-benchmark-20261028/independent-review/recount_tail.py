"""Independent bounded tail-component recount, with no scipy/evaluator imports."""
from pathlib import Path
from collections import deque
import json,hashlib,numpy as np
from PIL import Image
H=Path(__file__).resolve().parent;R=H.parent;F=R/'fresh-run';D=R/'error-tail-diagnostic';B=F/'inputs/room_datasets/koivu/iphone/long_capture'
report=json.loads((D/'REGIONAL_RESULTS.json').read_text());doc=json.loads((B/'transformations.json').read_text());images=json.loads((D/'IMAGE_INPUTS.json').read_text()); frames={Path(x['file_path']).stem:x for x in doc['frames']}
checks=0;maxdiff=0.;out=[]
def ck(x):
 global checks
 assert x;checks+=1
def compare(a,b):
 global maxdiff
 if isinstance(b,dict):
  ck(set(a)==set(b))
  for k in b:compare(a[k],b[k])
 elif isinstance(b,list):
  ck(len(a)==len(b))
  for x,y in zip(a,b):compare(x,y)
 elif isinstance(b,float):
  delta=abs(a-b);maxdiff=max(maxdiff,delta);ck(delta<1e-12)
 else:ck(a==b)
def stats(x):
 ck(np.isfinite(x).all())
 return {'count':int(len(x)),'median':float(np.median(x))if len(x)else None,'p95':float(np.quantile(x,.95))if len(x)else None,'mean':float(np.mean(x))if len(x)else None}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for rec in report['frames']:
 name=rec['frame'];f=frames[name];a=np.load(F/'evaluation/tsdf'/(name+'.npz'));b=np.load(F/'evaluation/faro'/(name+'.npz'))
 rows,cols=np.meshgrid(np.arange(0,994,4),np.arange(0,738,4),indexing='ij');rr=rows.ravel();cc=cols.ravel()
 for obj in (a,b):ck(np.array_equal(obj['row'],rr));ck(np.array_equal(obj['column'],cc))
 td=a['axialMetres'];fd=b['axialMetres'];pair=np.isfinite(td)&np.isfinite(fd)
 ck((td[np.isfinite(td)]>0).all());ck((fd[np.isfinite(fd)]>0).all())
 sensor=np.asarray(Image.open(B/'depth'/(name+'.png')))[rr,cc].astype(float)/1000
 im=Image.open(D/'local-rgb'/(name+'.jpg'));ck(im.size==(f['w'],f['h'])==(738,994));ck(im.getexif().get(274,1)==1)
 entry=next(x for x in images['images'] if x['member'].endswith(name+'.jpg'));ck(sha(D/'local-rgb'/(name+'.jpg'))==entry['sha256'])
 # Reproject positive-Z CV rays transformed through the same original GL pose.
 cv=np.column_stack(((cc-f['cx'])/f['fl_x'],(rr-f['cy'])/f['fl_y'],np.ones(len(rr)),np.ones(len(rr))))
 C=np.array(f['transform_matrix'])@np.diag([1,-1,-1,1]);back=(np.linalg.inv(C)@(C@cv.T)).T
 ck(np.max(abs(back[:,0]/back[:,2]*f['fl_x']+f['cx']-cc))<1e-10);ck(np.max(abs(back[:,1]/back[:,2]*f['fl_y']+f['cy']-rr))<1e-10)
 delta=td-fd;large=pair&(abs(delta)>.5);compare(int(pair.sum()),rec['paired']);compare(int(large.sum()),rec['largeOver50cm']);compare(int((large&(delta<0)).sum()),rec['largeEarlier']);compare(int((large&(delta>0)).sum()),rec['largeLater']);compare(stats(abs(delta[pair])),rec['overallAbsolute'])
 # Explicit four-connected flood fill independently reproduces scipy default labelling.
 pending=set(map(int,np.flatnonzero(large)));components=[];height,width=rows.shape
 while pending:
  first=min(pending);pending.remove(first);q=deque([first]);component=[]
  while q:
   i=q.popleft();component.append(i);y,x=divmod(i,width)
   for ny,nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1)):
    j=ny*width+nx
    if 0<=ny<height and 0<=nx<width and j in pending:pending.remove(j);q.append(j)
  components.append(np.array(sorted(component)))
 components.sort(key=lambda x:len(x),reverse=True)
 for ids,expected in zip(components[:8],rec['largestComponents']):
  si=ids[sensor[ids]>0]
  got={'sampleCount':len(ids),'pixelBounds':[int(cc[ids].min()),int(rr[ids].min()),int(cc[ids].max()),int(rr[ids].max())],'tsdfAxial':stats(td[ids]),'faroAxial':stats(fd[ids]),'sensorAxial':stats(sensor[si]),'signed':stats(delta[ids]),'absTsdfSensor':stats(abs(td[si]-sensor[si])),'absFaroSensor':stats(abs(fd[si]-sensor[si]))}
  compare(got,expected)
 out.append({'frame':name,'componentSizes':[len(x)for x in components[:8]],'largestComponentSensorZeroCount':int((sensor[components[0]]==0).sum()),'largestComponentSensorAtLeast4m':int((sensor[components[0]]>=4).sum()),'RGBSHA256':entry['sha256'],'depthSHA256':sha(B/'depth'/(name+'.png'))})
# Optional manually selected boxes: use stated inclusive pixel bounds, never retune.
boxfile=D/'VISUAL_BOX_RESULTS.json'
if boxfile.exists():
 for box in json.loads(boxfile.read_text()):
  name=box['frame'];a=np.load(F/'evaluation/tsdf'/(name+'.npz'));b=np.load(F/'evaluation/faro'/(name+'.npz'));rr=a['row'];cc=a['column'];td=a['axialMetres'];fd=b['axialMetres'];sensor=np.asarray(Image.open(B/'depth'/(name+'.png')))[rr,cc].astype(float)/1000
  x0,y0,x1,y1=box['pixelBounds'];m=(cc>=x0)&(cc<=x1)&(rr>=y0)&(rr<=y1);q=m&np.isfinite(td)&np.isfinite(fd);sm=q&(sensor>0);e=abs(td[q]-fd[q])
  values={'scheduled':int(m.sum()),'paired':int(q.sum()),'over50cm':int((e>.5).sum()),'medianAbsoluteResidual':float(np.median(e)),'p95AbsoluteResidual':float(np.quantile(e,.95)),'tsdfMedianDepth':float(np.median(td[q])),'faroMedianDepth':float(np.median(fd[q])),'sensorMedianDepth':float(np.median(sensor[sm])),'medianAbsTsdfSensor':float(np.median(abs(td[sm]-sensor[sm]))),'medianAbsFaroSensor':float(np.median(abs(fd[sm]-sensor[sm])))}
  for k,v in values.items():compare(v,box[k])
res={'status':'passed','checks':checks,'maximumFloatingDifference':maxdiff,'reviewedScriptSHA256':sha(D/'inspect_tail.py'),'reviewedResultSHA256':sha(D/'REGIONAL_RESULTS.json'),'reviewedVisualBoxesSHA256':sha(boxfile) if boxfile.exists() else None,'frames':out,'scope':'Independent four-connected components, summaries, integer pixel grid, zero-depth exclusion, RGB dimensions/orientation/hash and algebraic projection roundtrip. No raycast repeated. Full saved ray evaluation and pose/registration already reviewed separately.','caveats':['Post-hoc selected regions; not unbiased scene-wide accuracy.','All distances axial metres, not Euclidean range.','Some recorded depths exceed fusion input cutoff; do not assume all corresponding surfaces were observed in training.','Display extent uses raster bins; numerical labels use exact stride-4 integer coordinates.','Observed earlier/later reconstructed first hits do not uniquely identify drift, truncation, changed furniture or implementation cause.','No measured-reference mask or physical hazard labels; no safety or false-clear/block rate.']}
(H/'TAIL_REVIEW.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps(res,indent=2))
