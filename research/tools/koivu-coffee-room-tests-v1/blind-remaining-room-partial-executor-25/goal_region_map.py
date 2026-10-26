"""Phone-only corrected map adapter; world poses stay in the original game frame."""
from pathlib import Path
import hashlib,importlib.util,json,math,sys
import numpy as np
HERE=Path(__file__).resolve().parent;WS=HERE.parent;GAME=WS/'blind-split-candidate-game-03'
PAIRED=WS/'blind-corrected-mask-route-comparison-18/paired_adapter.py'
PAIRED_SHA='86d4510a3f801a2f5dd303fe184c8fe0f3fb1d1c90b9057ab1665352939d7c04'
PLAN=HERE/'SELECTED_PLAN.json'
PLAN_SHA='0c832761ebf4ba7f131416adfad9e63ab39c7c650688fa61395c18d963c4ece6'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load_paired():
 if sha(PAIRED)!=PAIRED_SHA:raise ValueError('paired adapter changed')
 spec=importlib.util.spec_from_file_location('north_frozen_paired_adapter',PAIRED);m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m);return m

def map_yaw(yaw,source,target,paired):
 if not math.isfinite(yaw):raise ValueError('finite yaw')
 origin,_=paired.map_objective(np.zeros(3),source,target)
 head,_=paired.map_objective(np.array([math.cos(yaw),0.,math.sin(yaw)]),source,target)
 delta=head-origin
 if np.linalg.norm(delta[[0,2]])<.99:raise ValueError('heading projection not near-horizontal')
 return math.atan2(delta[2],delta[0])

def load_plan(path=PLAN,digest=PLAN_SHA):
 p=Path(path)
 if p.resolve()!=PLAN.resolve()or digest!=PLAN_SHA or sha(p)!=digest:raise ValueError('fixed candidate identity')
 raw=json.loads(p.read_text());pair=load_paired();old=pair.metadata('old');new=pair.metadata('new')
 if raw['status']!='selectedPhoneOnlyGoalRegionApproach'or raw['profile']!='body45cmMargin0'or raw['map']!='new'or raw['referenceInputsUsed']or raw['physicalAuthority']or raw['startRelocated']:raise ValueError('only fixed phone-only candidate')
 if raw['taskArrivalToleranceMetres']!=.35 or raw['arrivalMustUseOriginalTaskGoal']is not True or raw['steeringGoalIsNotAnArrivalToleranceOrigin']is not True:raise ValueError('original goal authority')
 g=raw['geometry']
 if [g[k]for k in ('width','depth','height','margin')]!=[.45,.30,1.60,0.]:raise ValueError('fixed abstract numerical profile')
 start=np.asarray(raw['startCoordinateProvenance']['originalGameXYZ'],float);goal=np.asarray(raw['taskGoalCoordinateProvenance']['originalGameXYZ'],float)
 for original,mapped in ((start,raw['start']),(goal,raw['originalTaskGoal'])):
  q,_=pair.map_objective(original,old,new)
  if not np.allclose(q,mapped,atol=1e-12,rtol=0):raise ValueError('same physical objective association')
 steering,_=pair.map_objective(raw['steeringGoal'],new,old)
 if np.linalg.norm(steering-goal)>.35:raise ValueError('steering inside original full3D goal region')
 path=np.asarray([pair.map_objective(x,new,old)[0]for x in raw['fullXYZCandidateWithExactGoalConnector']])
 return {**raw,'sourceArtifactSHA256':digest,'originalArtifact':raw,'start':start.tolist(),'goal':goal.tolist(),'steeringGoalOriginalFrame':steering.tolist(),'initialYawRadians':map_yaw(raw['initialYawRadians'],new,old,pair),'originalFramePath':path.tolist(),'approachID':'remainingRoomPartialSouth','sourceAnchors':raw['originalStage11AnchorProvenance'],'physicsFrame':'original supplied level frame','correctedMapPoseFrame':'new supplied level frame','originalGoalOwnsArrival':True}

class GoalRegionMap:
 def __init__(self,plan):
  self.pair=load_paired();self.old=self.pair.metadata('old');self.new=self.pair.metadata('new');self.plan=plan
  self.model,g=self.pair.open_model('new',plan['profile']);self.revision=self.model.revision
  if self.revision!=plan['mapRevision']or g!=plan['geometry']:
   self.close();raise ValueError('candidate/model revision or geometry mismatch')
 def flag_receipt(self,position,yaw):
  pos,_=self.pair.map_objective(position,self.old,self.new);heading=map_yaw(yaw,self.old,self.new,self.pair)
  receipt=self.model.flag_receipt(pos,heading)
  return {**receipt,'inputFrame':'original game','queriedFrame':'corrected game','queriedPositionXYZ':pos.tolist(),'queriedYawRadians':heading,'referenceInputUsed':False}
 def route(self,start,goal):
  if not np.allclose(goal,self.plan['steeringGoalOriginalFrame'],atol=.000001,rtol=0):raise ValueError('only frozen steering target')
  mapped,_=self.pair.map_objective(start,self.old,self.new)
  r=self.model.route(mapped,np.asarray(self.plan['originalArtifact']['steeringGoal']))
  out={**r,'sourceNativeRouteInCorrectedFrame':r,'routeFrame':'original game','referenceInputUsed':False}
  invalid=False
  for key in ('projectedStart','projectedGoal'):
   p=r[key]
   if p is None or np.shape(p)!=(3,)or not np.isfinite(p).all():out[key]=None;invalid=True
   else:out[key]=self.pair.map_objective(p,self.new,self.old)[0].tolist()
  if invalid:
   out.update(complete=False,reason='nativeProjectionUnavailable',points=[],invalidNativeProjectionRetainedAsUnavailable=True);return out
  out['points']=[self.pair.map_objective(p,self.new,self.old)[0].tolist()for p in r['points']]
  return out
 def close(self):
  if self.model:self.model.close();self.model=None
