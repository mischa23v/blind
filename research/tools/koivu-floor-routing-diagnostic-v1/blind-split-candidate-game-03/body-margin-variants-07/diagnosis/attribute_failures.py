"""Saved phone-model failure attribution only; no new native/reference queries."""
from pathlib import Path
import hashlib, json, math, sys, time
sys.dont_write_bytecode = True
import numpy as np
from scipy import ndimage
from scipy.spatial import cKDTree
HERE=Path(__file__).resolve().parent; VAR=HERE.parent; GAME=VAR.parent
FOUR=ndimage.generate_binary_structure(2,1);RES=.05
PINS={
 VAR/'margin_variants.py':'661ae8cd72390da3d931dc9b1437be033cfcfe11079d63a708a58afc5a98a9f8',
 GAME/'inputs/koivu_5cm_occthres_split0.7.npz':'b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076',
 GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz':'a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d',
 VAR/'run-01/artifacts/body45cmMargin0.json':'8094003a7d49553a0e7c79d7a3dea1e50f515cdda3ab41652f770e99d6476393',
 VAR/'run-01/artifacts/body45cmMargin5cm.json':'7738cd72dc1ec6bdf49143278231e4f2abd3c516b4ae611cc359f91d60ccbc61',
 VAR/'run-01/artifacts/abstract28cmProfile.json':'a0531d931bdf8e306075691f8acd72f8298644a05dc0f318eb1c275443735e54',
 VAR/'run-01/artifacts/abstract28cmProfile.proposal0125.json':'6fb47a74a07fd0feacfbb6a91da1d942fc1183febb0be2f70d0d2dfa5fe68193'}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def verify():
 for p,h in PINS.items():
  if sha(p)!=h:raise ValueError('saved source/input changed: '+str(p))

def supercover(a,b):
 """All closed grid cells intersected by the centre-to-centre chord, not a route."""
 a=np.asarray(a,int);b=np.asarray(b,int);lo=np.minimum(a,b);hi=np.maximum(a,b)
 ij=np.indices(tuple(hi-lo+1)).reshape(2,-1).T+lo;p=a+.5;d=b-a
 enter=np.zeros(len(ij));leave=np.ones(len(ij));valid=np.ones(len(ij),bool)
 for axis in (0,1):
  if d[axis]==0:valid&=(p[axis]>=ij[:,axis])&(p[axis]<=ij[:,axis]+1)
  else:
   t0=(ij[:,axis]-p[axis])/d[axis];t1=(ij[:,axis]+1-p[axis])/d[axis]
   enter=np.maximum(enter,np.minimum(t0,t1));leave=np.minimum(leave,np.maximum(t0,t1))
 valid&=enter<=leave+1e-12;indices=np.flatnonzero(valid)
 indices=indices[np.lexsort((ij[indices,1],ij[indices,0],enter[indices]))]
 return ij[indices]

def nearest_boundary_pair(labels,a,b):
 if not a or not b or a==b:raise ValueError('two distinct existing components required')
 ca=labels==a;cb=labels==b
 aa=np.argwhere(ca&~ndimage.binary_erosion(ca,structure=FOUR,border_value=0))
 bb=np.argwhere(cb&~ndimage.binary_erosion(cb,structure=FOUR,border_value=0))
 tree=cKDTree(bb);dist,_=tree.query(aa,k=1,workers=1);minimum=float(dist.min());best=None
 for i in np.flatnonzero(dist<=minimum+1e-12):
  for j in tree.query_ball_point(aa[i],minimum+1e-12):
   delta=aa[i]-bb[j];key=(int(delta@delta),int(aa[i,0]),int(aa[i,1]),int(bb[j,0]),int(bb[j,1]))
   if best is None or key<best[0]:best=(key,aa[i].copy(),bb[j].copy())
 return best[1],best[2],{'boundaryCellCounts':[len(aa),len(bb)],'squaredDistanceCellUnits':best[0][0],
  'centreDistanceMetres':math.sqrt(best[0][0])*RES,'method':'upstream cKDTree; exact integer-distance/lexicographic tie-break',
  'guaranteedGlobalGraphMinimumCut':False,'chordIsNotAFeasiblePath':True}

