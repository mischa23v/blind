"""Unchanged recorded inputs/profile. Read-only span-stage and native predicate diagnosis."""
from pathlib import Path
import os,resource,time,json,ctypes as C,math,hashlib,collections
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(60,60));start=time.monotonic()
import numpy as np
from occupancy_engine import OccupancyEngine,Config,DT
H=Path(__file__).resolve().parent;ROOT=H.parents[2];P=H.parent/'recorded-ledger-proposal-v1';f=json.loads((P/'FROZEN_INPUTS_AND_ANCHORS.json').read_text());old=json.loads((P/'RECORDED_RESULT.json').read_text());a=np.memmap(ROOT/f['files'][0]['path'],dtype=DT,mode='r')
class Stages(C.Structure):
 _fields_=[(k,C.c_int)for k in ['beforeFilters','afterLedge','afterHead','compact','eroded','distance','regions','polygons','vertices']]+[(k,C.c_float)for k in ['ox','oy','oz','cs','ch']]
with OccupancyEngine(a,Config(**f['configuration']))as e:
 l=e.lib;l.bn_stage_stats.argtypes=[C.POINTER(Stages)];l.bn_stage_stats.restype=None;l.bn_debug_span_count.restype=C.c_int;l.bn_debug_spans.argtypes=[C.c_void_p,C.c_int];l.bn_debug_spans.restype=C.c_int
 ss=Stages();l.bn_stage_stats(C.byref(ss));st={k:getattr(ss,k)for k,_ in ss._fields_};n=l.bn_debug_span_count();sp=np.empty((n,7),np.int32);assert l.bn_debug_spans(sp.ctypes.data,n)==n
 queries=[]
 for pair in f['pairs']:
  aa=f['anchors'][pair['startAnchorIndex']];bb=f['anchors'][pair['goalAnchorIndex']]
  q=e.diagnostic(aa['requestedPlannerXYZ'],bb['requestedPlannerXYZ'],query_half_extents=f['queryHalfExtents'],max_points=f['maxPoints']);assert json.loads(json.dumps(q))==old['queries'][pair['pairIndex']]['result'],'instrumentation changed route';queries.append(q)
 np.save(H/'MERGED_SPANS.npy',sp)
 columns=collections.defaultdict(list)
 for i,row in enumerate(sp):columns[(int(row[0]),int(row[1]))].append(i)
 cfg=f['configuration'];height=int(np.ceil(np.float32(cfg['height'])/np.float32(cfg['cell_height'])));climb=int(np.floor(np.float32(cfg['max_climb'])/np.float32(cfg['cell_height'])));radius=int(np.ceil(np.float32(cfg['radius'])/np.float32(cfg['cell_size'])))
 reasons=collections.Counter();drop_cells=collections.Counter();predicted=[];unmatched=[];adj=collections.Counter();lower=[]
 for i,row in enumerate(sp):
  x,z,lo,top,tag,after,head=map(int,row)
  if tag!=1:continue
  col=columns[(x,z)];pos=col.index(i);ceiling=int(sp[col[pos+1],2])if pos+1<len(col)else 65535
  low=65535;lowtrav=top;hightrav=top;flags=set()
  for dx,dz in [(-1,0),(0,1),(1,0),(0,-1)]:
   nx,nz=x+dx,z+dz
   if nx<0 or nz<0 or nx>=e.stats['width']or nz>=e.stats['depth']:low=-climb-1;flags.add('gridBoundary');break
   nc=columns.get((nx,nz),[]);ng=[int(sp[j,3])for j in nc if sp[j,4]==1]
   if ng:adj[str(min(abs(t-top)for t in ng))]+=1
   else:adj['noNeighborGroundHypothesis']+=1
   ceiling0=int(sp[nc[0],2])if nc else 65535
   if min(ceiling,ceiling0)-top>=height:
    low=-climb-1;flags.add('gapBelowFirstNeighborSpan');break
   for p,j in enumerate(nc):
    ntop=int(sp[j,3]);nceil=int(sp[nc[p+1],2])if p+1<len(nc)else 65535
    if min(ceiling,nceil)-max(top,ntop)<height:continue
    diff=ntop-top;low=min(low,diff)
    if abs(diff)<=climb:lowtrav=min(lowtrav,ntop);hightrav=max(hightrav,ntop)
    elif diff<-climb:flags.add('accessibleNeighborDrop');drop_cells[str(-diff)]+=1;break
  removed=low<-climb or hightrav-lowtrav>climb
  if removed:
   if hightrav-lowtrav>climb:flags.add('accessibleRangeTooSteep')
   reasons['+'.join(sorted(flags))or'other']+=1
  if removed!=(after==0):unmatched.append(i)
  predicted.append(removed)
 # Neighborhood source classes, AABB not cylinder and not support certification.
 anchors=[]
 for anchor in f['anchors']:
  x,y,z=anchor['provisionalTopDatasetWorldXYZ'];rad=cfg['radius'];hi=z+cfg['height'];half=a['size']/2
  roi=(a['x']+half>=x-rad)&(a['x']-half<=x+rad)&(a['y']+half>=y-rad)&(a['y']-half<=y+rad)&(a['z']+half>=z)&(a['z']-half<=hi)
  v=a[roi];ix=int(np.floor((x-st['ox'])/st['cs']));iz=int(np.floor((-y-st['oz'])/st['cs']));near=columns.get((ix,iz),[])
  anchors.append({'anchorIndex':anchor['anchorIndex'],'leafRow':anchor['originalLeafRow'],'exactSourceLeaf':{k:float(a[anchor['originalLeafRow']][k])if k in ['x','y','z','size','probability']else int(a[anchor['originalLeafRow']][k])for k in DT.names},'columnXZ':[ix,iz],'columnSpans':[{'smin':int(sp[j,2]),'smax':int(sp[j,3]),'tag':int(sp[j,4]),'afterLedgeArea':int(sp[j,5]),'afterHeadArea':int(sp[j,6]),'topPlannerY':st['oy']+int(sp[j,3])*st['ch']}for j in near],'intersectingSyntheticBodyAABBOnly':{'occupiedGround':int(((v['occupied']==1)&(v['type']==1)).sum()),'otherOccupied':int(((v['occupied']==1)&(v['type']!=1)).sum()),'observedFree':int((v['occupied']==0).sum()),'unknownVolumeNotComputed':True,'notCylinderCollisionScoring':True}})
 result={'nativeStageCounts':st,'nativeMergedSpanCount':n,'unchanged20QueryOutputs':True,'quantizedConfiguration':{'walkableHeightCells':height,'walkableHeightMetres':height*st['ch'],'walkableClimbCells':climb,'walkableRadiusCells':radius,'walkableRadiusMetres':radius*st['cs'],'marginAddedAgain':False},'releasedLedgePredicateRecount':{'before':len(predicted),'removed':sum(predicted),'retained':len(predicted)-sum(predicted),'nativeDisagreements':len(unmatched),'removalReasons':dict(reasons),'accessibleDropHeightCellsHistogram':dict(drop_cells),'adjacentGroundHypothesisMinHeightDifferenceCellsPartialTraversalHistogram':dict(adj),'histogramTraversalMayShortCircuitLikeUpstream':True},'anchors':anchors,'noThresholdRetune':True,'physicalAuthority':False,'elapsedSeconds':time.monotonic()-start,'peakSelfRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'spanPayloadSHA256':hashlib.sha256((H/'MERGED_SPANS.npy').read_bytes()).hexdigest()}
 (H/'STAGE_DIAGNOSIS.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='anchors'},indent=2));assert not unmatched
