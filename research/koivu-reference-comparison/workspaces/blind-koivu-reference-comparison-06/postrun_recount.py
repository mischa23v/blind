"""Independent read-only recount of already saved stage-06 arrays; no VTK or original frames."""
from pathlib import Path
import hashlib,json,math,resource
import numpy as np
resource.setrlimit(resource.RLIMIT_CPU,(20,20))
ROOT=Path(__file__).resolve().parent
RUN=ROOT/'run-evaluate'; DATA=RUN/'comparison'
result=json.loads((DATA/'COMPARISON_RESULTS.json').read_text())
receipt=json.loads((RUN/'RUN_RECEIPT.json').read_text())
checks=0; max_residual=0.
def check(condition,label):
 global checks
 if not condition:raise AssertionError(label)
 checks+=1
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def stats(v):
 v=np.asarray(v,dtype=np.float64).ravel(); n=len(v)
 if not n:return {k:(0 if k=='count' else None) for k in ['count','meanSigned','medianSigned','MAE','medianAbsolute','p90Absolute','p95Absolute']}
 ordered=np.sort(v); absolute=np.sort(abs(v))
 def q(a,p):
  rank=(len(a)-1)*p; lo=int(math.floor(rank));hi=int(math.ceil(rank));return float(a[lo]+(a[hi]-a[lo])*(rank-lo))
 return dict(count=n,meanSigned=float(v.sum()/n),medianSigned=q(ordered,.5),MAE=float(abs(v).sum()/n),medianAbsolute=q(absolute,.5),p90Absolute=q(absolute,.9),p95Absolute=q(absolute,.95))
def same_stats(v,claimed,label):
 global max_residual
 actual=stats(v);check(set(actual)==set(claimed),label+' keys')
 for k,x in actual.items():
  y=claimed[k]
  if x is None:check(y is None,label+' empty '+k)
  elif k=='count':check(x==y,label+' count')
  else:
   residual=abs(x-y);max_residual=max(max_residual,residual);check(math.isfinite(y) and residual<=1e-12,label+' '+k)
 return actual
