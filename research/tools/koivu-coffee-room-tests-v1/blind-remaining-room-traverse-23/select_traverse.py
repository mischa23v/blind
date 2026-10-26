"""Bounded phone-only chronological horseshoe; immutable maps and prior failures."""
from pathlib import Path
import hashlib, importlib.util, json, math, sys
import numpy as np
HERE=Path(__file__).resolve().parent; WS=HERE.parent
REGION=WS/'blind-goal-region-approach-20/select_goal_region.py'
REGION_SHA='6f4474445b3ef8dbc09c2871c0dc759fe1139ce4a3e4e0c48fadd0c60a56d982'
POSE=WS/'blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json'
START=92; TARGETS=[120,200,220,20]; CAP=32

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(name,path):
 s=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(s);sys.modules[name]=m;s.loader.exec_module(m);return m

def roi_box_overlap(lo,hi):
 # Closed excluded ROI is conservative relative to historical open ROI.
 return bool(lo[0]<=-3 and hi[1]>=1 and lo[1]<=3.5)

def exclusion(path,model,ad,new,old):
 p=np.asarray(path,float);xy=np.c_[p[:,0],-p[:,2]];d=np.diff(xy,axis=0);length=np.linalg.norm(d,axis=1)
 headings=np.arctan2(d[:,1],d[:,0]);rows=[];radius=float(np.linalg.norm(model.rr.RB,axis=1).max())
 for i,(a,b,theta) in enumerate(zip(xy[:-1],xy[1:],headings)):
  c,s=math.cos(theta),math.sin(theta);rb=model.rr.RB
  rotated=np.c_[rb[:,0]*c-rb[:,1]*s,rb[:,0]*s+rb[:,1]*c]
  fp=np.vstack([a+rotated,b+rotated]);game=np.c_[fp[:,0],np.zeros(len(fp)),-fp[:,1]]
  orig,_=ad.map_objective(game,new,old);oldxy=ad.game_to_level(orig)[:,:2];lo=oldxy.min(0);hi=oldxy.max(0)
  rows.append({'kind':'straightSweptFootprintAABB','segment':i,'oldLevelXYBounds':[lo.tolist(),hi.tolist()],'excluded':roi_box_overlap(lo,hi)})
  if i:
   orig,_=ad.map_objective(p[i],new,old);q=ad.game_to_level(orig)[:2]
   lo=q-radius;hi=q+radius
   rows.append({'kind':'allYawTurnDiscAABB','junction':i,'oldLevelXYBounds':[lo.tolist(),hi.tolist()],'excluded':roi_box_overlap(lo,hi)})
 return {'passed':not any(r['excluded'] for r in rows),'conservativeContinuousHorizontalExclusion':True,'overrejectionPossible':True,'originalROI':'X<=-3 and 1<=Y<=3.5 in original level XY','rows':rows}

