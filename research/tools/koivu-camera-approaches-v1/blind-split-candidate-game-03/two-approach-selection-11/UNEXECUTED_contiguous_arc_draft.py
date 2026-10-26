"""Two fixed chronological camera-anchored approaches; phone map only.

No actor relocation, later-visit retry, reference input, ROI carving, or map edit.
Camera anchors are proposed simulation-body positions, not measured body poses.
"""
from pathlib import Path
import hashlib,importlib.util,json,math,sys
import numpy as np
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;GAME=HERE.parent;WS=GAME.parent
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
FACTORY=GAME/'three-lap-executor-09/profile_map.py'
NATIVE=GAME/'body-margin-variants-07/native025'
LIB_SHA='b6cd7e2ac35d738337e80597bcbdafd62e6884f5100867d7afbe1b77105709b0'
PROFILES=('body45cmMargin0','body45cmMargin5cm','abstract28cmProfile')
STEP=.025;TURN=math.radians(5);COALESCE=1e-6

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def safe(x):
 if isinstance(x,float)and not math.isfinite(x):return None
 if isinstance(x,dict):return {k:safe(v)for k,v in x.items()}
 if isinstance(x,(list,tuple)):return [safe(v)for v in x]
 return x

def in_roi(xy):
 p=np.asarray(xy);return (p[...,0]<-3)&(p[...,1]>1)&(p[...,1]<3.5)

def fixed_anchors(xy):
 xy=np.asarray(xy,float)
 if xy.ndim!=2 or xy.shape[1]!=2 or not np.isfinite(xy).all():raise ValueError('camera XY')
 inside=in_roi(xy);ids=np.flatnonzero(inside)
 if not len(ids):raise ValueError('no chronological ROI visit')
 first=int(ids[0]);last=first
 while last+1<len(xy)and inside[last+1]:last+=1
 if first==0 or last==len(xy)-1:raise ValueError('first visit lacks outside anchor on both sides')
 result=[]
 for name,goal,direction in [('northSide',first-1,-1),('southSide',last+1,1)]:
  start=goal;arc=0.;indices=[goal]
  while arc<2.:
   nxt=start+direction
   if nxt<0 or nxt>=len(xy)or inside[nxt]:break
   arc+=float(np.linalg.norm(xy[nxt]-xy[start]));start=nxt;indices.append(start)
  result.append({'approachID':name,'startPoseIndex':start,'goalPoseIndex':goal,'recordedOutsideSegmentIndicesGoalOutward':indices,'availableArcMetres':arc,'requestedArcMetres':2.,'shortContiguousSegment':arc<2.,'directAnchorSeparationMetres':float(np.linalg.norm(xy[start]-xy[goal]))})
 return {'firstROIPoseIndex':first,'lastROIPoseIndex':last,'approaches':result}

def game(xy):return [float(xy[0]),0.,-float(xy[1])]
def anchor_receipt(index,frames,xy,model):
 p=xy[index];ij=np.floor((p-np.asarray(model.origin))/.05).astype(int)
 inside=bool(np.all(ij>=0)and np.all(ij<np.asarray(model.mask.shape)))
 return {'poseIndex':index,'frameID':Path(frames[index]['file_path']).stem,'originalCameraLevelXY':p.tolist(),'requestedGamePoint':game(p),'sourceIJ':ij.tolist(),'cellCentreXY':(np.asarray(model.origin)+(ij+.5)*.05).tolist(),'insideRaster':inside,'outsideDisputedROI':not bool(in_roi(p)),'originalPhoneFlags':{k:bool(v[tuple(ij)])for k,v in model.flags.items()}if inside else None,'cameraIsNotMeasuredBodyPose':True,'anchorRelocated':False}

def raw_heading_fit(model,p):
 fit=[k for k in range(72)if model.sampled_fit(p,-math.radians(5*k))]
 return {'someSampledHeadingFits':bool(fit),'fittingSourceHeadingIndices5Degrees':fit,'headingChecks':72,'sampleSpacingMetres':.025}