def first_failed_pose(rr,mask,origin,path):
 """Exact routes_rect.sweep_ok sample order, including its original skips."""
 p=np.asarray(path,float);previous=None;ordinal=0
 for si,(a,b)in enumerate(zip(p[:-1],p[1:])):
  d=b-a;length=np.hypot(*d)
  if length<1e-6:continue
  theta=math.atan2(d[1],d[0])
  if previous is not None:
   change=(theta-previous+math.pi)%(2*math.pi)-math.pi
   for k in range(int(abs(change)/math.radians(5))+2):
    angle=previous+change*min(1,k*math.radians(5)/max(abs(change),1e-9));ordinal+=1
    if not rr.rect_ok(mask,origin,a[0],a[1],angle):
     return {'phase':'turn','segmentIndex':si,'sampleIndexWithinPhase':k,'sampleOrdinalOneBased':ordinal,'sourceXY':a.tolist(),'sourceYawRadians':angle}
  for k,t in enumerate(np.arange(0,length+1e-9,.025)):
   q=a+d*t/length;ordinal+=1
   if not rr.rect_ok(mask,origin,q[0],q[1],theta):
    return {'phase':'segment','segmentIndex':si,'sampleIndexWithinPhase':k,'sampleOrdinalOneBased':ordinal,'sourceXY':q.tolist(),'sourceYawRadians':theta,'distanceAlongSegmentMetres':float(t)}
  previous=theta
 return None

def fixtures(rr):
 labels=np.zeros((8,9),int);labels[2:4,1:3]=1;labels[2:4,5:7]=2
 a,b,r=nearest_boundary_pair(labels,1,2)
 assert a.tolist()==[2,2] and b.tolist()==[2,5] and r['squaredDistanceCellUnits']==9
 cells=set(map(tuple,supercover([0,0],[2,2]).tolist()));assert {(0,1),(1,0),(1,2),(2,1)}<=cells
 mask=np.ones((40,40),bool);mask[20:,:]=False;path=np.array([[.5,.5],[1.5,.5]])
 first=first_failed_pose(rr,mask,(0.,0.),path);assert first['phase']=='segment' and .825<=first['sourceXY'][0]<=.875
 assert rr.sweep_ok(mask,(0.,0.),np.c_[path[:,0],np.zeros(2),path[:,1]])=='segment'
 return 3

