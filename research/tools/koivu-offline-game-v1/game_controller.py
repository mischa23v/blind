#!/usr/bin/env python3
"""Isolated offline game controller: phone model + delivered simulated poses only.

No FARO path/mesh/cell/contact/support input is accepted. This is deliberately not
the native sensor worker: recorded Koivu has no genuine live confidence/tracking.
"""
import json,math,sys
import numpy as np
from game_model import PhoneModel,follow_candidate,MODE


class Controller:
    def __init__(self):
        self.model=None;self.goal=None;self.pose=None;self.last_tick=-1;self.run_id=None
        self.last_now=None;self.seen_runs=set()
    def consume(self,p):
        command=p.get('command')
        if command=='initialize':
            if self.model is not None or set(p)!={'command','surfacePath','surfaceSHA256'}:raise ValueError('invalid initialization')
            self.model=PhoneModel(p['surfacePath'],p['surfaceSHA256'])
            return {'status':'phoneModelImported','mode':MODE,'physicalAuthority':False,
                    'mapRevision':self.model.revision,'nativeBuildError':self.model.build_error}
        if self.model is None:raise ValueError('missing initialization')
        if command=='beginRun':
            if set(p)!={'command','runID','goal'}:raise ValueError('unexpected run input')
            if not isinstance(p['runID'],str) or p['runID'] in self.seen_runs or len(self.seen_runs)>=100:
                raise ValueError('repeated/invalid run owner')
            self.goal=self._point(p['goal']);self.pose=None;self.last_tick=-1;self.run_id=str(p['runID'])
            self.last_now=None;self.seen_runs.add(self.run_id)
            return {'status':'gameGoalRetained','runID':self.run_id,'physicalAuthority':False}
        if command!='physicsTick' or set(p)!={'command','runID','tick','now','deliveredPose'} or p['runID']!=self.run_id:
            raise ValueError('unexpected game input')
        tick=p['tick'];now=p['now']
        if (isinstance(tick,bool) or not isinstance(tick,int) or tick!=self.last_tick+1
            or not math.isfinite(now) or now<0 or self.last_now is not None and now<=self.last_now):
            raise ValueError('game clock/order')
        self.last_tick=tick;self.last_now=now
        if p['deliveredPose'] is not None:
            pose=p['deliveredPose']
            if (set(pose)!={'kind','runID','tick','capturedAt','position','yaw','mapRevision'}
                or pose['kind']!='simulated-kinematic-body-pose' or pose['runID']!=self.run_id
                or isinstance(pose['tick'],bool) or not isinstance(pose['tick'],int) or not 0<=pose['tick']<=tick):
                raise ValueError('not explicit simulated body pose')
            self._point(pose['position'])
            if (pose['mapRevision']!=self.model.revision or not math.isfinite(pose['yaw'])
                or not math.isfinite(pose['capturedAt']) or pose['capturedAt']<0 or pose['capturedAt']>now
                or self.pose is not None and (pose['capturedAt']<=self.pose['capturedAt'] or pose['tick']<=self.pose['tick'])):
                raise ValueError('pose association')
            self.pose=pose
        row={'physicalAuthority':False,'mode':MODE,'runID':self.run_id,'tick':tick,
             'mapRevision':self.model.revision,'forwardMetres':0.,'yawRadians':0.,
             'goalReachedByDeliveredPose':False,'sourceCapturedAt':None,'reason':'noDeliveredPose'}
        if self.pose is None:return row
        row['sourceCapturedAt']=self.pose['capturedAt'];row['poseAgeSeconds']=now-self.pose['capturedAt']
        if not 0<=row['poseAgeSeconds']<=.5:row['reason']='staleSimulatedPose';return row
        position=self._point(self.pose['position'])
        if not self.model.native.permits([(position,position)])[0]:
            row['reason']='unknownOrBlockedPhoneModelFootprint';return row
        error=float(np.linalg.norm((position-self.goal)[[0,2]]));row['deliveredGoalErrorMetres']=error
        if error<=.34:
            row['goalReachedByDeliveredPose']=True;row['reason']='deliveredPoseGoalStop';return row
        route=self.model.route(position,self.goal);row['nativeRoute']=route
        if not route['complete']:row['reason']=route['reason'];return row
        forward,yaw,reason=follow_candidate(position,self.pose['yaw'],route['points'])
        proposed=position.copy();heading=self.pose['yaw']+yaw
        proposed[[0,2]]+=[math.cos(heading)*forward,math.sin(heading)*forward]
        if not self.model.native.permits([(position,proposed)])[0]:
            row['reason']='nativeSurfaceWithheldProposedStep';return row
        row.update(forwardMetres=forward,yawRadians=yaw,reason=reason)
        return row
    @staticmethod
    def _point(p):
        a=np.asarray(p,dtype=float)
        if a.shape!=(3,) or not np.isfinite(a).all() or abs(a[1])>1e-9:raise ValueError('not declared level game pose/goal')
        return a
    def close(self):
        if self.model:self.model.close()


def main():
    if len(sys.argv)!=1:raise ValueError('controller stdin only')
    c=Controller()
    try:
        for line in sys.stdin:
            if len(line)>1024*1024:raise ValueError('input line cap')
            row=c.consume(json.loads(line));print(json.dumps(row,separators=(',',':'),allow_nan=False),flush=True)
    finally:c.close()

if __name__=='__main__':main()
