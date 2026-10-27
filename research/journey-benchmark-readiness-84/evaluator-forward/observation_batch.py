"""Validate measured observation history before any source cursor mutation."""
from pose_delivery import validate_delivered_pose

def validate_batch(batch,selected,revision,generation,tick,now,last_tick,last_time,last_pose):
 if not isinstance(batch,list)or len(batch)>64:return False,'invalidReleasedBatchSize',[]
 if not batch:
  if selected is None:return True,'noDeliveredPose',[]
  if not isinstance(selected,dict)or selected.get('deliveryMode')!='retained':return False,'newPoseMissingReleasedBatch',[]
  valid,reason=validate_delivered_pose(selected,revision,generation,tick,now,last_tick,last_time,last_pose)
  return valid,reason,[]
 checked=[];prev_tick=last_tick;prev_time=last_time;prev_pose=last_pose
 for observation in batch:
  if not isinstance(observation,dict)or observation.get('deliveryMode')!='new':return False,'releasedBatchMustContainNewObservations',[]
  valid,reason=validate_delivered_pose(observation,revision,generation,tick,now,prev_tick,prev_time,prev_pose)
  if not valid:return False,reason,[]
  checked.append(observation);prev_tick=observation['capturedTick'];prev_time=observation['capturedAt'];prev_pose=observation
 if selected!=checked[-1]:return False,'steeringPoseNotNewestValidatedObservation',[]
 return True,'acceptedMonotonicReleasedBatch',checked
