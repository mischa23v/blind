"""First-leg synthetic stress pilot, preserved physical gates and queue semantics."""
from pathlib import Path
import json,math,sys,time,selectors,subprocess,csv,gzip,lzma
from collections import Counter
from dataclasses import asdict
from pose_delivery import PoseDelivery,condition_by_id,goal_observation_current
from impairments import ActorProfile
import numpy as np
H=Path(__file__).resolve().parent;W=H.parent
import physics_primitives as motion
from oriented_container import sweep_enclosure
sys.path.insert(0,str(H));from loop_map import load_plan
class ControllerProcess(motion.ControllerProcess):
 def __init__(self,out,plan):
  self.err=(Path(out)/'controller.stderr.log').open('x');self.p=subprocess.Popen([sys.executable,str(H/'loop_controller.py')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=self.err,text=True,bufsize=1);self.selector=selectors.DefaultSelector();self.selector.register(self.p.stdout,selectors.EVENT_READ)
  try:self.initial=self.ask({'command':'initialize','planPath':plan['_path'],'planSHA256':plan['_sha']})
  except BaseException:self.close();raise

def jsonable(x):
 if isinstance(x,np.ndarray):return jsonable(x.tolist())
 if isinstance(x,np.generic):return jsonable(x.item())
 if isinstance(x,dict):return {str(k):jsonable(v)for k,v in x.items()}
 if isinstance(x,(list,tuple)):return [jsonable(v)for v in x]
 if isinstance(x,float)and not math.isfinite(x):raise ValueError('nonfinite evidence')
 return x

def save(path,x):Path(path).write_text(json.dumps(jsonable(x),indent=2,allow_nan=False)+'\n')
def arrived(cue,moved,pending,state,goal,leg_distance,leg_start):
 return bool(cue['goalReached']and not moved and not pending and np.linalg.norm(state-goal)<=.35 and np.linalg.norm((state-goal)[[0,2]])<=.35 and leg_distance>0 and leg_distance>=max(0,np.linalg.norm((leg_start-goal)[[0,2]])-.35))
def actual_winding(positions,centre):
 p=np.asarray(positions,float);c=np.asarray(centre,float)
 if p.ndim!=2 or p.shape[1]!=3 or len(p)<2 or c.shape!=(3,)or not np.isfinite(p).all()or not np.isfinite(c).all():raise ValueError('finite XYZ topology inputs')
 gap=float(np.linalg.norm(p[-1]-p[0]));q=np.vstack([p[:,[0,2]],p[0,[0,2]]])-c[[0,2]];a=q[:-1];b=q[1:];delta=b-a;dd=(delta*delta).sum(1);t=np.divide(-(a*delta).sum(1),dd,out=np.zeros(len(dd)),where=dd>0);near=a+np.clip(t,0,1)[:,None]*delta;minimum=float(np.linalg.norm(near,axis=1).min());defined=minimum>1e-9
 value=float(np.arctan2(a[:,0]*b[:,1]-a[:,1]*b[:,0],(a*b).sum(1)).sum()/(2*np.pi))if defined else None
 return {'defined':defined,'winding':value,'minimumSegmentDistanceFromWindingPointMetres':minimum,'mathematicalClosingGap3DMetres':gap,'mathematicalClosingGapHorizontalMetres':float(np.linalg.norm((p[-1]-p[0])[[0,2]])),'closingSegmentWasNotExecuted':True,'closureOnlyForTopologicalDiagnostic':True,'actualTraceSamples':len(p),'tablePointOriginalXYZ':c.tolist()}

from local_support import overlap_admission,underbody_guard,height as observed_support_height,connected as local_connected,proposed_ground_motion,validate_support_pose

def episode(plan,base,grounds,out,condition=None,seed=72000):
 condition=condition_by_id('nominal') if condition is None else condition
 out=Path(out);state=np.asarray(plan['start'],float);yaw=float(plan['initialYawRadians']);goal=np.array(plan['legs'][0]['originalTaskGoal']);ground=grounds[0];scorer=motion.GroundTiledReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)
 result={'condition':condition,'seed':seed,'firstLegOnly':False,'syntheticPoseDelivery':True,'worldVetoIsEvaluatorNotPhoneDetection':True,'scope':'One frozen ordered-pair synthetic stress episode; observed local floor support; not a table lap, real sensors or human safety','arrival':False,'completedLaps':0,'completedLegs':0,'motionExecuted':False,'physicalAuthority':False,'profile':plan['profile'],'geometry':plan['geometry'],'actualDistanceMetres':0.,'actual3DDistanceMetres':0.,'actualBodyContactEvents':0,'marginContactEvents':0,'rejectedPredictedBodyContactEvents':0,'rejectedPredictedMarginContactEvents':0,'rejectedPredictedUnderbodyContactEvents':0,'initialUnderbodyGuardContact':False,'underbodyGuardEnabled':True,'groundContacts':'unmeasured: classified floor IDs exempted as in previous scorer','floorPartitionPolicy':'immutable59 memberships; measured local max9 support; global plane provenance only; no handoff snaps','thresholdExceptions':False,'nominalStart':state.tolist(),'historicalWesternTaskExclusionRemoved':True}
 raw=base.support_probes(state,yaw);numeric=motion.support_check(raw)
 try:validate_support_pose(raw,state,yaw)
 except(ValueError,KeyError,TypeError)as exc:numeric.update(acceptedFiniteSupportModel=False,reason=str(exc))
 result['initialRawSupport']=raw;result['initialNumericSupport']=numeric
 if not numeric['acceptedFiniteSupportModel']:return {**result,'status':'initialNumericSupportRejected','ticks':0}
 initial_height=observed_support_height(raw);check=local_connected(raw,ground,initial_height,state,yaw);result['initialObservedSupport']=check
 if check['acceptedFiniteSupportModel']:state[1]=initial_height
 result.update(settledStart=state.tolist(),initialVerticalSettlementMetres=float(state[1]-plan['start'][1]),noPoseResetAfterInitialSettlement=True,globalPlaneProvenanceOnly=True,activeHeightLaw='maximum nine known observed floor hits with bounded continuity')
 if not check['acceptedFiniteSupportModel']:return {**result,'status':'initialMembershipSupportRejected','ticks':0}
 contact=scorer.swept_contacts(state,state,yaw,0.);result['initialContacts']=contact
 if motion.contact_status(contact):return {**result,'status':'initialBodyContact','ticks':0,'actualBodyContactEvents':int(contact['actualBody']['contact']),'marginContactEvents':int(contact['horizontalMargin']['contact'])}
 initialguard=underbody_guard(scorer,ground,state,state,yaw,0.,[raw,raw]);result['initialUnderbodyGuard']=initialguard
 if initialguard['contact']:return {**result,'status':'initialNonFloorUnderbodyGuardContact','initialUnderbodyGuardContact':True,'ticks':0}
 actor=motion.ActorFIFO(ActorProfile(**condition['actor']));delivery=PoseDelivery(condition,seed);last_motion_tick=-1;controller=ControllerProcess(out,plan);revision=controller.initial['mapRevision'];distance=0.;distance3d=0.;attempted=0.;leg=0;leg_distance=0.;leg_start=state.copy();status='timeout';stationary=0;last={};transitions=[];rows=[];flagged=0;scorers=[scorer];counts=Counter();max_pose_error=0.;max_yaw_error=0.;max_pose_age=0.;max_queue=0
 columns=['tick','time','x','y','z','yaw','proposedX','proposedY','proposedZ','forward','yawDelta','goalError','actualBodyContact','marginContact','currentLowUnresolvedCells','proposedLowUnresolvedCells','unmeasuredGroundContactSentinel','leg']
 tracefile=(out/'ACTUAL_TRACE_PARTIAL.csv').open('x',newline='');writer=csv.writer(tracefile);writer.writerow(columns);initial=[-1,100.,*state,yaw,*state,0.,0.,float(np.linalg.norm(state-goal)),0,0,-1,-1,-1,0];writer.writerow(initial);tracefile.flush();rows.append(initial)
 evidence=lzma.open(out/'TICK_EVIDENCE.jsonl.xz','xt',encoding='utf-8',preset=6)
 try:
  controller.ask({'command':'beginRun','goal':goal.tolist()})
  for tick in range(plan['maximumTicks']):
   now=100+tick/15;before=state.copy();byaw=yaw;delivered,delivery_row=delivery.capture_and_release(tick,now,state,yaw,revision,leg);cue=controller.ask({'command':'tick','tick':tick,'now':now,'deliveredPose':delivered,'releasedPoses':[dict(x['packet']['pose'],deliveryMode='new')for x in delivery_row['released']]})
   counts['retainedObservationTicks']+=int(delivery_row.get('retainedObservation',False));counts['ticksWithoutNewPacket']+=int(not delivery_row.get('newPacketSelected',False));counts['captureWithheldTicks']+=int(delivery_row['captureWithheld']);counts['ticksWithoutUsableObservation']+=int(delivered is None);counts['coalescedPackets']+=delivery_row['coalescedPackets'];max_queue=max(max_queue,delivery_row['pendingPackets']);counts['controllerReason:'+cue['reason']]+=1
   if delivered is not None:
    max_pose_error=max(max_pose_error,float(np.linalg.norm(state-np.array(delivered['position']))));max_yaw_error=max(max_yaw_error,abs(math.atan2(math.sin(yaw-delivered['yaw']),math.cos(yaw-delivered['yaw']))));max_pose_age=max(max_pose_age,now-delivered['capturedAt'])
   applied=actor.step(tick,motion.ActorCommand(cue['forwardMetres'],cue['yawRadians'],tick,cue['sourceCapturedAt'],cue['reason']));proposed=state.copy();pyaw=yaw+applied.yaw_radians;proposed[[0,2]]+=[math.cos(pyaw)*applied.forward_metres,math.sin(pyaw)*applied.forward_metres]
   if np.linalg.norm(proposed-state)>.025000001 or abs(applied.yaw_radians)>math.radians(1)+1e-10:raise RuntimeError('unchanged actor command cap')
   moved=bool(applied.forward_metres or applied.yaw_radians);counts['motionAfterIssuedZeroTicks']+=int(moved and cue['forwardMetres']==0 and cue['yawRadians']==0);counts['translationClippedTicks']+=int(applied.translation_clipped);pending=any(c.forward_metres or c.yaw_radians for _,c in actor.pending);attempted+=abs(applied.forward_metres);contacts=[];support=None;movement=None;underbody=None
   if moved:
    segments,support,movement=proposed_ground_motion(scorer,ground,state,proposed,yaw,applied.yaw_radians)
    if segments is None:status='unknownReferenceSupportDuringMotion'if movement is None else'groundFollowMovementCap'
    else:
     midpoint,proposed=segments
     for aa,bb,yy,dy in((state,midpoint,yaw,applied.yaw_radians/2),(midpoint,proposed,yaw+applied.yaw_radians/2,applied.yaw_radians/2)):
      c=scorer.swept_contacts(aa,bb,yy,dy);contacts.append(c);failure=motion.contact_status(c)
      if failure:
       status='rejectedPredicted:'+failure;result['rejectedPredictedBodyContactEvents']+=int(c['actualBody']['contact']);result['rejectedPredictedMarginContactEvents']+=int(c['horizontalMargin']['contact']);break
     if status=='timeout':
      guardrows=movement['supportRows'];halves=[]
      for j,(aa,bb,yy,dy)in enumerate(((state,midpoint,yaw,applied.yaw_radians/2),(midpoint,proposed,yaw+applied.yaw_radians/2,applied.yaw_radians/2))):
       halves.append(underbody_guard(scorer,ground,aa,bb,yy,dy,guardrows[j:j+2]))
       if halves[-1]['contact']:break
      underbody={'contact':any(x['contact']for x in halves),'halfSegments':halves,'actualMidpointCovered':len(halves)==2,'checkedHalfSegments':len(halves)}
      if underbody['contact']:status='rejectedPredictedUnderbodyObstacle';result['rejectedPredictedUnderbodyContactEvents']+=1
     if status=='timeout':state=proposed;yaw=pyaw;delta=float(np.linalg.norm((state-before)[[0,2]]));distance+=delta;leg_distance+=delta;distance3d+=movement['attempted3DDistanceMetres'];result['motionExecuted']=True
   actual_moved=bool(np.linalg.norm(state-before)>1e-12 or abs(yaw-byaw)>1e-12);current_flags=cue.get('phoneFlagReceipt',{}).get('lowUnresolvedCells',-1);proposed_flags=cue.get('proposedPhoneFlagReceipt',{}).get('lowUnresolvedCells',-1);flagged+=current_flags>0
   if actual_moved:last_motion_tick=tick
   observation_current=goal_observation_current(cue,delivered,leg,last_motion_tick)
   isarrival=status=='timeout'and observation_current and arrived(cue,moved,pending,state,goal,leg_distance,leg_start)
   terminal={'poseDelivery':delivery_row,'deliveredPose':delivered,'lastCommittedMotionTick':last_motion_tick,'goalObservationCurrent':observation_current,'cue':cue,'appliedCommand':asdict(applied),'contacts':contacts,'support':support,'movement':movement,'pendingMotion':pending,'actualFull3DGoalError':float(np.linalg.norm(state-goal)),'candidateStateCommitted':status=='timeout','underbodyGuard':underbody}
   row=[tick,now,*state,yaw,*proposed,applied.forward_metres,applied.yaw_radians,float(np.linalg.norm(state-goal)),0,0,current_flags,proposed_flags,-1,leg];rows.append(row);writer.writerow(row);tracefile.flush();evidence.write(json.dumps(jsonable({'tick':tick,'leg':leg,**terminal}),separators=(',',':'),allow_nan=False)+'\n');evidence.flush();last=terminal
   if isarrival:
    transitions.append({'leg':leg,'tick':tick,'position':state.tolist(),'yaw':yaw,'goal':goal.tolist(),'legDistanceMetres':leg_distance,'totalDistanceMetres':distance,'full3DGoalErrorMetres':float(np.linalg.norm(state-goal)),'pendingMotion':pending,'appliedMotion':moved,'sameActorStateRetained':True});result['completedLegs']=leg+1
    status='completeOrderedPairSyntheticEpisode';result['arrival']=True;result['completedLaps']=0
   stationary=0 if actual_moved else stationary+1
   if stationary>=150 and not pending and not isarrival and status=='timeout':status='deadlockNoMotion'
   save(out/'LIVE_PROGRESS.json',{'status':status,'lastCommittedTick':tick,'leg':leg,'completedLegs':result['completedLegs'],'actualDistanceMetres':distance,'actual3DDistanceMetres':distance3d,'position':state.tolist(),'yaw':yaw,'arrival':result['arrival'],'actualTraceCSVFlushed':True})
   if tick%30==0:print(json.dumps({'phase':'loopTick','tick':tick,'leg':leg,'distance':distance,'status':status}),flush=True)
   if status!='timeout':break
 finally:controller.close();tracefile.close();evidence.close()
 np.savez_compressed(out/'ACTOR_TRACE.npz',trace=np.asarray(rows),columns=np.asarray(columns))
 with lzma.open(out/'QUERY_OPTIMIZATION.json.xz','wt',encoding='utf-8',preset=6)as f:json.dump(jsonable([s.optimization_rows for s in scorers]),f,separators=(',',':'))
 result.update(stressCounts=dict(counts),maximumDeliveredPoseErrorMetres=max_pose_error,maximumDeliveredYawErrorRadians=max_yaw_error,maximumDeliveredPoseAgeSeconds=max_pose_age,maximumPendingPosePackets=max_queue,interruptionExposureComplete=counts['captureWithheldTicks']==30 if condition['id']=='tracking_interruption' else None,condition=condition,syntheticPoseDelivery=True,seed=seed,firstLegOnly=False,worldVetoIsEvaluatorNotPhoneDetection=True,status=status,ticks=tick+1,actualDistanceMetres=distance,actual3DDistanceMetres=distance3d,attemptedDistanceMetres=attempted,finalPosition=state.tolist(),finalYawRadians=yaw,terminal=last,legTransitions=transitions,ticksWithLowUnresolvedExposure=flagged,traceSHA256=motion.sha(out/'ACTOR_TRACE.npz'),sourceRouteNeverChanged=True,sourceRouteFixedWithinEachLeg=True,sourceOnlyReplannedAtDrainedHandoffs=False,sourceRequeriesExecuted=0,actualBodyContactsCommitted=0,firstPredictedContactOrSupportFailureTerminates=True,finalPendingMotion=bool(last.get('pendingMotion')),finalAppliedCommand=last.get('appliedCommand'),finalOriginalStartError3DMetres=float(np.linalg.norm(state-np.array(plan['start']))),finalOriginalStartErrorHorizontalMetres=float(np.linalg.norm((state-np.array(plan['start']))[[0,2]])))
 return result