def assemble(start,goal,leg):
 path=[np.asarray(start,float).copy()];path[0][1]=0.;merges=[]
 for i,p0 in enumerate(leg['points']):
  p=np.asarray(p0,float).copy()
  if p.shape!=(3,)or not np.isfinite(p).all():raise ValueError('nonfinite native point')
  p[1]=0.;distance=float(np.linalg.norm((p-path[-1])[[0,2]]))
  if distance<=COALESCE:merges.append({'nativePointIndex':i,'originalNativePoint':p0,'retainedCandidatePoint':path[-1].tolist(),'residualMetres':distance})
  else:path.append(p)
 endpoint=np.asarray(goal,float).copy();endpoint[1]=0.
 connector=float(np.linalg.norm((endpoint-path[-1])[[0,2]]))
 if connector>.1+1e-9:raise ValueError('goal connector exceeds original association bound')
 if connector>COALESCE:path.append(endpoint)
 else:path[-1]=endpoint
 while len(path)>1 and np.linalg.norm((path[-1]-path[-2])[[0,2]])<=COALESCE:
  merges.append({'removedCandidatePoint':path[-2].tolist(),'retainedExactGoal':endpoint.tolist(),'residualMetres':float(np.linalg.norm((path[-1]-path[-2])[[0,2]]))});del path[-2]
 if len(path)<2:raise ValueError('degenerate fixed anchor pair')
 return np.asarray(path),{'goalConnectorMetresBeforeCoalescing':connector,'goalConnectorNativeSearch':False,'numericalCoalescingBoundMetres':COALESCE,'merges':merges,'actorStartGoalOrPoseChanged':False}

def check_open(model,path):
 xy=np.c_[path[:,0],-path[:,2]];d=np.diff(xy,axis=0);length=np.linalg.norm(d,axis=1);heading=np.arctan2(d[:,1],d[:,0])
 if np.any(length<=COALESCE):raise ValueError('uncoalesced zero segment')
 original=model.rr.sweep_ok(model.mask,model.origin,np.c_[xy[:,0],np.zeros(len(xy)),xy[:,1]])
 endpoints=True;poses=[]
 for i,(a,b,L,theta)in enumerate(zip(xy[:-1],xy[1:],length,heading)):
  for p in(a,b):endpoints &= bool(model.rr.rect_ok(model.mask,model.origin,*p,float(theta)))
  if i:
   previous=float(heading[i-1]);change=(float(theta)-previous+math.pi)%(2*math.pi)-math.pi
   for k in range(int(abs(change)/TURN)+2):poses.append((*a,previous+change*min(1,k*TURN/max(abs(change),1e-9))))
  for v in np.arange(0,L+1e-9,STEP):poses.append((*(a+(b-a)*min(1,float(v/L))),float(theta)))
  poses.append((*b,float(theta)))
 # Diagnostic only. Never changes the map or candidate acceptance predicate.
 centres=0;footprints=0;sample_cells=set()
 for x,y,theta in poses:
  centres+=int(in_roi([x,y]));c,s=math.cos(theta),math.sin(theta);rb=model.rr.RB
  footprint=np.c_[x+rb[:,0]*c-rb[:,1]*s,y+rb[:,0]*s+rb[:,1]*c]
  footprints+=int(np.any(in_roi(footprint)))
  ij=np.floor((footprint-np.asarray(model.origin))/.05).astype(int)
  sample_cells.update(map(tuple,ij.tolist()))
 low=0
 for i,j in sample_cells:
  if 0<=i<model.mask.shape[0]and 0<=j<model.mask.shape[1]:low+=int(model.flags['lowUnresolvedFlag'][i,j])
 return {'passed':original=='ok'and endpoints,'unchangedSourceSweep':original,'exactEndpointHeadingsFit':endpoints,'pathLengthMetres':float(length.sum()),'lengthInHistorical2To6Band':bool(2<=length.sum()<=6),'historicalLengthBandIsDiagnosticNotAcceptance':True,'initialYawRadians':-float(heading[0]),'sampledPoseCount':len(poses),'sampledCentrePosesInsideROI':centres,'sampledFootprintPosesTouchingROI':footprints,'sampledROIIntersectionAffectsAcceptance':False,'uniqueSampledFootprintCells':len(sample_cells),'lowUnresolvedSampledCells':low,'continuousClearanceProven':False,'translationSpacingMetres':STEP,'turnStepDegrees':5}

