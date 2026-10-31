"""Verbatim function extraction; no historical episode/controller import."""
import numpy as np

def support_check(row,foot=None):
    heights=[p['modelHeightY']for p in row['probes']if p['hit']]
    span=max(heights)-min(heights)if heights else None
    error=max(abs(v-(0 if foot is None else foot))for v in heights)if heights else None
    accepted=len(heights)==9 and span<=.02 and error<=(.03 if foot is None else .02)
    return {'acceptedFiniteSupportModel':bool(accepted),'hitCount':len(heights),'missingCount':9-len(heights),'spreadMetres':span,'maximumAnchorErrorMetres':error,'heightMinimum':min(heights)if heights else None,'heightMaximum':max(heights)if heights else None,'continuousSupportProven':False,'semanticFloorEstablished':False}

def connected_support(row,ground,previous_y):
    result=support_check(row,previous_y)
    not_ground=[int(p['referenceCellID']) for p in row['probes']
                if p['hit'] and not ground.is_ground(int(p['referenceCellID']))]
    result.update(groundComponentConfirmedForAllProbes=not not_ground and result['hitCount']==9,
                  nonGroundProbeCellIDs=not_ground,
                  supportPolicy='nine first-hit probes on initially seeded shared-edge <=5 degree component')
    result['acceptedFiniteSupportModel']=bool(result['acceptedFiniteSupportModel'] and not not_ground)
    return result

def proposed_ground_motion(scorer,ground,state,proposed,yaw,dyaw):
    """Two short straight physical segments, each with finite connected support.

    Mid/end Y follow actual reference support; XZ and yaw are unchanged from the
    independent actor. Missing/disconnected support is rejected, not repaired.
    """
    midpoint=(state+proposed)*.5
    midrow=scorer.support_probes(midpoint,yaw+dyaw*.5)
    midcheck=connected_support(midrow,ground,float(state[1]))
    if not midcheck['acceptedFiniteSupportModel']:
        return None,[midcheck],None
    midpoint[1]=midcheck['heightMaximum']
    endrow=scorer.support_probes(proposed,yaw+dyaw)
    endcheck=connected_support(endrow,ground,float(midpoint[1]))
    if not endcheck['acceptedFiniteSupportModel']:
        return None,[midcheck,endcheck],None
    proposed=proposed.copy();proposed[1]=endcheck['heightMaximum']
    length=float(np.linalg.norm(midpoint-state)+np.linalg.norm(proposed-midpoint))
    if length>.025000001:
        return None,[midcheck,endcheck],{'reason':'3D movement cap including ground following','attempted3DDistanceMetres':length}
    return (midpoint,proposed),[midcheck,endcheck],{'attempted3DDistanceMetres':length}
