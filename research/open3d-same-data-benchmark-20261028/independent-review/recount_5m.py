from pathlib import Path
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
import ast,json,hashlib,numpy as np
from PIL import Image
H=Path(__file__).resolve().parent;F=H.parent/'fresh-run';P=H.parent/'range-ablation-proposal';V=P/'run'
# Reuse earlier independent review's formulas, not the producing evaluator.
exec((H/'recount.py').read_text().split("protocol=json.loads")[0])
check(digest(P/'FROZEN.json')=='0b9e6eeee19565a3ca2112ea926a2ecdbdf4c930528e7bfe8d063323d164d448')
frozen=json.loads((P/'FROZEN.json').read_text());codepins=0
for p,h in frozen['pins'].items():
 if Path(p).suffix in ('.py','.json') and Path(p).stat().st_size<5000000:check(digest(p)==h);codepins+=1
old=(F/'fusion_worker.py').read_text();new=(P/'fusion_5m.py').read_text();new=new.replace('depth_trunc=5.0','depth_trunc=4.0').replace("'depthTrunc':5.0","'depthTrunc':4.0").replace('Post-hoc 5 m range ablation of author-configured Koivu fusion; not untouched validation, SLAM or navigation','Author-configured observed-depth Koivu provided-pose fusion; not SLAM, accuracy or navigation')
def fun(src,name):return ast.dump(next(n for n in ast.parse(src).body if isinstance(n,ast.FunctionDef)and n.name==name),include_attributes=False)
check(fun(old,'worker')==fun(new,'worker'));check(fun((F/'summarize_common.py').read_text(),'summary')==fun((P/'summarize_5m.py').read_text(),'summary'))
result=json.loads((V/'COMMON_GEOMETRY_RESULTS.json').read_text());comp=json.loads((V/'COMPARISON.json').read_text());protocol=json.loads((V/'EVALUATOR_FROZEN.json').read_text());ids=protocol['frameIDs'];check(ids==json.loads((F/'EVALUATOR_FROZEN.json').read_text())['frameIDs']);check(len(ids)==29)
records={r['frameID']:r for r in json.loads((V/'evaluation/tsdf/RESULT.json').read_text())['records']};refs=[];preds=[];raws=[];saved={}
for i,name in enumerate(ids):
 path=V/'evaluation/tsdf'/(name+'.npz');check(digest(path)==records[name]['fileSHA256'])
 with np.load(path)as a,np.load(F/'evaluation/faro'/(name+'.npz'))as b,np.load(F/'evaluation/tsdf'/(name+'.npz'))as c:
  check(np.array_equal(a['row'],b['row'])and np.array_equal(a['column'],b['column']));check(np.array_equal(np.isfinite(a['axialMetres']),a['cellID']>=0));ref=b['axialMetres'].copy();pred=a['axialMetres'].copy();saved[name]=(a['row'].copy(),a['column'].copy(),c['axialMetres'].copy(),ref,pred)
 refs.append(ref);preds.append(pred)
 compare(dict(frameID=name,**geometry(ref,pred)),result['frames'][i])
 with Image.open(F/'inputs/room_datasets/koivu/iphone/long_capture/depth'/(name+'.png'))as im:raws.append(np.asarray(im)[::4,::4].ravel().copy())
compare(geometry(np.concatenate(refs),np.concatenate(preds)),result['pooled']);compare(sensor(np.concatenate(raws),np.concatenate(preds)),result['heldoutProcessedSensorConsistency'])
for p in comp['points']:
 name=p['id'].split('_q')[0];u,v=p['pixel'];r,c,base,ref,pred=saved[name];i=np.where((r==v)&(c==u))[0];check(len(i)==1);i=i[0];compare(p['variant5mAxial'],float(pred[i]));compare(p['baseline4mAxial'],float(base[i]));compare(p['faroAxial'],float(ref[i]))
for region in comp['fixedRegions']:
 name=region['frame'];r,c,base,ref,pred=saved[name]
 if name=='frame_00228':
  mask=(np.isfinite(base)&np.isfinite(ref)&(abs(base-ref)>.5)).reshape(249,185);seen=np.zeros(mask.shape,bool);components=[]
  for y,x in zip(*np.where(mask)):
   if seen[y,x]:continue
   seen[y,x]=True;todo=[(y,x)];group=[]
   while todo:
    yy,xx=todo.pop();group.append(yy*185+xx)
    for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
     ny,nx=yy+dy,xx+dx
     if 0<=ny<249 and 0<=nx<185 and mask[ny,nx]and not seen[ny,nx]:seen[ny,nx]=True;todo.append((ny,nx))
   components.append(group)
  m=np.zeros(len(r),bool);m[max(components,key=len)]=True;check(m.sum()==4166)
 else:m=(c>=160)&(c<=600)&(r>=780)&(r<=970)&np.isfinite(base)&np.isfinite(ref);check(m.sum()==5328)
 for label,z in [('baseline4m',base),('variant5m',pred)]:
  valid=m&np.isfinite(z)&np.isfinite(ref);e=z[valid]-ref[valid]
  compare({'paired':int(valid.sum()),'missingPrediction':int(np.count_nonzero(m&~np.isfinite(z))),'medianAbsolute':float(np.median(abs(e))),'p95Absolute':float(np.quantile(abs(e),.95)),'signedMin':float(e.min()),'signedMedian':float(np.median(e)),'signedMax':float(e.max())},region[label])
report={'status':'passed','checksPassed':checks,'floatingComparisons':floats,'maximumStatisticDifference':max_delta,'codeAndJSONPinsChecked':codepins,'workerASTEquivalentExceptRangeAndScope':True,'summaryFunctionASTIdentical':True,'geometryQueries':0,'frozenSHA256':digest(P/'FROZEN.json'),'resultSHA256':digest(V/'COMMON_GEOMETRY_RESULTS.json'),'all29Availability':result['pooled']['availability'],'variantAllPaired':result['pooled']['all']['statistics'],'fixedRegions':comp['fixedRegions'],'limitations':['Post-hoc development ablation, not independent holdout validation','Changing cutoff affects both admitted observations and allocated TSDF coverage, not purely clearing','No physical safety or navigation conclusion','Native ray queries not independently repeated; small source/JSON pins and saved arrays checked, not all large training archives rehashed']}
(H/'RANGE_5M_REVIEW.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