def select_one(model,profile,geometry,anchor,frames,xy):
 start=game(xy[anchor['startPoseIndex']]);goal=game(xy[anchor['goalPoseIndex']])
 sa=anchor_receipt(anchor['startPoseIndex'],frames,xy,model);ga=anchor_receipt(anchor['goalPoseIndex'],frames,xy,model)
 sf=raw_heading_fit(model,start);gf=raw_heading_fit(model,goal)
 r={'status':'pending','approachID':anchor['approachID'],'profile':profile,'geometry':geometry,'mapRevision':model.revision,'nativeLibrarySHA256':LIB_SHA,'start':start,'goal':goal,'initialYawRadians':None,'nativeInitialRoute':None,'sourceAnchors':{'selection':anchor,'start':sa,'goal':ga},'rawAnchorHeadingFit':{'start':sf,'goal':gf},'referenceInputsUsed':False,'physicalAuthority':False,'mapWasAltered':False,'candidateAssociationMetresMaximum':.1,'actorSnapped':False}
 if not sf['someSampledHeadingFits']or not gf['someSampledHeadingFits']:
  r['status']='rawCameraAnchorFootprintRejected';r['failedAnchors']=[k for k,v in [('start',sf),('goal',gf)]if not v['someSampledHeadingFits']];return r
 leg=model.route(start,goal);r['nativeInitialRoute']=leg
 if not leg['complete']:r['status']='fixedApproachRouteRejected';r['reason']=leg['reason'];return r
 try:path,connectors=assemble(start,goal,leg)
 except ValueError as e:r['status']='fixedApproachConnectorRejected';r['reason']=str(e);return r
 check=check_open(model,path);r['candidatePath']=path.tolist();r['connectorReceipt']=connectors;r['sampledFit']=check
 r['initialYawRadians']=check['initialYawRadians'];r['pathLengthMetres']=check['pathLengthMetres']
 if check['passed']:
  r['status']='selectedPhoneOnlyApproach';r['initialFlags']=model.flag_receipt(start,r['initialYawRadians'])
 else:r['status']='exactEndpointOrOpenPathRejected'
 return r

def fixtures():
 xy=np.array([[0,4],[-1,4],[-2,4],[-2.9,3.2],[-3.2,3.2],[-3.2,2],[-3.1,.9],[-2.8,.6],[-2.7,.5],[-3.2,1.2]])
 r=fixed_anchors(xy);a,b=r['approaches']
 assert(r['firstROIPoseIndex'],r['lastROIPoseIndex'])==(4,5)
 assert a['goalPoseIndex']==3 and a['startPoseIndex']==1 and not a['shortContiguousSegment']
 assert b['goalPoseIndex']==6 and b['startPoseIndex']==8 and b['shortContiguousSegment']
 assert not in_roi([-3,2])and not in_roi([-4,1])and not in_roi([-4,3.5])and in_roi([-4,2])
 path,receipt=assemble([0,0,0],[1,0,0],{'points':[[0,0,0],[1.0000001,.02,0]]})
 assert np.array_equal(path,[[0,0,0],[1,0,0]])and receipt['goalConnectorMetresBeforeCoalescing']<=COALESCE
 assert safe({'p':float('nan')})=={'p':None}
 return 5

def main(output,expected):
 freeze=HERE/'FROZEN.json'
 if sha(freeze)!=expected:raise ValueError('freeze SHA before parse')
 pins=json.loads(freeze.read_text())['files']
 def verify():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('source/input pin changed '+p)
 verify();out=Path(output);out.mkdir(exist_ok=False);nfixtures=fixtures()
 spec=importlib.util.spec_from_file_location('fixed_approach_profile_factory',FACTORY);factory=importlib.util.module_from_spec(spec);spec.loader.exec_module(factory)
 frames=json.loads(POSE.read_text())['frames']
 if len(frames)!=294:raise ValueError('recorded frame count')
 meta=GAME/'inputs/koivu_5cm_v2_pipeline2_out.npz'
 with np.load(meta,allow_pickle=False)as z:R=z['R'];t=z['t']
 xy=(np.array([f['transform_matrix']for f in frames])[:,:3,3]@R.T+t)[:,:2]
 anchors=fixed_anchors(xy);results=[]
 for profile in PROFILES:
  with factory.open_profile_map(profile,NATIVE,LIB_SHA)as model:
   if not np.array_equal(model.R,R)or not np.array_equal(model.t,t):raise ValueError('anchor/model frame mismatch')
   for a in anchors['approaches']:
    result=select_one(model,profile,factory.variants.geometry(profile),a,frames,xy)
    name=profile+'-'+a['approachID']+'.json'
    with(out/name).open('x')as f:json.dump(safe(result),f,indent=2,allow_nan=False);f.write('\n')
    row={'profile':profile,'approachID':a['approachID'],'status':result['status'],'reason':result.get('reason'),'failedAnchors':result.get('failedAnchors'),'pathLengthMetres':result.get('pathLengthMetres'),'artifact':name,'sha256':sha(out/name)};results.append(row);print(json.dumps(row),flush=True)
 verify()
 summary={'scope':'Fixed first-visit two-approach PHONE-ONLY selection; camera anchors are not measured body poses','fixturesPassed':nfixtures,'anchors':anchors,'results':results,'sourceHashesVerifiedBeforeAfter':True,'nativeQueries':sum(json.loads((out/r['artifact']).read_text())['nativeInitialRoute']is not None for r in results),'referenceInputsUsed':False,'movementEpisodesExecuted':0,'physicalAuthority':False,'noLaterVisitOrAlternativeAnchorRetry':True}
 with(out/'RESULTS.json').open('x')as f:json.dump(summary,f,indent=2,allow_nan=False);f.write('\n')
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
