"""Bounded phone-mask steering selection within the unchanged north task region.

The raw start and original task goal are never relocated. A selected steering
centre is not a new arrival-tolerance origin. No reference or actor is involved.
"""
from pathlib import Path
import hashlib, importlib.util, json, math, sys
import numpy as np

sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;WS=HERE.parent
GAME=WS/'blind-split-candidate-game-03'
ADAPTER=WS/'blind-corrected-mask-route-comparison-18/paired_adapter.py'
ADAPTER_SHA='86d4510a3f801a2f5dd303fe184c8fe0f3fb1d1c90b9057ab1665352939d7c04'
CLEARANCE=WS/'blind-flexible-loop-search-19/flexible_loop.py'
CLEARANCE_SHA='d62aafe4cbb9eb37c06bf0b358d895eb12d7efcc239fdefc46dd73e20d6c65d5'
PRIOR=GAME/'two-approach-selection-11/run-01/result'
PRIOR_SHA={
 'body45cmMargin0':'47100b598b9bd4ba4b096b808b032f98c34e6693d638e10823ec5df2246f5c47',
 'body45cmMargin5cm':'7f17151b6a138fbc3a6bb720b0b2324203cc5db510cbdc3fb368b2680d14109f',
 'abstract28cmProfile':'eccc49a8343cf33b382756ee7bf67eb93c3c2b49e33085570815daf144089024'}
REGION=.35;MAX_CANDIDATES=32


def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def load(name,path,expected):
 if sha(path)!=expected:raise ValueError('pinned source changed: '+str(path))
 spec=importlib.util.spec_from_file_location(name,path);module=importlib.util.module_from_spec(spec)
 sys.modules[name]=module;spec.loader.exec_module(module);return module


def region_membership(original_frame_points,original_task_goal):
 p=np.asarray(original_frame_points,float);goal=np.asarray(original_task_goal,float)
 if p.ndim!=2 or p.shape[1]!=3 or goal.shape!=(3,) or not np.isfinite(p).all() or not np.isfinite(goal).all():
  raise ValueError('finite common-original-frame XYZ required')
 delta=p-goal
 horizontal=np.linalg.norm(delta[:,[0,2]],axis=1);full=np.linalg.norm(delta,axis=1)
 return (horizontal<=REGION)&(full<=REGION),horizontal,full


def rank_candidates(model,meta,old,task_goal_old,ad,clearance):
 cells=np.argwhere(model.mask)
 xy=np.asarray(model.origin)+(cells+.5)*.05
 points=np.c_[xy[:,0],np.zeros(len(xy)),-xy[:,1]]
 original_points,_=ad.map_objective(points,meta,old)
 eligible,horizontal,full=region_membership(original_points,task_goal_old)
 ids=np.flatnonzero(eligible)
 field=clearance.clearance_field(model.mask)
 score=clearance.clearance_at(xy[ids],model.origin,field)
 # Original common-frame horizontal distance breaks clearance ties. Full XYZ
 # is additionally bounded, retained and never flattened for task association.
 order=np.lexsort((cells[ids,1],cells[ids,0],horizontal[ids],-score))
 candidates=[]
 for rank,q in enumerate(order):
  idx=ids[q]
  candidates.append({'rank':rank,'sourceIJ':cells[idx].tolist(),
   'steeringGoal':points[idx].tolist(),'steeringGoalInOriginalGameFrame':original_points[idx].tolist(),
   'distanceToOriginalGoalHorizontalMetres':float(horizontal[idx]),
   'distanceToOriginalGoalFull3DMetres':float(full[idx]),
   'originalFrameVerticalDifferenceMetres':float(original_points[idx,1]-task_goal_old[1]),
   'conservativeCentreClearanceLowerBoundMetres':float(score[q]),
   'originalPhoneFlags':{k:bool(v[tuple(cells[idx])])for k,v in model.flags.items()}})
 return candidates,{'walkCentres':len(cells),'horizontalRegionCentres':int((horizontal<=REGION).sum()),
  'horizontalRegionRejectedByFull3DBound':int(((horizontal<=REGION)&(full>REGION)).sum()),
  'eligibleFull3DRegionCentres':len(candidates),'distanceLimitMetres':REGION,
  'ordering':'descending conservative centre clearance; original common-frame horizontal task-goal distance; source i,j',
  'heightZeroMeaning':'steering centres lie on the supplied model plane, not measured body poses',
  'clearanceIsNotPhysicalBodyClearance':True}