def main(output):
 verify();started=time.monotonic();sys.path.insert(0,str(VAR));import margin_variants as mv
 rr_test=mv.rectangle_module('abstract28cmProfile');passed=fixtures(rr_test)
 with np.load(GAME/'inputs/koivu_5cm_occthres_split0.7.npz',allow_pickle=False)as z:flags={k:z[k].copy()for k in ('support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk')}
 with np.load(GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz',allow_pickle=False)as z:lo=z['lo'].copy();R=z['R'].copy();t=z['t'].copy();res=float(z['res'])
 mask=flags['walk'];origin=np.asarray(lo[:2],float)*RES;assert mask.shape==(241,250) and res==RES
 distance,nearest=ndimage.distance_transform_edt(mask,return_indices=True);corrected=distance*RES-RES*np.sqrt(2)/2
 def cell(ij):
  i,j=map(int,ij);xy=origin+(np.array([i,j])+.5)*RES;inside=0<=i<mask.shape[0]and 0<=j<mask.shape[1]
  return {'sourceIJ':[i,j],'sourceCentreXY':xy.tolist(),'sourceCellBoundsXY':[*(xy-RES/2).tolist(),*(xy+RES/2).tolist()],
   'gameXYZAtNominalPlane':[float(xy[0]),0.,float(-xy[1])],'phoneXYZAtNominalPlane':(R.T@(np.array([xy[0],xy[1],0.])-t)).tolist(),
   'coordinateMeaning':'nominal-plane cell localization, not measured 3D obstacle position','insideGrid':inside,
   'flags':{k:bool(v[i,j])for k,v in flags.items()}if inside else None}
 rows=[]
 for path in [p for p in PINS if p.parent.name=='artifacts']:
  saved=json.loads(path.read_text());g=saved['geometry'];candidate=saved['candidate'];radius=g['nativeProposalRadius']
  eligible=mask&(corrected>=radius);labels,n=ndimage.label(eligible,structure=FOUR)
  rr=mv.rectangle_module(saved['profile'],radius if saved.get('proposalAttempt')=='proposal0125Fallback'else None)
  for k,leg in enumerate(candidate['nativeLegs']):
   if leg['complete']:continue
   a=candidate['waypoints'][k];b=candidate['waypoints'][(k+1)%4];ai=tuple(a['sourceIJ']);bi=tuple(b['sourceIJ'])
   record={'profile':saved['profile'],'proposalAttempt':saved.get('proposalAttempt','primary'),'legIndex':k,
    'sides':[a['side'],b['side']],'savedReason':leg['reason'],'nativeComplete':leg['nativeComplete'],
    'nativeStatus':leg['nativeStatus'],'nativeError':leg['nativeError'],'proposalRadius':radius,
    'endpointCells':[cell(ai),cell(bi)],'endpointCentreComponents':[int(labels[ai]),int(labels[bi])],
    'centreComponentCount':int(n),'projectedStart':leg['projectedStart'],'projectedGoal':leg['projectedGoal']}
   projected=[]
   for p in (leg['projectedStart'],leg['projectedGoal']):
    if p is None or any(v is None for v in p):projected.append(None);continue
    xy=np.array([p[0],-p[2]]);ij=np.floor((xy-origin)/RES).astype(int);c=cell(ij)
    c['centreComponent']=int(labels[tuple(ij)])if c['insideGrid']else None;projected.append(c)
   record['projectedEndpointCells']=projected
   if not leg['nativeComplete']:
    ca,cb=record['endpointCentreComponents']
    if ca>0 and ca==cb:record['attribution']='sameCentreComponentNativePartial_requiresPlannerRasterAssociationInvestigation'
    elif not ca or not cb:record['attribution']='endpointNotInDeclaredCentreMask'
    else:
     x,y,detail=nearest_boundary_pair(labels,ca,cb);chord=[]
     for ij in supercover(x,y):
      c=cell(ij);ii=tuple(ij);c.update(centreComponent=int(labels[ii]),correctedEDTClearanceMetres=float(corrected[ii]),requiredProposalRadius=radius)
      witness=nearest[:,ij[0],ij[1]];c['nearestBlockedMaskCell']=cell(witness);chord.append(c)
     record.update(attribution='differentCentreComponents_nearestBoundaryPairDiagnosticNotMinimumCut',
      nearestBoundaryPair={'cells':[cell(x),cell(y)],**detail},interveningSupercoverCells=chord)
   else:
    points=np.asarray([a['point']]+leg['points'],float);source=np.c_[points[:,0],-points[:,2]]
    upstream=rr.sweep_ok(mask,origin,np.c_[source[:,0],np.zeros(len(source)),source[:,1]])
    first=first_failed_pose(rr,mask,origin,source)
    if first is None or 'sampled_'+first['phase']!=leg['reason']or first['phase']!=upstream:raise ValueError('saved/replayed first failure disagrees')
    x,y=first['sourceXY'];angle=first['sourceYawRadians'];c,s=math.cos(angle),math.sin(angle)
    points=np.c_[x+rr.RB[:,0]*c-rr.RB[:,1]*s,y+rr.RB[:,0]*s+rr.RB[:,1]*c]
    ij=np.floor((points-origin)/RES).astype(int);unique=np.unique(ij,axis=0);bad=[]
    for v in unique:
     row=cell(v)
     if not row['insideGrid']or not row['flags']['walk']:row['footprintSampleCount']=int(np.all(ij==v,axis=1).sum());bad.append(row)
    first.update(gameXYZAtNominalPlane=[x,0.,-y],gameYawRadians=-angle,totalFootprintSamples=len(rr.RB),
     uniqueFootprintMaskCells=len(unique),offendingCells=bad,allSampledFootprintOffendersReported=True,
     continuousFootprintCoverageProven=False,upstreamReasonVerified=upstream)
    record.update(attribution='firstExactOriginalRectangleSampleFailure',firstFailedSample=first)
   rows.append(record)
 verify()
 result={'scope':'fixed saved phone-model failure attribution, not physical obstacles or a minimum cut','fixtureChecksPassed':passed,
  'records':rows,'sourceInputPinsVerifiedBeforeAfter':True,'sourceInputSHA256':{str(p):h for p,h in PINS.items()},
  'sourceSHA256':sha(__file__),'wallSeconds':time.monotonic()-started,'nativeRouteQueries':0,'referenceInputsUsed':False,
  'parametersChanged':False,'movementEpisodesExecuted':0,'physicalAuthority':False}
 data=(json.dumps(result,indent=2,allow_nan=False)+'\n').encode();assert len(data)<1900*1024
 with Path(output).open('xb')as f:f.write(data)
 print(json.dumps({'records':len(rows),'bytes':len(data),'attributions':{label:sum(r['attribution']==label for r in rows)for label in sorted({r['attribution']for r in rows})}}),flush=True)

if __name__=='__main__':main(sys.argv[1])