names=[f'frame_{i+1:05d}' for i in range(0,32,4)]
check(result['fixedIndices']==list(range(0,32,4)) and result['frameCount']==8,'fixed frame schedule')
check(len(result['frames'])==8 and len(result['rayArtifacts'])==8,'eight unique output groups')
check(receipt['exitCode']==0 and receipt['sourceAndInputHashesVerifiedBeforeAndAfter'] is True,'successful external receipt')
check(receipt['configSHA256']==digest(ROOT/'CONFIG.json'),'current config equals receipt')
rows=np.arange(0,994,4)[:,None];cols=np.arange(0,738,4)[None,:]
rr=np.broadcast_to(rows,(249,185));cc=np.broadcast_to(cols,(249,185))
totals=dict(scheduled=0,paired=0,sensorOnly=0,referenceOnly=0,neither=0)
errors=[]; ranges=[[] for _ in range(6)];edges=[[] for _ in range(5)];frame_reports=[];artifact_pins=[]
for fi,name in enumerate(names):
 record=result['frames'][fi]; artifact=result['rayArtifacts'][fi];path=DATA/(name+'-scheduled-rays.npz')
 check(record['basename']==name and record['sourceIndex']==fi*4,'ordered frame identity')
 check(artifact['path']==path.name and artifact['bytes']==path.stat().st_size and artifact['sha256']==digest(path),'NPZ artifact pin')
 artifact_pins.append(artifact)
 check(record==json.loads((DATA/(name+'-metrics.json')).read_text()),'standalone frame report matches pooled report')
 with np.load(path,allow_pickle=False) as z:
  check(set(z.files)=={'row','column','sensorAxialNominalMetres','referenceAxialRegisteredNominalMetres','status','referenceEdgeCategory','referenceCellID'},'array keys')
  a={k:z[k] for k in z.files}
 check(all(v.shape==(249,185) for v in a.values()),'array shapes')
 check(np.array_equal(a['row'],rr) and np.array_equal(a['column'],cc),'exact scheduled pixel addresses')
 s=a['sensorAxialNominalMetres']; r=a['referenceAxialRegisteredNominalMetres']; sv=np.isfinite(s)&(s>0);rv=np.isfinite(r)&(r>0);paired=sv&rv
 check(np.all(rv|np.isnan(r)),'no infinite or nonpositive reference mislabeled missing')
 check(np.all(a['referenceCellID'][~rv]==-1) and np.all((a['referenceCellID'][rv]>=0)&(a['referenceCellID'][rv]<17801112)),'reference cell IDs and unknowns')
 expected=np.where(sv,np.where(rv,0,1),np.where(rv,2,3)).astype(np.uint8)
 check(np.array_equal(a['status'],expected),'availability recomputed from saved depth')
 cnt=dict(scheduled=expected.size,paired=int((expected==0).sum()),sensorOnly=int((expected==1).sum()),referenceOnly=int((expected==2).sum()),neither=int((expected==3).sum()))
 check(cnt==record['counts'],'frame count reconciliation')
 for k,v in cnt.items():totals[k]+=v
 e=s-r;errors.append(e[paired]);same_stats(e[paired],record['allPairedStatistics'],name+' all')
 masks=[rv&(r<.15),rv&(r>=.15)&(r<1),rv&(r>=1)&(r<2),rv&(r>=2)&(r<3),rv&(r>=3)&(r<=5),rv&(r>5)]
 check(np.array_equal(sum(m.astype(np.int8) for m in masks),rv.astype(np.int8)),'range bins disjoint/exhaustive')
 for j,m in enumerate(masks):
  row=record['byReferenceDepth'][j];check(row['referenceValidCount']==int(m.sum()),'reference range support count');v=e[m&paired];ranges[j].append(v);same_stats(v,row['statistics'],name+' range '+str(j))
 edge=np.full(r.shape,-1,dtype=np.int8)
 boundary=np.zeros(r.shape,bool);boundary[[0,-1],:]=True;boundary[:,[0,-1]]=True
 edge[rv&boundary]=0
 neighbors=np.stack([r[:-2,1:-1],r[2:,1:-1],r[1:-1,:-2],r[1:-1,2:]])
 center=r[1:-1,1:-1];valid_center=rv[1:-1,1:-1];valid_neighbors=np.all(np.isfinite(neighbors)&(neighbors>0),axis=0)
 delta=np.max(abs(neighbors-center[None,:,:]),axis=0)
 interior=np.where(valid_neighbors,np.where(delta<=.02,2,np.where(delta<=.10,3,4)),1).astype(np.int8)
 edge[1:-1,1:-1]=np.where(valid_center,interior,-1)
 check(np.array_equal(a['referenceEdgeCategory'],edge),'independent vectorized edge reconstruction')
 for j in range(5):
  m=edge==j;row=record['byReferenceEdge'][j];check(row['referenceValidCount']==int(m.sum()),'reference edge support count');v=e[m&paired];edges[j].append(v);same_stats(v,row['statistics'],name+' edge '+str(j))
 tile_totals={k:0 for k in totals};check(len(record['imageTiles'])==48,'48 tiles')
 for j,tile in enumerate(record['imageTiles']):
  tr,tc=divmod(j,8);check(tile['row']==tr and tile['column']==tc,'tile identity')
  mask=(rr*6//994==tr)&(cc*8//738==tc);states=expected[mask]
  tcounters=dict(scheduled=states.size,paired=int((states==0).sum()),sensorOnly=int((states==1).sum()),referenceOnly=int((states==2).sum()),neither=int((states==3).sum()))
  check(all(tile[k]==v for k,v in tcounters.items()),'tile counts')
  for k,v in tcounters.items():tile_totals[k]+=v
 check(tile_totals==cnt,'tiles reconcile to frame')
 frame_reports.append({'basename':name,**cnt,'MAE':record['allPairedStatistics']['MAE'],'p95Absolute':record['allPairedStatistics']['p95Absolute']})
check(totals==result['totals'] and totals['scheduled']==368520,'aggregate denominator')
pooled=same_stats(np.concatenate(errors),result['allPairedStatistics'],'pooled')
for j,v in enumerate(ranges):same_stats(np.concatenate(v),result['byReferenceDepth'][j]['statistics'],'pooled range '+str(j))
for j,v in enumerate(edges):same_stats(np.concatenate(v),result['byReferenceEdge'][j]['statistics'],'pooled edge '+str(j))
check(sum(x['statistics']['count'] for x in result['byReferenceDepth'])==totals['paired'],'pooled range count')
check(sum(x['statistics']['count'] for x in result['byReferenceEdge'])==totals['paired'],'pooled edge count')
log=[json.loads(x) for x in (RUN/'stdout.log').read_text().splitlines() if x.strip()]
build=[x for x in log if x.get('phase')=='locator_build_completed'];first=[x for x in log if x.get('phase')=='first_native_query_completed'];complete=[x for x in log if x.get('phase')=='frame_complete']
check(len(build)==1 and len(first)==8 and len(complete)==8,'phase telemetry completions')
check([x['basename'] for x in complete]==names,'telemetry frame ordering')
check((RUN/'stderr.log').stat().st_size==0,'stderr empty')
heartbeats=[json.loads(x) for x in (RUN/'heartbeat.jsonl').read_text().splitlines() if x.strip()]
check([x['sequence'] for x in heartbeats]==list(range(len(heartbeats))),'heartbeat sequence')
check(all(x['elapsedWallSeconds']<y['elapsedWallSeconds'] for x,y in zip(heartbeats,heartbeats[1:])),'heartbeat wall monotonic')
check(max(x['sampledPeakTreeRSSBytes'] for x in heartbeats)<=receipt['resources']['sampledPeakTreeRSSBytes'],'heartbeat RSS consistent with receipt')
check(all(result[k] is False for k in ['absoluteAccuracyEstablished','confidenceFabricated','trackingFabricated','registrationFittedHere','detectorOrNavigationCalled','meshMeasuredVsCompletedSurfaceMaskAvailable']),'conservative result flags')
out={'reviewScope':'Independent recount of saved derived NPZ/JSON only. No VTK, ray tracing, original-frame decode, refit or navigation.', 'passed':True,'checksPassed':checks,'maxStatisticAbsoluteResidual':max_residual,'totals':totals,'pairedFraction':totals['paired']/totals['scheduled'],'sensorOnlyFraction':totals['sensorOnly']/totals['scheduled'],'pooledStatistics':pooled,'frames':frame_reports,'referenceDepthBinCounts':[x['statistics']['count'] for x in result['byReferenceDepth']],'referenceEdgeBinCounts':[x['statistics']['count'] for x in result['byReferenceEdge']],'resourceReceipt':receipt['resources'],'locatorBuildWallSeconds':build[0]['buildWallSeconds'],'heartbeatCount':len(heartbeats),'inputReportPins':{'resultsSHA256':digest(DATA/'COMPARISON_RESULTS.json'),'receiptSHA256':digest(RUN/'RUN_RECEIPT.json'),'reviewScriptSHA256':digest(Path(__file__))},'derivedArrayPinsVerified':artifact_pins,'doesNotIndependentlyValidateRayGeometry':True,'doesNotEstablishPhysicalAccuracy':True}
p=ROOT/'POSTRUN_RECOUNT.json'
with p.open('x') as f:json.dump(out,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps({k:v for k,v in out.items() if k not in ['frames','derivedArrayPinsVerified']},indent=2))
