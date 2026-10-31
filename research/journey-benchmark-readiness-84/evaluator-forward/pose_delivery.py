"""Synthetic observation transport, not a perception system or world authority."""
from pathlib import Path
import json,math,sys
from dataclasses import asdict
import numpy as np
H=Path(__file__).resolve().parent;W=H.parent
sys.path.insert(0,str(H))
from impairments import SensorFIFO,SensorProfile

def condition_by_id(name):
 matches=[x for x in json.loads((H/'CONDITIONS.json').read_text())['conditions']if x['id']==name]
 if len(matches)!=1:raise ValueError('unknown unique frozen condition')
 return matches[0]

import os
SESSION_ID=os.environ.get('FROZEN_EPISODE_SESSION_ID','stage84-contract-fixtures')

class PoseDelivery:
 def __init__(self,condition,seed):
  self.condition=condition;self.queue=SensorFIFO(SensorProfile(seed=seed,**condition['poseDelivery']));self.cached=None;self.context=None;self.invalid_context=False
 def capture_and_release(self,tick,now,state,yaw,revision,generation):
  context=(SESSION_ID,revision,generation)
  if self.context is None:self.context=context
  if context!=self.context:self.invalid_context=True;self.cached=None
  if self.invalid_context:return None,{'capture':None,'captureWithheld':False,'disposition':None,'released':[],'selectedSourceTick':None,'coalescedPackets':0,'pendingPackets':len(self.queue.pending),'syntheticOnly':True,'truePosePassedDirectlyToController':False,'invalidContextLatched':True,'retainedObservation':False,'newPacketSelected':False}
  interval=self.condition['withholdCaptureTicks'];withheld=interval is not None and interval[0]<=tick<interval[1];disposition=None;capture=None
  if not withheld:
   capture={'kind':'simulated-physics-body-pose','position':np.asarray(state).tolist(),'yaw':float(yaw),'capturedAt':now,'capturedTick':tick,'generation':generation,'mapRevision':revision,'sessionID':SESSION_ID}
   disposition=asdict(self.queue.submit(tick,{'tick':tick,'receivedAt':now,'command':'continue','pose':capture}))
  released=self.queue.release(tick,now);new=bool(released)
  if new:
   import copy
   candidate=released[-1].packet['pose']
   if (candidate.get('sessionID'),candidate.get('mapRevision'),candidate.get('generation'))!=self.context or (self.cached is not None and candidate['capturedTick']<=self.cached['capturedTick']):
    self.invalid_context=True;self.cached=None
   else:self.cached=copy.deepcopy(candidate)
  delivered=None
  if self.cached is not None and not self.invalid_context and 0<=now-self.cached['capturedAt']<=.5:
   import copy
   delivered=copy.deepcopy(self.cached);delivered['deliveryMode']='new'if new else'retained'
  return delivered,{'capture':capture,'captureWithheld':withheld,'disposition':disposition,'released':[asdict(r)for r in released],'selectedSourceTick':delivered['capturedTick']if delivered else None,'coalescedPackets':max(0,len(released)-1),'pendingPackets':len(self.queue.pending),'syntheticOnly':True,'truePosePassedDirectlyToController':False,'newPacketSelected':new,'retainedObservation':bool(delivered and not new),'retainedOriginalCaptureTimestamp':delivered['capturedAt']if delivered else None,'invalidContextLatched':self.invalid_context}

def validate_delivered_pose(p,revision,generation,tick,now,last_tick,last_time,last_pose=None):
 keys={'kind','position','yaw','capturedAt','capturedTick','generation','mapRevision','sessionID','deliveryMode'}
 if not isinstance(p,dict) or set(p)!=keys or p['kind']!='simulated-physics-body-pose' or p['mapRevision']!=revision:return False,'wrongSimulatedPoseSchemaOrRevision'
 if p['sessionID']!=SESSION_ID:return False,'wrongObservationSession'
 if p['deliveryMode']not in ('new','retained'):return False,'wrongObservationDeliveryMode'
 retained=p['deliveryMode']=='retained'
 if retained and (last_pose is None or any(p[k]!=last_pose[k]for k in keys if k!='deliveryMode')):return False,'retainedObservationNotExactPreviouslyAcceptedPacket'
 if type(p['generation'])is not int or p['generation']!=generation:return False,'wrongObservationGeneration'
 t=p['capturedTick'];time=p['capturedAt']
 if type(t)is not int or not 0<=t<=tick or (t<last_tick or (t==last_tick and not retained)):return False,'nonmonotonicOrFutureCaptureTick'
 if isinstance(time,bool) or not isinstance(time,(int,float)) or not math.isfinite(time) or (time<last_time or (time==last_time and not retained)) or abs(time-(100+t/15))>1e-9:return False,'nonmonotonicOrWrongCaptureTimestamp'
 try:pos=np.asarray(p['position'],float)
 except (TypeError,ValueError):return False,'malformedDeliveredPosition'
 if pos.shape!=(3,)or not np.isfinite(pos).all()or isinstance(p['yaw'],bool)or not isinstance(p['yaw'],(int,float))or not math.isfinite(p['yaw']):return False,'nonfiniteDeliveredPose'
 if not 0<=now-time<=.5:return False,'staleOrInvalidSimulatedPose'
 return True,'acceptedSimulatedObservation'

def goal_observation_current(cue,delivered,generation,last_motion_tick):
 return bool(delivered is not None and delivered.get('deliveryMode')=='new' and cue.get('sourceDeliveryMode')=='new' and cue.get('goalReached') and cue.get('sourceGeneration')==generation==delivered.get('generation') and cue.get('sourceCapturedTick')==delivered.get('capturedTick') and type(delivered.get('capturedTick'))is int and delivered['capturedTick']>last_motion_tick)
