"""Simulation-only controller: supplied phone map + delivered physics pose.

No reference mesh, support, contacts, correction or future pose is an input.
This deliberately does not claim Swift cylindrical clearance for a rectangle.
The original task goal owns arrival; a separate frozen steering target owns route queries.
"""
from pathlib import Path
import json,math,sys,hashlib
import numpy as np
from goal_region_map import GoalRegionMap,load_plan
WS=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(WS/'blind-koivu-game-07'))
from game_model import follow_candidate

class Controller:
    def __init__(self):self.model=None;self.goal=None;self.tick=-1;self.revision=None
    def consume(self,p):
        if p.get('command')=='initialize':
            if self.model is not None or set(p)!={'command','planPath','planSHA256'}:raise ValueError('initialization contract')
            self.plan=load_plan(p['planPath'],p['planSHA256']);self.model=GoalRegionMap(self.plan);self.revision=self.model.revision
            self.route_goal=self.point(self.plan['steeringGoalOriginalFrame'])
            return {'physicalAuthority':False,'status':'importedCorrectedPhoneGoalRegion','mapRevision':self.revision}
        if p.get('command')=='beginRun':
            if self.model is None or self.goal is not None or set(p)!={'command','goal'}:raise ValueError('single run only')
            self.goal=self.point(p['goal'])
            if not np.array_equal(self.goal,self.point(self.plan['goal'])):raise ValueError('only original physical task goal')
            return {'physicalAuthority':False,'status':'originalTaskGoalRetained','steeringGoalIsNotArrivalOrigin':True}
        if set(p)!={'command','tick','now','deliveredPose'}or p['command']!='tick'or self.goal is None:raise ValueError('physics tick contract')
        if type(p['tick'])is not int or p['tick']!=self.tick+1:raise ValueError('tick order')
        self.tick=p['tick'];pose=p['deliveredPose'];now=float(p['now'])
        row={'physicalAuthority':False,'forwardMetres':0.,'yawRadians':0.,'goalReached':False,'reason':'noDeliveredPose','sourceCapturedAt':None}
        if pose is None:return row
        if set(pose)!={'kind','position','yaw','capturedAt','mapRevision'}or pose['kind']!='simulated-physics-body-pose'or pose['mapRevision']!=self.revision:raise ValueError('not matching simulated pose')
        pos=self.point(pose['position']);yaw=float(pose['yaw']);age=now-float(pose['capturedAt'])
        if not math.isfinite(yaw)or not math.isfinite(age)or not 0<=age<=.5:row['reason']='staleOrInvalidSimulatedPose';return row
        row['sourceCapturedAt']=pose['capturedAt'];row['poseAgeSeconds']=age
        # Offline level-map association only; actual world foot Y is retained in
        # physics/trace. No reference-derived horizontal correction occurs.
        planar=pos.copy();planar[1]=0.;goal=self.goal.copy();goal[1]=0.
        route_goal=self.route_goal.copy()
        row['phoneFlagReceipt']=self.model.flag_receipt(planar,yaw)
        if not row['phoneFlagReceipt']['sampledFit']:
            row['reason']='currentSampledPhoneFootprintWithheld';return row
        error=float(np.linalg.norm((planar-goal)[[0,2]]));row['goalError']=error
        if error<=.34 and float(np.linalg.norm(pos-self.goal))<=.35:row.update(goalReached=True,reason='deliveredPoseGoalStop');return row
        route=self.model.route(planar,route_goal)
        if not route['complete'] or len(route['points'])<1:row['reason']='noCompleteNativeCandidate';return row
        pa=np.asarray(route['projectedStart']);pb=np.asarray(route['projectedGoal'])
        if not np.isfinite(pa).all()or not np.isfinite(pb).all()or np.linalg.norm((pa-planar)[[0,2]])>.1 or np.linalg.norm((pb-route_goal)[[0,2]])>.1 or abs(pa[1])>.05 or abs(pb[1])>.05:
            row['reason']='unassociatedNativeCandidate';return row
        points=np.asarray(route['points'],dtype=float)
        if not np.isfinite(points).all()or np.any(np.abs(points[:,1])>.05):row['reason']='unassociatedNativeHeight';return row
        points[:,1]=0.
        if not np.isfinite(points).all():raise ValueError('nonfinite native corners')
        forward,turn,reason=follow_candidate(planar,yaw,points)
        proposed=planar.copy();heading=yaw+turn
        proposed[[0,2]]+=[math.cos(heading)*forward,math.sin(heading)*forward]
        row['proposedPhoneFlagReceipt']=self.model.flag_receipt(proposed,heading)
        if not row['proposedPhoneFlagReceipt']['sampledFit']:
            row['reason']='proposedSampledPhoneFootprintWithheld';return row
        # Conservative original-frame all-yaw radius swept AABB, independent of map.
        g=self.plan['geometry'];radius=math.hypot(g['width']/2+g['margin'],g['depth']/2+g['margin'])
        a=planar[[0,2]]*np.array([1.,-1.]);b=proposed[[0,2]]*np.array([1.,-1.]);lo=np.minimum(a,b)-radius;hi=np.maximum(a,b)+radius
        row['westernExclusionProposedSweep']={'originalLevelXYBounds':[lo.tolist(),hi.tolist()],'conservativeAllYawRadius':radius,'passed':not bool(lo[0]<=-3 and hi[1]>=1 and lo[1]<=3.5)}
        if not row['westernExclusionProposedSweep']['passed']:
            row['reason']='excludedWesternROISweepWithheld';return row
        row.update(forwardMetres=forward,yawRadians=turn,reason=reason,nativeCandidatePoints=points.tolist(),permissiveUnknownAdmitted=True)
        return row
    @staticmethod
    def point(p):
        a=np.asarray(p,dtype=float)
        if a.shape!=(3,)or not np.isfinite(a).all():raise ValueError('finite pose required')
        return a
    def close(self):
        if self.model:self.model.close()
if __name__=='__main__':
    c=Controller()
    try:
        for line in sys.stdin:
            if len(line)>1024**2:raise ValueError('packet cap')
            print(json.dumps(c.consume(json.loads(line)),allow_nan=False),flush=True)
    finally:c.close()