def main(output,expected):
 f=HERE/'PLANNING_FROZEN.json'
 if sha(f)!=expected:raise ValueError('manifest identity')
 pins=json.loads(f.read_text())['files']
 def verify():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('pin changed '+p)
 verify();out=Path(output);out.mkdir(exist_ok=False)
 if sha(REGION)!=REGION_SHA:raise ValueError('region source pin')
 region=load('traverse_frozen_region',REGION);ad=region.load('traverse_paired',region.ADAPTER,region.ADAPTER_SHA);clearance=region.load('traverse_clearance',region.CLEARANCE,region.CLEARANCE_SHA)
 helpers=ad.helper_modules();old=ad.metadata('old');new=ad.metadata('new')
 frames=json.loads(POSE.read_text())['frames'];raw=(np.array([q['transform_matrix'] for q in frames])[:,:3,3]@old['R'].T+old['t'])
 def anchor(i):return {'poseIndex':i,'frameID':Path(frames[i]['file_path']).stem,'originalGameXYZ':[float(raw[i,0]),0.,float(-raw[i,1])],'cameraIsNotMeasuredBodyPose':True}
 startanchor=anchor(START);targets=[anchor(i) for i in TARGETS];summaries=[]
 for profile in ad.PROFILES:
  model,g=ad.open_model('new',profile)
  try:
   start,_=ad.map_objective(startanchor['originalGameXYZ'],old,new);previous=start;whole=[];legs=[];passed=True;previous_heading=None
   result={'profile':profile,'geometry':g,'map':'new','mapRevision':model.revision,'startAnchor':startanchor,'targetAnchors':targets,'startOriginalGameXYZ':startanchor['originalGameXYZ'],'start':start.tolist(),'referenceInputsUsed':False,'physicalAuthority':False,'movementExecuted':False,'mapWasAltered':False,'rawStartRelocated':False,'selectionPolicy':'sequential first accepted of32 clearance-ranked centres per unchanged original0.35m task region; no backtracking; all prior outcome files preserved','status':'planning','legs':legs}
   for n,anchor_row in enumerate(targets):
    goal=anchor_row['originalGameXYZ'];candidates,ranking=region.rank_candidates(model,new,old,goal,ad,clearance)
    leg={'legIndex':n,'originalTaskGoal':goal,'targetAnchor':anchor_row,'requestedStartCorrectedGameXYZ':previous.tolist(),'candidateRanking':ranking,'rankedCandidates':candidates,'attempts':[],'status':'noAcceptedCandidateIn32CentrePolicy'}
    legs.append(leg)
    for cand in candidates[:CAP]:
     attempt=ad.query_fixed(model,previous,cand['steeringGoal'],helpers);attempt['candidateRank']=cand['rank'];leg['attempts'].append(attempt)
     if attempt['status']!='fixedPhoneModelLegAccepted':continue
     path=np.asarray(attempt['planarFootprintValidationPath']);exc=exclusion(path,model,ad,new,old);attempt['westernExclusion']=exc
     if not exc['passed']:attempt['status']='excludedWesternROISweep';continue
     metric=clearance.path_metric(path,model.origin,clearance.clearance_field(model.mask))
     if previous_heading is not None:
      junction=clearance.junction(model,previous_heading,metric['firstHeading'],[previous[0],-previous[2]],clearance.clearance_field(model.mask));attempt['entryJunction']=junction
      if not junction['passed']:attempt['status']='itineraryJunctionRectangleRejected';continue
      point_old,_=ad.map_objective(previous,new,old);q=ad.game_to_level(point_old)[:2];radius=float(np.linalg.norm(model.rr.RB,axis=1).max())
      if roi_box_overlap(q-radius,q+radius):attempt['status']='excludedWesternROIItineraryTurn';continue
     exposure=helpers['approach'].check_open(model,path)
     if not exposure['passed']:raise ValueError('shared sweep disagreement')
     leg.update(status='selectedPhoneOnlyLeg',selectedCandidateRank=cand['rank'],steeringGoal=cand['steeringGoal'],steeringGoalOriginalGameXYZ=cand['steeringGoalInOriginalGameFrame'],candidatePath=path.tolist(),sampledFitAndUnresolvedExposure=exposure,metric=metric)
     whole.extend(path.tolist() if not whole else path[1:].tolist());previous=np.array(cand['steeringGoal']);previous_heading=metric['lastHeading'];break
    if leg['status']!='selectedPhoneOnlyLeg':passed=False;break
   result['nativeQueries']=sum(len(l['attempts']) for l in legs)
   result['completedPlannedLegs']=sum(l['status']=='selectedPhoneOnlyLeg' for l in legs)
   result['unattemptedTargetIndices']=TARGETS[len(legs):]
   result['status']='selectedPhoneOnlyMainRoomHorseshoe' if passed else 'noCompleteHorseshoeWithinDeclaredFinitePolicy'
   if passed:
    path=np.asarray(whole);result['candidatePath']=path.tolist();result['originalFramePath']=ad.map_objective(path,new,old)[0].tolist();result['pathLengthMetres']=sum(l['metric']['length']for l in legs);result['initialYawRadians']=-legs[0]['metric']['firstHeading'];result['goal']=targets[-1]['originalGameXYZ'];result['allPathExposure']=helpers['approach'].check_open(model,path)
   (out/(profile+'.json')).write_text(json.dumps(ad.safe(result),separators=(',',':'),allow_nan=False)+'\n')
   row={'profile':profile,'status':result['status'],'nativeQueries':result['nativeQueries'],'completedPlannedLegs':result['completedPlannedLegs'],'totalTaskLegs':len(TARGETS),'pathLengthMetres':result.get('pathLengthMetres'),'artifact':profile+'.json','sha256':sha(out/(profile+'.json'))};summaries.append(row);print(json.dumps(row),flush=True)
  finally:model.close()
 # One episode, strongest envelope first; no reference-dependent replacement.
 preference=['body45cmMargin5cm','body45cmMargin0','abstract28cmProfile']
 selected=next((r for p in preference for r in summaries if r['profile']==p and r['status']=='selectedPhoneOnlyMainRoomHorseshoe'),None)
 verify();(out/'RESULTS.json').write_text(json.dumps({'scope':'longer main-room horseshoe corridors; not all floor-area coverage, not small-room entry yet','results':summaries,'oneEpisodeSelected':selected,'episodePreference':preference,'referenceInputsUsed':False,'movementExecuted':False,'sourceInputHashesVerifiedBeforeAfter':True,'excludedOriginalLevelROI':{'xMaximum':-3,'yMinimum':1,'yMaximum':3.5},'itineraryStartPoseIndex':START,'itineraryTargetPoseIndices':TARGETS},indent=2)+'\n')
if __name__=='__main__':main(sys.argv[1],sys.argv[2])
