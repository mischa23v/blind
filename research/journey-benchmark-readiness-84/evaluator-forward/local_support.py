"""Frozen simulated local ground following. No perception or horizontal steering."""
from pathlib import Path
import sys,math,numpy as np
H=Path(__file__).resolve().parent
import physics_primitives as motion
from oriented_container import sweep_enclosure
RESIDUAL=.002;SLOPE_DEGREES=5.;ASSOCIATION=.02;STATE_EPS=1e-6

def rows_values(row):
 p=row.get('probes',[])
 if len(p)!=9 or not all(x.get('hit',False)for x in p):raise ValueError('nine observed finite support probes required')
 xyz=np.array([[*x['modelXZ'],x['modelHeightY']]for x in p],float)
 if xyz.shape!=(9,3)or not np.isfinite(xyz).all():raise ValueError('finite support coordinates required')
 return xyz[:,:2],xyz[:,2]

def validate_support_pose(row,pose,yaw):
    xz,_=rows_values(row);pose=np.asarray(pose,float)
    if pose.shape!=(3,)or not np.isfinite(pose).all()or not math.isfinite(yaw):raise ValueError('finite support pose/yaw required')
    offsets=[(0.,0.)]+[(x*.075,z*.1125)for x,z in((-1,-1),(-1,1),(1,-1),(1,1))]+[(x*.15,z*.225)for x,z in((-1,-1),(-1,1),(1,-1),(1,1))]
    f=np.array([math.cos(yaw),math.sin(yaw)]);lat=np.array([-math.sin(yaw),math.cos(yaw)]);expected=np.array([pose[[0,2]]+f*x+lat*z for x,z in offsets])
    if np.max(np.abs(xz-expected))>1e-9:raise ValueError('support probe order/pose mismatch')
    return True

def height(row):return float(rows_values(row)[1].max())
def connected(row,ground,previous_y,pose=None,yaw=None):
 try:
  rows_values(row)
  if pose is not None:validate_support_pose(row,pose,yaw)
 except(ValueError,KeyError,TypeError)as exc:return {'acceptedFiniteSupportModel':False,'reason':str(exc),'groundComponentConfirmedForAllProbes':False}
 r=motion.connected_support(row,ground,previous_y);r['supportPolicy']='same immutable floor IDs, nine observed support heights, local actual foot datum';return r

def continuity(oldrow,newrow,previous_y,old_pose,old_yaw,new_pose,new_yaw):
 try:validate_support_pose(oldrow,old_pose,old_yaw);validate_support_pose(newrow,new_pose,new_yaw)
 except(ValueError,KeyError,TypeError)as exc:return {'accepted':False,'reason':str(exc),'probeOrderValidated':False}
 oldxz,oldh=rows_values(oldrow);newxz,newh=rows_values(newrow);displacement=float(np.linalg.norm(newxz-oldxz,axis=1).max());limit=2*RESIDUAL+math.tan(math.radians(SLOPE_DEGREES))*displacement;delta=abs(float(newh.max())-previous_y);prior_error=abs(float(oldh.max())-previous_y)
 return {'accepted':bool(prior_error<=STATE_EPS and delta<=limit+1e-12),'previousFootMatchesPreviousMax9':prior_error<=STATE_EPS,'previousFootMax9ErrorMetres':prior_error,'maximumCorrespondingProbeXZDisplacementMetres':displacement,'heightDeltaMetres':delta,'heightChangeLimitMetres':limit,'twoSidedExistingResidualAllowanceMetres':2*RESIDUAL,'existingFloorSlopeDegrees':SLOPE_DEGREES,'probeOrderValidated':True,'probePoseToleranceMetres':1e-9}

