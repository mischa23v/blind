"""Simulation-only controller: fixed goals and source-only drained-handoff queries.

No reference mesh, support, contacts, correction or future pose is an input.
This deliberately does not claim Swift cylindrical clearance for a rectangle.
The original task goal owns arrival; a separate frozen steering target owns route queries.
"""
from pathlib import Path
import json,math,sys,hashlib,copy
import numpy as np
from pose_delivery import validate_delivered_pose
from observation_batch import validate_batch
from loop_map import GoalRegionMap,load_plan
WS=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(Path(__file__).resolve().parent))
from follower import follow_candidate

class Controller:
    def __init__(self):self.model=None;self.goal=None;self.tick=-1;self.revision=None;self.last_capture_tick=-1;self.last_capture_time=-float('inf');self.generation=0;self.last_accepted_pose=None
    def consume(self,p):
        if p.get('command')=='initialize':
            if self.model is not None or set(p)!={'command','planPath','planSHA256'}:raise ValueError('initialization contract')
            self.plan=load_plan(p['planPath'],p['planSHA256']);self.model=GoalRegionMap(self.plan);self.revision=self.model.revision
            self.route_goal=self.point(self.plan['steeringGoalOriginalFrame'])
            return {'physicalAuthority':False,'status':'importedFrozenPolycamNativeProposalOnly','mapRevision':self.revision}
        if p.get('command')=='beginRun':
            if self.model is None or self.goal is not None or set(p)!={'command','goal'}:raise ValueError('single run only')
            self.goal=self.point(p['goal'])
            if not np.array_equal(self.goal,self.point(self.plan['goal'])):raise ValueError('only original physical task goal')
            return {'physicalAuthority':False,'status':'originalTaskGoalRetained','steeringGoalIsNotArrivalOrigin':True}
        if p.get('command')=='beginNextLeg':
            if set(p)!={'command','goal','leg'} or self.goal is None:raise ValueError('next leg contract')
            ix=p['leg']
            if type(ix)is not int or not 0<=ix<len(self.plan['legs']):raise ValueError('valid ordered leg')
            if not np.array_equal(self.point(p['goal']),self.point(self.plan['legs'][ix]['originalTaskGoal'])):raise ValueError('original source goal only')
            self.model.begin_next(ix);self.generation=ix;self.goal=self.point(p['goal']);self.route_goal=self.goal.copy()
            return {'physicalAuthority':False,'status':'sameActorNextLoopLeg','noReset':True,'connectorToFrozenNextStartRequired':False,'actualDeliveredPoseSourceReplanPending':True}
        if set(p)!={'command','tick','now','deliveredPose','releasedPoses'}or p['command']!='tick'or self.goal is None:raise ValueError('physics tick contract')
        if type(p['tick'])is not int or p['tick']!=self.tick+1:raise ValueError('tick order')
        self.tick=p['tick'];pose=p['deliveredPose'];now=float(p['now'])
        row={'physicalAuthority':False,'forwardMetres':0.,'yawRadians':0.,'goalReached':False,'reason':'noDeliveredPose','sourceCapturedAt':None}
        accepted,reason,observations=validate_batch(p['releasedPoses'],pose,self.revision,self.generation,self.tick,now,self.last_capture_tick,self.last_capture_time,self.last_accepted_pose)
        if not accepted:row['reason']=reason;return row
        if pose is None:return row
        progress=[]
        for observation in observations:
            item=self.model.observe_progress(observation['position']);item.update(capturedTick=observation['capturedTick'],capturedAt=observation['capturedAt']);progress.append(item)
        row['releasedObservationProgress']=progress;row['steeringFromNewestOnly']=True
        self.last_accepted_pose=copy.deepcopy(pose);self.last_capture_tick=pose['capturedTick'];self.last_capture_time=pose['capturedAt']
        pos=self.point(pose['position']);yaw=float(pose['yaw']);age=now-float(pose['capturedAt'])
        row['sourceDeliveryMode']=pose['deliveryMode'];row['sourceCapturedTick']=pose['capturedTick'];row['sourceGeneration']=pose['generation']
        row['sourceCapturedAt']=pose['capturedAt'];row['poseAgeSeconds']=age
        # Offline level-map association only; actual world foot Y is retained in
        # physics/trace. No reference-derived horizontal correction occurs.
        planar=pos.copy();planar[1]=0.;goal=self.goal.copy();goal[1]=0.
        route_goal=self.route_goal.copy()
        row['phoneFlagReceipt']=self.model.flag_receipt(planar,yaw)
        # External comparator: retain old-mask flags, never clear them or veto from them.
        error=float(np.linalg.norm((planar-goal)[[0,2]]));row['goalError']=error
        if error<=.35 and float(np.linalg.norm(pos-self.goal))<=.35:row.update(goalReached=True,reason='deliveredPoseGoalStop');return row
        route=self.model.route(pos,route_goal)
        row['sourceReplanReceipt']=route.get('sourceReplanReceipt')
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
        # Same diagnostic-only handling for the proposed footprint.
        # Full-loop objective supersedes old task-only western exclusion.
        # This is not a body/support/unknown collision exemption.
        row['historicalWesternTaskExclusionRemoved']=True
        row.update(forwardMetres=forward,yawRadians=turn,reason=reason,proposalOnly=True,originalMaskApproval=False,nativeCandidatePoints=points.tolist(),permissiveUnknownAdmitted=True)
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
