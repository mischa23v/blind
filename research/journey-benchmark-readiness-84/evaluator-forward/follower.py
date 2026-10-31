import math
import numpy as np
def follow_candidate(position,yaw,points):
    """Same bounded point-follower arithmetic as the prior simulator actuator.

    It consumes native candidate corners, not a hand-authored route. The body
    pose here is the delivered simulated pose; this function never moves truth.
    """
    p=np.asarray(position,dtype=float)
    target=next((np.asarray(q) for q in points if np.linalg.norm((np.asarray(q)-p)[[0,2]])>.01),None)
    if target is None:return 0.,0.,'noDistinctCandidatePoint'
    delta=target-p;target_yaw=math.atan2(delta[2],delta[0])
    error=math.atan2(math.sin(target_yaw-yaw),math.cos(target_yaw-yaw))
    turn=max(-math.radians(1),min(math.radians(1),error))
    distance=min(.02,float(np.linalg.norm(delta[[0,2]]))) if abs(error)<=math.radians(5) else 0.
    return distance,turn,'boundedNativeCandidate'
