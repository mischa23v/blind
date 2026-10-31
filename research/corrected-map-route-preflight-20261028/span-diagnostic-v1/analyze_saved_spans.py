"""Analyze saved native spans with released connectivity predicate; no mapping/query rerun."""
from pathlib import Path
import os,resource,time,json,collections
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(60,60));begin=time.monotonic()
import numpy as np,scipy
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import connected_components
H=Path(__file__).resolve().parent;sp=np.load(H/'MERGED_SPANS.npy',mmap_mode='r');d=json.loads((H/'STAGE_DIAGNOSIS.json').read_text());st=d['nativeStageCounts'];height=d['quantizedConfiguration']['walkableHeightCells'];climb=d['quantizedConfiguration']['walkableClimbCells'];columns=collections.defaultdict(list)
for i,r in enumerate(sp):columns[(int(r[0]),int(r[1]))].append(i)
ceilings=np.full(len(sp),65535,np.int32)
for rows in columns.values():
 for i,j in zip(rows,rows[1:]):ceilings[i]=sp[j,2]
lowhead=collections.Counter();clearances=[]
for i,r in enumerate(sp):
 if r[4]==1 and r[5]!=0 and r[6]==0:
  rows=columns[(int(r[0]),int(r[1]))];j=rows[rows.index(i)+1];gap=int(sp[j,2]-r[3]);assert gap<height
  upper='groundHypothesis'if sp[j,4]==1 else'occupiedObstaclePriority';metres=gap*st['ch'];clearances.append(metres)
  label=next(label for limit,label in [(0.04,'0to4cm'),(.08,'4to8cm'),(.16,'8to16cm'),(.4,'16to40cm'),(.8,'40to80cm'),(1.23,'80to123cm')]if metres<=limit)
  lowhead[upper+':'+label]+=1
keep=np.flatnonzero(sp[:,6]!=0);node={int(i):n for n,i in enumerate(keep)};src=[];dst=[];reasons=collections.Counter();heightdiff=collections.Counter();pernode=[]
for ii in keep:
 i=int(ii);x,z,_,top,_,_,_=map(int,sp[i]);counter=collections.Counter()
 for dx,dz in [(-1,0),(0,1),(1,0),(0,-1)]:
  neighbors=columns.get((x+dx,z+dz),[]);survivors=[j for j in neighbors if sp[j,6]!=0];overlap=[j for j in survivors if min(int(ceilings[i]),int(ceilings[j]))-max(top,int(sp[j,3]))>=height];connected=[j for j in overlap if abs(int(sp[j,3])-top)<=climb]
  if connected:
   # Same first qualifying neighbor behavior as released compact build.
   src.append(node[i]);dst.append(node[connected[0]]);reason='connected'
  elif overlap:
   reason='heightDifferenceExceedsZeroClimb';heightdiff[str(min(abs(int(sp[j,3])-top)for j in overlap))]+=1
  elif survivors:reason='neighborSurvivesButVerticalOverlapTooSmall'
  elif not neighbors:reason='noObservedOccupiedSpanInNeighborColumn'
  elif any(sp[j,4]==1 and sp[j,5]!=0 and sp[j,6]==0 for j in neighbors):reason='neighborGroundRemovedForHeadroom'
  elif any(sp[j,4]==1 and sp[j,5]==0 for j in neighbors):reason='neighborGroundRemovedForLedge'
  elif all(sp[j,4]!=1 for j in neighbors):reason='neighborOnlyObstaclePrioritySpans_noGroundHypothesis'
  else:reason='other'
  reasons[reason]+=1;counter[reason]+=1
 pernode.append(counter)
g=csr_matrix((np.ones(len(src),np.uint8),(src,dst)),shape=(len(keep),len(keep)));n,labels=connected_components(g,directed=False);sizes=np.bincount(labels);order=np.sort(sizes)[::-1]
regions=[]
for a in d['anchors']:
 x,z=a['columnXZ'];mask=(np.abs(sp[keep,0]-x)<=20)&(np.abs(sp[keep,1]-z)<=16);ni=np.flatnonzero(mask);c=collections.Counter()
 for j in ni:c.update(pernode[int(j)])
 localidx=np.flatnonzero((np.abs(sp[:,0]-x)<=20)&(np.abs(sp[:,1]-z)<=16));local=sp[localidx]
 regions.append({'anchorIndex':a['anchorIndex'],'fixedWindowColumns':[41,33],'windowMetres':[41*st['cs'],33*st['cs']],'groundHypotheses':int((local[:,4]==1).sum()),'afterLedge':int((local[:,5]!=0).sum()),'afterHeadroom':len(ni),'directionalConnectionReasons':dict(c),'distinctNativeConnectivityComponentsTouchingWindow':int(len(np.unique(labels[ni]))),'largestWholeComponentSizesTouchingWindow':sorted([int(sizes[k])for k in np.unique(labels[ni])],reverse=True)[:10]})
r={'lowHeadRejectedCount':sum(lowhead.values()),'nextOccupiedSpanClassAndClearanceHistogram':dict(lowhead),'clearanceQuantilesMetres':np.quantile(clearances,[0,.25,.5,.75,1]).tolist(),'preErosionCompactSpanCount':len(keep),'directionalConnectivityReasons':dict(reasons),'blockedHeightJumpCellsHistogram':dict(heightdiff),'connectedComponentsBeforeErosion':int(n),'largestComponentSizes':order[:20].tolist(),'singletonComponents':int((sizes==1).sum()),'componentsAtMost25Spans':int((sizes<=25).sum()),'spansInComponentsAtMost25':int(sizes[sizes<=25].sum()),'anchorWindows':regions,'method':'Read-only diagnostic graph reproduces released compact heightfield overlap/climb predicate; scipy.sparse.csgraph.connected_components, not a new planner','scipyVersion':scipy.__version__,'thresholdsChanged':False,'mappingOrNativeQueriesRerun':False,'physicalAuthority':False,'elapsedSeconds':time.monotonic()-begin,'peakSelfRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024};(H/'SAVED_SPAN_CONNECTIVITY_DIAGNOSIS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
