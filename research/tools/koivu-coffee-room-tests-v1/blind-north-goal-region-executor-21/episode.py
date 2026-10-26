"""Prepared camera-anchored approaches with shared scene ground and equivalent v17 scoring.

Reference physics chooses only vertical support, never XZ, yaw, route or goal.
No changes to the frozen first episode, phone map, margin, controller or body.
"""
from pathlib import Path
import json,math,sys,time
from dataclasses import asdict
import numpy as np
HERE=Path(__file__).resolve().parent;WS=HERE.parent;ROOT=WS/'blind-split-candidate-game-03'
sys.path.insert(0,str(ROOT/'source'))
from run_pilot import (ControllerProcess,support_check,contact_status,load_surface,
    transform,serial_vtk,ActorFIFO,ActorProfile,ActorCommand,sha,dump)
from oriented_container import OrientedReferenceContainer
sys.path.insert(0,str(ROOT/'ground-follow-v3'))
from ground_support import GroundSupport
sys.path.insert(0,str(ROOT/'ground-query-tile-v17'))
from oriented_ground_tiled_container import GroundTiledReferenceContainer

def verify(expected):
    path=HERE/'FROZEN.json'
    if sha(path)!=expected:raise ValueError('manifest changed')
    for p,h in json.loads(path.read_text())['files'].items():
        if sha(WS/p)!=h:raise ValueError('pinned source/input changed: '+p)

# The scorer imports historical modules that alter sys.path. Bind this helper
# by its exact frozen file, never by the ambiguous historical module name.
import importlib.util as _import_util
_v3_path=ROOT/'ground-follow-v3/run_ground_pilot.py'
_v3_spec=_import_util.spec_from_file_location('frozen_v3_approach_ground_motion',_v3_path)
_v3_motion=_import_util.module_from_spec(_v3_spec)
sys.modules[_v3_spec.name]=_v3_motion
_v3_spec.loader.exec_module(_v3_motion)
connected_support=_v3_motion.connected_support
plane_support_height=_v3_motion.plane_support_height
proposed_ground_motion=_v3_motion.proposed_ground_motion
if Path(proposed_ground_motion.__code__.co_filename).resolve()!=_v3_path.resolve():
    raise RuntimeError('unexpected ground-motion implementation')

