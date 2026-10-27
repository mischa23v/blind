"""Frozen source-only single-pair cursor; no reference/occupancy loader or new search."""
from pathlib import Path
import hashlib,json
import numpy as np
H=Path(__file__).resolve().parent
def load_plan(path,digest):
 p=Path(path).resolve()
 if p.parent!=H/'plans' or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:raise ValueError('frozen local pair plan identity')
 r=json.loads(p.read_text());pairs=json.loads((H/'MATRIX.json').read_text())['pairs']
 if type(r['pairIndex'])is not int or not 0<=r['pairIndex']<20 or r['sourcePair']!=pairs[r['pairIndex']]:raise ValueError('original ordered pair identity')
 if r['start']!=r['sourcePair']['startOriginalXYZ']or r['goal']!=r['sourcePair']['goalOriginalXYZ']:raise ValueError('original endpoint mismatch')
 if r['originalFramePath'][0]!=r['start']or r['originalFramePath'][-1]!=r['goal']:raise ValueError('endpoint connector mismatch')
 if r['geometry']!={'width':.45,'depth':.30,'height':1.6,'margin':0.}or r['taskArrivalToleranceMetres']!=.35 or r['cornerConsumptionToleranceMetres']!=.01:raise ValueError('fixed physical/controller dimensions')
 if not r['sourceOnly']or r['physicalAuthority']or r['maximumTicks']!=2500:raise ValueError('scope/tick cap')
 return {**r,'mapRevision':digest,'_path':str(p),'_sha':digest}
class GoalRegionMap:
 def __init__(self,plan):
  self.plan=plan;self.revision=plan['mapRevision'];self.points=np.array(plan['originalFramePath'],float);self.cursor=0;self.leg=0
 def close(self):pass
 def flag_receipt(self,position,yaw):
  return {'lowUnresolvedCells':-1,'source':'historical occupancy diagnostic not available in forward runner','available':False,'approval':False,'physicalAuthority':False,'noSyntheticEligibleCells':True}
 def route(self,start,goal):
  if not np.array_equal(goal,self.plan['goal']):raise ValueError('fixed original pair goal only')
  while self.cursor<len(self.points)and np.linalg.norm((self.points[self.cursor]-start)[[0,2]])<=.01:self.cursor+=1
  return {'complete':True,'points':self.points[self.cursor:].tolist(),'projectedStart':[float(start[0]),0.,float(start[2])],'projectedGoal':list(goal),'fixedCornerCursor':self.cursor,'proposalOnly':True,'referenceInputUsed':False,'fullRectangleValidated':False,'nativeRequeryPerformed':False,'sourceReplanReceipt':None}
 def observe_progress(self,position):
  position=np.asarray(position,float)
  if position.shape!=(3,)or not np.isfinite(position).all():raise ValueError('finite delivered progress observation')
  before=self.cursor
  while self.cursor<len(self.points)and np.linalg.norm((self.points[self.cursor]-position)[[0,2]])<=.01:self.cursor+=1
  return {'cursorBefore':before,'cursorAfter':self.cursor,'positionXYZ':position.tolist(),'unchangedRadiusMetres':.01,'sourceOnly':True}
 def begin_next(self,leg):raise ValueError('single frozen pair only; no handoff/reset')