def proposed_ground_motion(scorer,ground,state,proposed,yaw,dyaw):
 startrow=scorer.support_probes(state,yaw);startcheck=connected(startrow,ground,float(state[1]),state,yaw)
 if not startcheck['acceptedFiniteSupportModel']:return None,[startcheck],None
 if abs(height(startrow)-state[1])>STATE_EPS:return None,[{'acceptedFiniteSupportModel':False,'reason':'actual foot differs from previous observed max9; no snap'}],None
 midpoint=(state+proposed)*.5;midrow=scorer.support_probes(midpoint,yaw+dyaw*.5);midcheck=connected(midrow,ground,float(state[1]),midpoint,yaw+dyaw*.5)
 if not midcheck['acceptedFiniteSupportModel']:return None,[midcheck],None
 midcontinuity=continuity(startrow,midrow,float(state[1]),state,yaw,midpoint,yaw+dyaw*.5);midcheck['localHeightContinuity']=midcontinuity
 if not midcontinuity['accepted']:midcheck['acceptedFiniteSupportModel']=False;return None,[midcheck],None
 midpoint[1]=height(midrow);midcheck['observedLocalFootHeight']=float(midpoint[1]);midcheck['localFootAssociation']=connected(midrow,ground,float(midpoint[1]),midpoint,yaw+dyaw*.5)
 if not midcheck['localFootAssociation']['acceptedFiniteSupportModel']:midcheck['acceptedFiniteSupportModel']=False;return None,[midcheck],None
 endrow=scorer.support_probes(proposed,yaw+dyaw);endcheck=connected(endrow,ground,float(midpoint[1]),proposed,yaw+dyaw)
 if not endcheck['acceptedFiniteSupportModel']:return None,[midcheck,endcheck],None
 endcontinuity=continuity(midrow,endrow,float(midpoint[1]),midpoint,yaw+dyaw*.5,proposed,yaw+dyaw);endcheck['localHeightContinuity']=endcontinuity
 if not endcontinuity['accepted']:endcheck['acceptedFiniteSupportModel']=False;return None,[midcheck,endcheck],None
 proposed=proposed.copy();proposed[1]=height(endrow);endcheck['observedLocalFootHeight']=float(proposed[1]);endcheck['localFootAssociation']=connected(endrow,ground,float(proposed[1]),proposed,yaw+dyaw)
 if not endcheck['localFootAssociation']['acceptedFiniteSupportModel']:endcheck['acceptedFiniteSupportModel']=False;return None,[midcheck,endcheck],None
 length=float(np.linalg.norm(midpoint-state)+np.linalg.norm(proposed-midpoint));receipt={'attempted3DDistanceMetres':length,'supportRows':[startrow,midrow,endrow],'heightLaw':'max nine observed known-floor hits; no global plane projection','initialSettlementOnly':False}
 if length>.025000001:return None,[midcheck,endcheck],{**receipt,'reason':'unchanged25mm total3D motion cap'}
 return (midpoint,proposed),[midcheck,endcheck],receipt

def underbody_guard(scorer,ground,start,end,yaw,dyaw,support_rows):
 if len(support_rows)!=2:raise ValueError('both actual segment endpoint support rows required')
 checks=[connected(row,ground,float(p[1]),p,yy)for row,p,yy in zip(support_rows,(start,end),(yaw,yaw+dyaw))]
 if not all(x['acceptedFiniteSupportModel']for x in checks):raise ValueError('guard requires known accepted support at both endpoints')
 if any(abs(height(row)-float(p[1]))>STATE_EPS for row,p in zip(support_rows,(start,end))):raise ValueError('guard endpoint foot must equal observed max9; no floating foot')
 heights=np.concatenate([rows_values(row)[1]for row in support_rows]);low=float(heights.min()-ASSOCIATION);top=float(max(start[1],end[1])+.002);a=np.asarray(start,float).copy();b=np.asarray(end,float).copy();a[1]=b[1]=low
 corners,_=sweep_enclosure(a,b,yaw,dyaw,half_forward=.15,half_lateral=.225,height=top-low,floor_contact_exclusion=0.)
 r=scorer.contact_corners(corners);return {'contact':bool(r['contact']),'raw':r,'lowerY':low,'upperY':top,'observedSupportMinimumY':float(heights.min()),'observedSupportMaximumY':float(heights.max()),'existingSupportAssociationEnvelopeMetres':ASSOCIATION,'actualHalfSegmentEnclosed':True,'onlySameFloorMembershipExempted':True,'globalPlaneUsed':False,'continuousSupportProven':False}

def overlap_admission(base,old,new,state,yaw):
 raw=base.support_probes(state,yaw);a=connected(raw,old,float(state[1]),state,yaw);b=connected(raw,new,float(state[1]),state,yaw);match=bool(a['acceptedFiniteSupportModel']and b['acceptedFiniteSupportModel']and abs(height(raw)-state[1])<=STATE_EPS)
 return {'accepted':match,'oldSupport':a,'newSupport':b,'sameProvenancePlane':bool(np.array_equal(old.plane_coefficients,new.plane_coefficients)),'provenancePlaneNotAdmissionCriterion':True,'observedHeightMatchesActualFoot':bool(abs(height(raw)-state[1])<=STATE_EPS)if a['acceptedFiniteSupportModel']and b['acceptedFiniteSupportModel']else False,'stateUnchanged':True,'rawSupport':raw,'poseReset':False}