def select_one(ad,clearance,helpers,profile,label,old,meta,prior):
 original_start=np.asarray(prior['sourceAnchors']['start']['requestedGamePoint'],float)
 original_goal=np.asarray(prior['sourceAnchors']['goal']['requestedGamePoint'],float)
 start,start_receipt=ad.map_objective(original_start,old,meta)
 task_goal,goal_receipt=ad.map_objective(original_goal,old,meta)
 model,geometry=ad.open_model(label,profile)
 try:
  candidates,ranking=rank_candidates(model,meta,old,original_goal,ad,clearance)
  result={'profile':profile,'map':label,'geometry':geometry,'mapRevision':model.revision,
   'nativeLibrarySHA256':ad.LIB_SHA,'start':start.tolist(),'originalTaskGoal':task_goal.tolist(),
   'startCoordinateProvenance':start_receipt,'taskGoalCoordinateProvenance':goal_receipt,
   'originalStage11AnchorProvenance':prior['sourceAnchors'],'priorFixedPointStatus':prior['status'],
   'startRelocated':False,'actorSnapped':False,'referenceInputsUsed':False,'movementExecuted':False,
   'physicalAuthority':False,'candidateRanking':ranking,'rankedCandidates':candidates,
   'taskArrivalToleranceMetres':REGION,'arrivalMustUseOriginalTaskGoal':True,
   'steeringGoalIsNotAnArrivalToleranceOrigin':True,
   'arrivalScoring':'Future actor must use original task goal and unchanged task-arrival rule, never a second 0.35 m tolerance around steering',
   'attempts':[],'status':'noGoalRegionCandidateWithinFinitePolicy'}
  for candidate in candidates[:MAX_CANDIDATES]:
   steering=candidate['steeringGoal']
   attempt=ad.query_fixed(model,start,steering,helpers)
   attempt['rankedSteeringCandidate']=candidate
   result['attempts'].append(attempt)
   if attempt['status']!='fixedPhoneModelLegAccepted':
    continue
   path=np.asarray(attempt['planarFootprintValidationPath'],float)
   exposure=helpers['approach'].check_open(model,path)
   if not exposure['passed']:raise ValueError('shared open-fit diagnostics disagree with accepted exact query')
   # This is only the same planar footprint-validation polyline. The requested
   # start remains the original full XYZ in start and in the native receipt.
   result.update(status='selectedPhoneOnlyGoalRegionApproach',steeringGoal=steering,
    selectedCandidateRank=candidate['rank'],candidatePath=path.tolist(),
    initialYawRadians=exposure['initialYawRadians'],pathLengthMetres=exposure['pathLengthMetres'],
    sampledFitAndUnresolvedExposure=exposure,nativeInitialRoute=attempt['nativeAndOriginalRectangleResult'],
    fullXYZCandidateWithExactGoalConnector=attempt['fullXYZCandidateWithExactGoalConnector'],
    selectedQueryReceipt=attempt,startPlanarValidationDoesNotRelocateActor=True)
   break
  result['nativeQueries']=len(result['attempts'])
  result['candidateCapReached']=len(result['attempts'])==MAX_CANDIDATES
  result['eligibleCandidatesNotQueried']=len(candidates)-len(result['attempts'])
  result['stoppedAfterFirstAccepted']=result['status']=='selectedPhoneOnlyGoalRegionApproach'
  result['failureScope']='At most first 32 ranked existing centres within the unchanged task region; not proof that all region goals are unreachable'
  return result
 finally:model.close()


def main(output,expected):
 freeze=HERE/'FROZEN.json'
 if sha(freeze)!=expected:raise ValueError('frozen manifest SHA required before parse')
 pins=json.loads(freeze.read_text())['files']
 def verify():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('source/input changed: '+p)
 verify();out=Path(output);out.mkdir(exist_ok=False)
 ad=load('goal_region_adapter',ADAPTER,ADAPTER_SHA)
 clearance=load('goal_region_clearance',CLEARANCE,CLEARANCE_SHA)
 helpers=ad.helper_modules();old=ad.metadata('old');new=ad.metadata('new');summaries=[]
 common_start=common_goal=None
 for profile in ad.PROFILES:
  prior_path=PRIOR/(profile+'-northSide.json')
  if sha(prior_path)!=PRIOR_SHA[profile]:raise ValueError('original raw north objective changed')
  prior=json.loads(prior_path.read_text());s=prior['sourceAnchors']['start']['requestedGamePoint'];g=prior['sourceAnchors']['goal']['requestedGamePoint']
  if common_start is None:common_start,common_goal=s,g
  elif s!=common_start or g!=common_goal:raise ValueError('raw physical objectives differ between profiles')
  for label,meta in [('old',old),('new',new)]:
   result=select_one(ad,clearance,helpers,profile,label,old,meta,prior)
   filename=profile+'-'+label+'.json'
   with(out/filename).open('x')as f:json.dump(ad.safe(result),f,separators=(',',':'),allow_nan=False);f.write('\n')
   row={'profile':profile,'map':label,'status':result['status'],'nativeQueries':result['nativeQueries'],
        'eligibleCandidates':result['candidateRanking']['eligibleFull3DRegionCentres'],
        'selectedCandidateRank':result.get('selectedCandidateRank'),
        'artifact':filename,'sha256':sha(out/filename)}
   summaries.append(row);print(json.dumps(row),flush=True)
 verify()
 count=sum(r['nativeQueries'] for r in summaries)
 if count>192:raise ValueError('fixed overall native query cap')
 with(out/'RESULTS.json').open('x')as f:
  json.dump({'results':summaries,'nativeQueries':count,'originalStartGameXYZ':common_start,
   'originalTaskGoalGameXYZ':common_goal,'taskRegionMetres':REGION,
   'startRelocated':False,'arrivalMustUseOriginalTaskGoal':True,'steeringToleranceCompounded':False,
   'sourceInputHashesVerifiedBeforeAfter':True,'referenceInputsUsed':False,'movementExecuted':False,
   'physicalAuthority':False},f,indent=2);f.write('\n')


if __name__=='__main__':main(sys.argv[1],sys.argv[2])