def episode(route,base,out,ground,controller_factory):
    start=np.array(route['start'],float);goal=np.array(route['goal'],float);yaw=float(route['initialYawRadians'])
    nominal=start.copy();initial_support=base.support_probes(start,yaw);initial_check=support_check(initial_support)
    result={'scope':'Camera-anchored permissive offline phone-map approach with shared scene-ground reference physics; not a loop or live clearance',
        'profile':route['profile'],'geometry':route['geometry'],'approachID':route['approachID'],'sourceAnchors':route['sourceAnchors'],'condition':'baseline','physicalAuthority':False,'gameEpisodesScheduled':1,'arrival':False,'motionExecuted':False,
        'actualDistanceMetres':0.,'actual3DDistanceMetres':0.,'attemptedDistanceMetres':0.,
        'actualBodyContactEvents':0,'marginContactEvents':0,'nearFootAmbiguousContactEvents':0,
        'ticksWithGroundContact':None,'groundTriangleContactReports':None,
        'initialReferenceSupport':initial_support,'initialSupportCheck':initial_check,
        'nominalStart':nominal.tolist(),'goal':goal.tolist(),
        'sourceConfidence':'unavailable and not synthesized','trackingState':'unavailable and not synthesized',
        'farOnlyDipConflict':'unassessed in supplied masks','strictStatClearFeasibility':'historical old-mask external logs had no 2–6m strict routes; not a corrected-map feasibility result',
        'preservedFirstAttempt':'historical fixed route attempts unchanged; this is a different frozen camera-anchored approach',
        'groundContactMeasurement':'unmeasured: immutable original ground IDs skipped; trace sentinel -1','groundSemantics':'retain original seeded low-slope ground; recover excluded microfaces only through local 20 cm patch residuals and shared edges; ONE broad robust plane sets actor Y; raw obstacle residuals and steep boundaries retained',
        'continuousSupportProven':False,'semanticGroundTruthEstablished':False}
    if not initial_check['acceptedFiniteSupportModel']:
        result.update(status='invalidStartReferenceSupport',goalErrorMetres=float(np.linalg.norm((start-goal)[[0,2]])),ticks=0);return result
    ground.assert_matches(base.surface,base.transform)
    result['groundComponent']=ground.receipt
    result['sharedSceneGroundAcrossProfiles']=True
    scorer=GroundTiledReferenceContainer(base.surface,base.transform,ground=ground,body=base.body)
    start[1]=plane_support_height(initial_support,ground);state=start.copy()
    result['initialPlanarSupportCheck']=connected_support(initial_support,ground,float(start[1]))
    if not result['initialPlanarSupportCheck']['acceptedFiniteSupportModel']:
        result.update(status='invalidStartPlaneSupportAssociation',ticks=0,goalErrorMetres=float(np.linalg.norm((start-goal)[[0,2]])));return result
    result['settledStart']=start.tolist();result['referenceFootAnchorCorrectionMetres']=float(start[1]-nominal[1])
    result['footAnchorPolicy']='world-only ONE fixed fitted plane; maximum plane height at nine actual-body support locations; observed connected-ground and hole checks remain; no horizontal correction'
    contact_started=time.monotonic();print(json.dumps({'phase':'initial_contact_check_begin'}),flush=True)
    contacts=scorer.swept_contacts(start,start,yaw,0.);result['initialContactCheckWallSeconds']=time.monotonic()-contact_started;result['initialContacts']=contacts;status=contact_status(contacts)
    if status:
        result.update(status='invalidStart:'+status,actualBodyContactEvents=int(contacts['actualBody']['contact']),marginContactEvents=int(contacts['horizontalMargin']['contact']),nearFootAmbiguousContactEvents=int(status=='firstContactTriangleNearFootAmbiguous'),goalErrorMetres=float(np.linalg.norm((state-goal)[[0,2]])),ticks=0);return result
    controller=controller_factory(out);actor=ActorFIFO(ActorProfile());trace=[]
    distance=0.;distance3d=0.;attempted=0.;stationary=0;last={};status='timeout'
    pose_revision=controller.initial['mapRevision'];flagged_ticks=0;missing_flag_ticks=0
    try:
        controller.ask({'command':'beginRun','goal':goal.tolist()})
        for tick in range(1200):
            now=100+tick/15
            pose={'kind':'simulated-physics-body-pose','position':state.tolist(),'yaw':yaw,'capturedAt':now,'mapRevision':pose_revision}
            cue=controller.ask({'command':'tick','tick':tick,'now':now,'deliveredPose':pose})
            current_flags=cue.get('phoneFlagReceipt',{}).get('lowUnresolvedCells',-1)
            proposed_flags=cue.get('proposedPhoneFlagReceipt',{}).get('lowUnresolvedCells',-1)
            flagged_ticks+=current_flags>0;missing_flag_ticks+=current_flags<0
            command=ActorCommand(cue['forwardMetres'],cue['yawRadians'],tick,cue['sourceCapturedAt'],cue['reason'])
            applied=actor.step(tick,command);proposed=state.copy();proposed_yaw=yaw+applied.yaw_radians
            proposed[[0,2]]+=[math.cos(proposed_yaw)*applied.forward_metres,math.sin(proposed_yaw)*applied.forward_metres]
            if np.linalg.norm(proposed-state)>.025000001 or abs(applied.yaw_radians)>math.radians(1)+1e-10:raise RuntimeError('actor cap')
            moved=abs(applied.forward_metres)>0 or abs(applied.yaw_radians)>0;attempted+=abs(applied.forward_metres)
            pending=any(c.forward_metres or c.yaw_radians for _,c in actor.pending)
            contacts=[];support=None;motion=None;actual_contact=False;margin_contact=False;ground_reports=0
            if moved:
                segment,support,motion=proposed_ground_motion(scorer,ground,state,proposed,yaw,applied.yaw_radians)
                if segment is None:status='unknownReferenceSupportDuringMotion' if motion is None else 'groundFollowMovementCap'
                else:
                    midpoint,proposed=segment
                    for a,b,ay,d in ((state,midpoint,yaw,applied.yaw_radians*.5),(midpoint,proposed,yaw+applied.yaw_radians*.5,applied.yaw_radians*.5)):
                        contact=scorer.swept_contacts(a,b,ay,d);contacts.append(contact)
                        # Ground triangles are deliberately unmeasured by v6.
                        ground_reports=0
                        failure=contact_status(contact)
                        if failure:
                            status=failure;actual_contact=bool(contact['actualBody']['contact']);margin_contact=bool(contact['horizontalMargin']['contact'])
                            result['actualBodyContactEvents']+=int(actual_contact);result['marginContactEvents']+=int(margin_contact)
                            result['nearFootAmbiguousContactEvents']+=int(failure=='firstContactTriangleNearFootAmbiguous');break
                    if status=='timeout':
                        state=proposed;yaw=proposed_yaw;distance+=abs(applied.forward_metres);distance3d+=motion['attempted3DDistanceMetres'];result['motionExecuted']=True
            result['ticksWithGroundContact']=None;result['groundTriangleContactReports']=None
            error=float(np.linalg.norm((state-goal)[[0,2]]))
            arrival=bool(cue['goalReached']and not moved and not pending and error<=.35 and float(np.linalg.norm(state-goal))<=.35 and distance>0 and distance>=max(0,float(np.linalg.norm((start-goal)[[0,2]]))-.35))
            if arrival:status='arrivalReferenceModelOnly';result['arrival']=True
            stationary=0 if moved else stationary+1
            if stationary>=150 and not pending and not arrival:status='deadlockNoMotion'
            trace.append([tick,now,*state,yaw,*proposed,applied.forward_metres,applied.yaw_radians,error,int(actual_contact),int(margin_contact),current_flags,proposed_flags,-1])
            last={'cue':cue,'appliedCommand':asdict(applied),'contacts':contacts,'support':support,'motion':motion,'pendingMotion':pending,'actualGoalErrorMetres':error,'actualFull3DGoalErrorMetres':float(np.linalg.norm(state-goal)),'steeringGoalIsNotArrivalOrigin':True}
            if tick%15==0:print(json.dumps({'phase':'actor_tick','tick':tick,'distance':distance,'goalError':error,'status':status}),flush=True)
            if status!='timeout':break
    finally:controller.close()
    np.savez_compressed(out/'ACTOR_TRACE.npz',trace=np.asarray(trace),columns=np.asarray(['tick','time','x','y','z','yaw','proposedX','proposedY','proposedZ','forward','yawDelta','goalError','actualBodyContact','marginContact','currentLowUnresolvedCells','proposedLowUnresolvedCells','unmeasuredGroundContactSentinel']))
    dump(out/'QUERY_OPTIMIZATION.json',scorer.optimization_rows)
    result.update(status=status,ticks=tick+1,actualDistanceMetres=distance,actual3DDistanceMetres=distance3d,attemptedDistanceMetres=attempted,goalErrorMetres=last['actualGoalErrorMetres'],finalPosition=state.tolist(),finalYawRadians=yaw,terminal=last,traceSHA256=sha(out/'ACTOR_TRACE.npz'),nominalSpeedMetresPerSecond=.30,maximumSpeedMetresPerSecond=.375,warningBurden='not measured: no live sensor/hazard stream in offline game',ticksWithSampledLowUnresolvedExposure=flagged_ticks,ticksWithoutCurrentFlagReceipt=missing_flag_ticks,traceMissingFlagSentinel=-1)
    return result
